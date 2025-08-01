package binteractive.artnetsocket;

import lime.system.ThreadPool;
import lime.system.WorkOutput;
import sys.net.UdpSocket;
import sys.net.Host;
import sys.thread.Thread;
import haxe.io.Bytes;
import openfl.events.EventDispatcher;
import openfl.events.Event;
import binteractive.artnetsocket.ArtNetSocketEvents;

/**
 * ArtNetSocketPoller
 *
 * Handles threaded UDP polling for ArtNetSocket using lime.system.ThreadPool.
 * Encapsulates all background network polling and threadsafe event dispatch.
 */
class ArtNetSocketPoller {
    private var socket:UdpSocket;
    private var running:Bool = false;
    private var threadPool:ThreadPool;
    private var pollJobID:Int = -1;
    private var dispatcher:EventDispatcher;

    /**
     * Constructor.
     * @param socket      UDP socket to poll for incoming data.
     * @param dispatcher  Event dispatcher to forward UDP data events to.
     */
    public function new(socket:UdpSocket, dispatcher:EventDispatcher) {
        this.socket = socket;
        this.dispatcher = dispatcher;
        // Use a single-threaded ThreadPool (safe and efficient for socket polling)
        threadPool = new ThreadPool(1, 1);
    }

    /**
     * Starts the background polling job.
     * Safe to call multiple times; will not duplicate jobs.
     */
    public function start():Void {
        if (running) return;
        running = true;
        attachThreadPoolListeners();
        pollJobID = threadPool.run(pollLoop, {});
    }

    /**
     * Stops the background polling job and cleans up the thread pool.
     */
    public function stop():Void {
        running = false;
        if (threadPool != null && pollJobID != -1) {
            threadPool.cancelJob(pollJobID);
            pollJobID = -1;
        }
    }

    /**
     * The polling function to be run on a background thread.
     * It receives UDP packets and uses sendProgress to communicate with the main thread.
     */
    private function pollLoop(state:Dynamic, output:WorkOutput):Void {
        var bufferSize = 1024;
        var buffer = Bytes.alloc(bufferSize);
        var addr = new sys.net.Address();
        while (running) {
            try {
                while (true) {
                    // addr will be filled with the sender's address (remote host/port)
                    var bytesRead = socket.readFrom(buffer, 0, bufferSize, addr);
                    if (bytesRead <= 0) break;
                    var host = addr.host;
                    var port = addr.port;
                    var data = buffer.sub(0, bytesRead);
                    output.sendProgress({ data: data, host: host, port: port });
                }
            } catch (e:Dynamic) {
                output.sendError(e);
            }
            Thread.sleep(0.01);
        }
        output.sendComplete(null);
    }

    /**
     * Attaches listeners to the thread pool for progress (data received) and error events.
     * These will dispatch custom events on the provided dispatcher.
     */
    private function attachThreadPoolListeners():Void {
        threadPool.onProgress.add(function(payload:Dynamic) {
            if (payload != null && payload.data != null && payload.host != null && payload.port != null) {
                // Use a custom event to forward UDP data to ArtNetSocket
                dispatcher.dispatchEvent(new ArtNetSocketPollEvent(payload.data, payload.host, payload.port));
            }
        });
        threadPool.onError.add(function(err) {
            dispatcher.dispatchEvent(new ArtNetErrorEvent(ArtNetSocket.ERROR, Std.string(err)));
        });
    }
}

/**
 * Internal event class for socket polling results.
 * Not intended to be used directly by library consumers.
 */
class ArtNetSocketPollEvent extends Event {
    public var data:Bytes;
    public var host:String;
    public var port:Int;
    public function new(data:Bytes, host:String, port:Int) {
        super("ArtNetSocketPollEvent", false, false);
        this.data = data;
        this.host = host;
        this.port = port;
    }
}
