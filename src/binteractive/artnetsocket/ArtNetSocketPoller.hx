package binteractive.artnetsocket;

import lime.system.ThreadPool;
import lime.system.WorkOutput;
import sys.net.UdpSocket;
import sys.net.Host;
import haxe.io.Bytes;
import haxe.Timer;
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
    private var socket:UdpSocket; // The UDP socket to poll for incoming data
    private var running:Bool = false; // Flag indicating whether polling is active
    private var threadPool:ThreadPool; // ThreadPool for running the polling job in a background thread
    private var pollJobID:Int = -1; // ID of the current polling job in the ThreadPool
    private var dispatcher:EventDispatcher; // Event dispatcher for forwarding UDP data events

    /**
     * Constructor.
     * @param socket      UDP socket to poll for incoming data.
     * @param dispatcher  Event dispatcher to forward UDP data events to.
     */
    public function new(socket:UdpSocket, dispatcher:EventDispatcher) {
        this.socket = socket;
        this.dispatcher = dispatcher;
        // Create a single-threaded ThreadPool (safe and efficient for socket polling)
        threadPool = new ThreadPool(1, 1);
    }

    /**
     * Starts the background polling job.
     * Safe to call multiple times; will not duplicate jobs.
     */
    public function start():Void {
        if (running) return; // Already running? Do nothing.
        running = true;
        attachThreadPoolListeners(); // Set up listeners for data and error events
        // Start the polling loop in the ThreadPool
        pollJobID = threadPool.run(pollLoop, {});
    }

    /**
     * Stops the background polling job and cleans up the thread pool.
     * Also closes the socket to unblock any waiting thread.
     */
    public function stop():Void {
        running = false; // Signal the polling loop to exit
        // Close the socket to immediately unblock any blocking read
        try {
            socket.close();
        } catch (e:Dynamic) {
            // Ignore errors, socket may already be closed
        }
        // Cancel the polling job in the thread pool
        if (threadPool != null && pollJobID != -1) {
            threadPool.cancelJob(pollJobID);
            pollJobID = -1;
        }
    }

    /**
     * The polling function to be run on a background thread.
     * It receives UDP packets and uses sendProgress to communicate with the main thread.
     * The loop exits promptly when 'running' is set to false and the socket is closed.
     */
    private function pollLoop(state:Dynamic, output:WorkOutput):Void {
        var bufferSize = 1024; // Size of the UDP receive buffer
        var buffer = Bytes.alloc(bufferSize); // Buffer for receiving UDP data
        var addr = new sys.net.Address(); // Address of sender

        // Try to set the socket to non-blocking mode (if supported)
        try {
            socket.setBlocking(false);
        } catch (e:Dynamic) {
            // Not supported on some targets; it's safe to ignore
        }

        // Main polling loop
        while (running) {
            var dataRead = false; // Tracks if any data was received in this iteration
            try {
                while (true) {
                    // Attempt to read data from the socket into the buffer
                    var bytesRead = socket.readFrom(buffer, 0, bufferSize, addr);
                    if (bytesRead <= 0) break; // No data read, exit inner loop
                    dataRead = true; // Mark that data was received
                    // Send received data to the main thread using sendProgress
                    output.sendProgress({
                        data: buffer.sub(0, bytesRead),
                        host: addr.host,
                        port: addr.port
                    });
                }
            } catch (e:Dynamic) {
                // If the socket is closed, exit the thread immediately
                var msg = Std.string(e);
                if (msg.indexOf("Bad file descriptor") >= 0 || msg.indexOf("socket closed") >= 0) {
                    break; // Exit the polling loop
                }
                // EWOULDBLOCK/EAGAIN just means no data available yet
                if (!isWouldBlockError(e)) {
                    output.sendError(e); // Report real errors
                }
            }
            // Sleep for 10ms if no data was received, to avoid busy-waiting and high CPU usage
            if (!dataRead) sys.thread.Thread.sleep(0.01);
        }
        // Notify main thread that polling has completed
        output.sendComplete(null);
    }

    /**
     * Returns true if the error corresponds to a non-blocking read
     * where no data was available (EWOULDBLOCK/EAGAIN).
     */
    private function isWouldBlockError(e:Dynamic):Bool {
        var msg = Std.string(e);
        return msg.indexOf("EWOULDBLOCK") >= 0 || msg.indexOf("EAGAIN") >= 0;
    }

    /**
     * Attaches listeners to the thread pool for progress (data received) and error events.
     * These will dispatch custom events on the provided dispatcher.
     */
    private function attachThreadPoolListeners():Void {
        // Listen for data received from the polling thread
        threadPool.onProgress.add(function(payload:Dynamic) {
            if (payload != null && payload.data != null && payload.host != null && payload.port != null) {
                // Use a custom event to forward UDP data to ArtNetSocket
                dispatcher.dispatchEvent(new ArtNetSocketPollEvent(payload.data, payload.host, payload.port));
            }
        });
        // Listen for errors from the polling thread
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
    public var data:Bytes; // UDP packet data
    public var host:String; // Sender's host
    public var port:Int; // Sender's port
    public function new(data:Bytes, host:String, port:Int) {
        super("ArtNetSocketPollEvent", false, false);
        this.data = data;
        this.host = host;
        this.port = port;
    }
}
