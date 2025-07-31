package b_interactive.artnetsocket;

import openfl.events.EventDispatcher;
import openfl.events.Event;
import haxe.io.Bytes;
import lime.system.Thread;
import b_interactive.artnetsocket.ArtNetHelper;

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
 * Cross-platform, event-driven UDP socket tailored for Art-Net (OpenFL/Haxe 4.3+).
 * - Native (C++, HL): Non-blocking with polling thread.
 * - AIR/Flash: Event-driven with DatagramSocket.
 *
 * Fires high-level events for ArtDMX (DMX data), ArtPollReply (discovery),
 * and exposes raw UDP data for unparsed packets.
 *
 * Usage:
 *   - Listen for ArtNetSocket.ARTDMX, ARTPOLLREPLY, DATA, and ERROR events.
 *   - Use sendDMX and sendPoll for Art-Net transmission.
 */
class ArtNetSocket extends EventDispatcher {
    public static inline var ARTDMX:String = "artdmx";             // Event type: ArtDMXEvent
    public static inline var ARTPOLLREPLY:String = "artpollreply"; // Event type: ArtPollReplyEvent
    public static inline var DATA:String = "data";                 // Event type: ArtNetDataEvent (raw)
    public static inline var ERROR:String = "error";               // Event type: ArtNetErrorEvent

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
     * Binds and opens a socket on the specified UDP port.
     * @param port UDP port (default for Art-Net is 6454)
     */
    public function new(port:Int) {
        super();
        this.port = port;
        #if (air || flash)
        socket = new DatagramSocket();
        socket.addEventListener(DatagramSocketDataEvent.DATA, onSocketData);
        socket.addEventListener(IOErrorEvent.IO_ERROR, onSocketError);
        socket.bind(port, "0.0.0.0");
        socket.receive();
        #else
        socket = new UdpSocket();
        socket.setBlocking(false);
        socket.bind(new Host("0.0.0.0"), port);
        dispatcher = Lib.current.stage;
        running = true;
        thread = Thread.create(pollLoop);
        #end
    }

    /**
     * Closes the socket and stops background polling (if native).
     */
    public function close():Void {
        #if (air || flash)
        socket.close();
        #else
        running = false;
        socket.close();
        #end
    }

    /**
     * Send an ArtDMX packet (DMX data) to a target.
     * @param pkt ArtDMXPacket (see ArtNetHelper typedef)
     * @param host Destination IP or host name
     * @param port UDP port (default 6454)
     */
    public function sendDMX(pkt:ArtDMXPacket, host:String, port:Int = 6454):Void {
        var data = ArtNetHelper.encodeDMX(pkt);
        send(data, host, port);
    }

    /**
     * Send ArtPoll (discovery) packet to a network segment.
     * Use broadcast address (e.g., 255.255.255.255) for all nodes.
     * @param host Destination IP (broadcast for discovery)
     * @param port UDP port (default 6454)
     */
    public function sendPoll(host:String, port:Int = 6454):Void {
        var data = ArtNetHelper.encodePoll();
        send(data, host, port);
    }

    /**
     * Send raw UDP bytes.
     * @param data Bytes to send
     * @param host Target IP
     * @param port Target port
     */
    public function send(data:Bytes, host:String, port:Int):Void {
        #if (air || flash)
        socket.send(data.getData(), 0, data.length, host, port);
        #else
        socket.sendTo(data, new Host(host), port);
        #end
    }

    #if (air || flash)
    // AIR/Flash: socket data event handler
    function onSocketData(e:DatagramSocketDataEvent):Void {
        onDataReceived(Bytes.ofData(e.data), e.srcAddress, e.srcPort);
    }
    // AIR/Flash: socket error handler
    function onSocketError(e:IOErrorEvent):Void {
        dispatchEvent(new ArtNetErrorEvent(ERROR, e.text));
    }
    #else
    // Native: background polling thread for UDP receive
    function pollLoop() {
        while (running) {
            try {
                while (true) {
                    var result = socket.recvFrom(1024);
                    if (result == null) break;
                    var host = result.host.toString();
                    var port = result.port;
                    onDataReceived(result.data, host, port);
                }
            } catch (e:Dynamic) {
                dispatcher.dispatchEvent(new ArtNetErrorEvent(ERROR, Std.string(e)));
            }
            Thread.sleep(0.01);
        }
    }
    #end

    /**
     * Handles incoming UDP data, parses as Art-Net if possible,
     * and dispatches the appropriate event.
     * @param data Received UDP payload
     * @param host Source IP address
     * @param port Source UDP port
     */
    private function onDataReceived(data:Bytes, host:String, port:Int):Void {
        var detected = ArtNetHelper.detectAndParse(data);
        if (detected != null) {
            switch (detected.type) {
                case "ArtDMX":
                    dispatchEvent(new ArtDMXEvent(ARTDMX, detected.packet, host, port));
                case "ArtPollReply":
                    dispatchEvent(new ArtPollReplyEvent(ARTPOLLREPLY, detected.packet, host, port));
                default:
            }
        } else {
            dispatchEvent(new ArtNetDataEvent(DATA, data, host, port));
        }
    }
}

/**
 * Event: ArtDMX (DMX data) received.
 */
class ArtDMXEvent extends Event {
    public var dmx:ArtDMXPacket;
    public var host:String;
    public var port:Int;
    public function new(type:String, dmx:ArtDMXPacket, host:String, port:Int) {
        super(type, false, false);
        this.dmx = dmx;
        this.host = host;
        this.port = port;
    }
}

/**
 * Event: ArtPollReply (node discovery) received.
 */
class ArtPollReplyEvent extends Event {
    public var info:ArtPollReplyPacket;
    public var host:String;
    public var port:Int;
    public function new(type:String, info:ArtPollReplyPacket, host:String, port:Int) {
        super(type, false, false);
        this.info = info;
        this.host = host;
        this.port = port;
    }
}

/**
 * Event: Raw UDP data received (for unparsed/unknown packets).
 */
class ArtNetDataEvent extends Event {
    public var data:Bytes;
    public var host:String;
    public var port:Int;
    public function new(type:String, data:Bytes, host:String, port:Int) {
        super(type, false, false);
        this.data = data;
        this.host = host;
        this.port = port;
    }
}

/**
 * Event: Socket error.
 */
class ArtNetErrorEvent extends Event {
    public var message:String;
    public function new(type:String, message:String) {
        super(type, false, false);
        this.message = message;
    }
}
