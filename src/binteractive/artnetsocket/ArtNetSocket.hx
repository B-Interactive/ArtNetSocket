package binteractive.artnetsocket;

import openfl.events.EventDispatcher;
import openfl.events.Event;
import haxe.io.Bytes;
import binteractive.artnetsocket.ArtNetHelper;

#if (air || flash)
import openfl.net.DatagramSocket;
import openfl.events.DatagramSocketDataEvent;
import openfl.events.IOErrorEvent;
#else
import sys.net.UdpSocket;
import sys.net.Host;
import openfl.Lib;
import binteractive.artnetsocket.ArtNetSocketPoller;
#end

/**
 * ArtNetSocket
 *
 * Cross-platform, event-driven UDP socket tailored for Art-Net (OpenFL/Haxe 4.3+).
 * - Native (C++, HL): Non-blocking with polling thread (using ArtNetSocketPoller).
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
    private var socket:DatagramSocket;
    #else
    private var socket:UdpSocket;
    private var poller:ArtNetSocketPoller;
    #end

    private var port:Int;

    /**
     * Binds and opens a socket on the specified UDP port.
     * @param port UDP port (default for Art-Net is 6454)
     */
    public function new(port:Int = 6454) {
        super();
        this.port = port;
        #if (air || flash)
        // AIR/Flash: Use event-driven DatagramSocket
        socket = new DatagramSocket();
        socket.addEventListener(DatagramSocketDataEvent.DATA, onSocketData);
        socket.addEventListener(IOErrorEvent.IO_ERROR, onSocketError);
        socket.bind(port, "0.0.0.0");
        socket.receive();
        #else
        // Native: Use non-blocking socket with background polling
        socket = new UdpSocket();
        socket.setBlocking(false);
        socket.bind(new Host("0.0.0.0"), port);
        poller = new ArtNetSocketPoller(socket, this);
        // Listen for custom poll events & forward to core handler
        addEventListener("ArtNetSocketPollEvent", function(e:ArtNetSocketPollEvent) {
            onDataReceived(e.data, e.host, e.port);
        });
        poller.start();
        #end
    }

    /**
     * Closes the socket and stops background polling (if native).
     */
    public function close():Void {
        #if (air || flash)
        socket.close();
        #else
        poller.stop();
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
     * @param host Destination IP (default "255.255.255.255" for broadcast)
     * @param port UDP port (default 6454)
     */
    public function sendPoll(host:String = "255.255.255.255", port:Int = 6454):Void {
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
    /**
     * AIR/Flash: DatagramSocket data event handler.
     * @param e DatagramSocketDataEvent containing received data.
     */
    private function onSocketData(e:DatagramSocketDataEvent):Void {
        onDataReceived(Bytes.ofData(e.data), e.srcAddress, e.srcPort);
    }

    /**
     * AIR/Flash: DatagramSocket error event handler.
     * @param e IOErrorEvent containing error text.
     */
    private function onSocketError(e:IOErrorEvent):Void {
        dispatchEvent(new ArtNetErrorEvent(ERROR, e.text));
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
                    // Unknown Art-Net type, handled as raw data below
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
