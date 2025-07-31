package b-interactive.artnetsocket;

import openfl.events.EventDispatcher;
import openfl.events.Event;
import haxe.io.Bytes;
import lime.system.Thread;

#if (air || flash)
import openfl.net.DatagramSocket;
import openfl.events.DatagramSocketDataEvent;
import openfl.events.IOErrorEvent;
#else
import sys.net.UdpSocket;
import sys.net.Host;
import openfl.Lib;
#end

/**
 * ArtNetSocket
 *
 * Cross-platform, event-driven UDP socket for OpenFL/Lime projects.
 * - On native targets: uses sys.net.UdpSocket and a Lime background thread for polling.
 * - On AIR/Flash: uses openfl.net.DatagramSocket with built-in event dispatching.
 *
 * Usage:
 *   import b-interactive.artnetsocket.ArtNetSocket;
 *   var socket = new ArtNetSocket(6454);
 *   socket.addEventListener(ArtNetSocket.DATA, onData);
 *   socket.addEventListener(ArtNetSocket.ERROR, onError);
 *   socket.send(...);
 */
class ArtNetSocket extends EventDispatcher {
    public static inline var DATA:String = "data";   // Event type for received UDP data
    public static inline var ERROR:String = "error"; // Event type for socket errors

    #if (air || flash)
    var socket:DatagramSocket;
    #else
    var socket:UdpSocket;
    var running:Bool = false;
    var thread:Thread;
    var dispatcher:EventDispatcher;
    #end

    var port:Int;

    /**
     * Constructor: binds the UDP socket to the specified port.
     * @param port UDP port to bind for listening.
     */
    public function new(port:Int) {
        super();
        this.port = port;

        #if (air || flash)
        // AIR/Flash: Use OpenFL DatagramSocket with events
        socket = new DatagramSocket();
        socket.addEventListener(DatagramSocketDataEvent.DATA, onSocketData);
        socket.addEventListener(IOErrorEvent.IO_ERROR, onSocketError);
        socket.bind(port, "0.0.0.0");
        socket.receive();
        #else
        // Native: Use sys UDP socket and Lime thread for polling
        socket = new UdpSocket();
        socket.setBlocking(false);
        socket.bind(new Host("0.0.0.0"), port);
        dispatcher = Lib.current.stage; // Main thread event dispatcher
        running = true;
        thread = Thread.create(pollLoop);
        #end
    }

    /**
     * Close the UDP socket and stop background thread (if any).
     */
    public function close() {
        #if (air || flash)
        socket.close();
        #else
        running = false;
        socket.close();
        #end
    }

    /**
     * Send a UDP packet.
     * @param data The payload to send.
     * @param host Target IP address or hostname.
     * @param port Target UDP port.
     */
    public function send(data:Bytes, host:String, port:Int) {
        #if (air || flash)
        socket.send(data.getData(), 0, data.length, host, port);
        #else
        socket.sendTo(data, new Host(host), port);
        #end
    }

    #if (air || flash)
    /**
     * Handle incoming data on AIR/Flash targets.
     */
    function onSocketData(e:DatagramSocketDataEvent):Void {
        dispatchEvent(new ArtNetDataEvent(DATA, Bytes.ofData(e.data), e.srcAddress, e.srcPort));
    }

    /**
     * Handle socket errors on AIR/Flash targets.
     */
    function onSocketError(e:IOErrorEvent):Void {
        dispatchEvent(new ArtNetErrorEvent(ERROR, e.text));
    }
    #else
    /**
     * Background polling loop for native targets.
     * Reads UDP packets and dispatches events on the main thread.
     */
    function pollLoop() {
        while (running) {
            try {
                while (true) {
                    var result = socket.recvFrom(1024);
                    if (result == null) break;
                    // Dispatch data event on the main thread
                    dispatcher.dispatchEvent(
                        new ArtNetDataEvent(DATA, result.data, result.host.toString(), result.port)
                    );
                }
            } catch (e:Dynamic) {
                // Dispatch error event on the main thread
                dispatcher.dispatchEvent(new ArtNetErrorEvent(ERROR, Std.string(e)));
            }
            Thread.sleep(0.01); // Prevent busy-waiting
        }
    }
    #end
}

/**
 * Custom event: dispatched when UDP data is received.
 */
class ArtNetDataEvent extends Event {
    public var data:Bytes;  // Packet payload
    public var host:String; // Sender IP
    public var port:Int;    // Sender port

    public function new(type:String, data:Bytes, host:String, port:Int) {
        super(type, false, false);
        this.data = data;
        this.host = host;
        this.port = port;
    }
}

/**
 * Custom event: dispatched when a socket error occurs.
 */
class ArtNetErrorEvent extends Event {
    public var message:String;

    public function new(type:String, message:String) {
        super(type, false, false);
        this.message = message;
    }
}