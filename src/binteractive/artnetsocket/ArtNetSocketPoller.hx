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
    while (running) {
        try {
            while (true) {
                // Allocate a new buffer for each read to avoid data overwrite
                buffer = Bytes.alloc(bufferSize);
                var result = socket.readFrom(buffer);
                if (result == null) break;
                var host = result.host.toString();
                var port = result.port;
                // result.data is a Bytes slice of the buffer, or just pass buffer with length
                output.sendProgress({ data: buffer.sub(0, result.length), host: host, port: port });
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
