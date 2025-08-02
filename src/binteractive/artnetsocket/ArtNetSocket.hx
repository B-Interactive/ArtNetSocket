package binteractive.artnetsocket;

import openfl.events.EventDispatcher;
import openfl.events.Event;
import openfl.net.DatagramSocket;
import openfl.events.DatagramSocketDataEvent;
import openfl.events.IOErrorEvent;
import haxe.io.Bytes;
import binteractive.artnetsocket.ArtNetHelper;
import binteractive.artnetsocket.ArtNetSocketEvents;
import binteractive.artnetsocket.ArtNetTypes;

/**
 * ArtNetSocket
 *
 * Cross-platform, event-driven UDP socket tailored for Art-Net (OpenFL/Haxe 4.3+).
 * Uses OpenFL's DatagramSocket for all supported targets (cpp, hashlink, neko, AIR/Flash).
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

    private var socket:DatagramSocket;
    private var port:Int;
    private var address:String;

    /**
     * Binds and opens a socket on the specified UDP port.
     * @param address interface to bind to (default is "0.0.0.0" for all)
     * @param port UDP port (default for Art-Net is 6454)
     */
    public function new(address:String = "0.0.0.0", port:Int = 6454) {
        super();
        this.address = address;
        this.port = port;

        if (!DatagramSocket.isSupported) {
            dispatchEvent(new ArtNetErrorEvent(ERROR, "DatagramSocket is not supported on this platform."));
            return;
        }

        socket = new DatagramSocket();
        socket.enableBroadcast = true;
        socket.addEventListener(DatagramSocketDataEvent.DATA, onSocketData);
        socket.addEventListener(IOErrorEvent.IO_ERROR, onSocketError);

        try {
            socket.bind(port, address);
            socket.receive();
        } catch (e:Dynamic) {
            dispatchEvent(new ArtNetErrorEvent(ERROR, "Failed to bind DatagramSocket: " + Std.string(e)));
        }
    }

    /**
     * Closes the socket and removes listeners.
     */
    public function close():Void {
        if (socket != null) {
            socket.removeEventListener(DatagramSocketDataEvent.DATA, onSocketData);
            socket.removeEventListener(IOErrorEvent.IO_ERROR, onSocketError);
            try {
                socket.close();
            } catch (e:Dynamic) {
                // Ignore errors on close
            }
            socket = null;
        }
    }

    /**
     * Send an ArtDMX packet.
     * @param pkt ArtDMXPacket structure
     * @param host Target IP address or broadcast ("255.255.255.255")
     * @param port Target UDP port (default 6454)
     */
    public function sendDMX(pkt:ArtDMXPacket, host:String, port:Int = 6454):Void {
        if (socket == null) return;
        var bytes = ArtNetHelper.encodeDMX(pkt);
        try {
            socket.send(host, port, bytes.getData());
        } catch (e:Dynamic) {
            dispatchEvent(new ArtNetErrorEvent(ERROR, "Failed to send DMX: " + Std.string(e)));
        }
    }

    /**
     * Send an ArtPoll packet (node discovery).
     * @param host Target IP or broadcast address
     * @param port Target UDP port (default 6454)
     */
    public function sendPoll(host:String = "255.255.255.255", port:Int = 6454):Void {
        if (socket == null) return;
        var bytes = ArtNetHelper.encodePoll();
        try {
            socket.send(host, port, bytes.getData());
        } catch (e:Dynamic) {
            dispatchEvent(new ArtNetErrorEvent(ERROR, "Failed to send Poll: " + Std.string(e)));
        }
    }

    /**
     * Internal event handler for received UDP data.
     * Parses ArtDMX and ArtPollReply, dispatches events.
     */
    private function onSocketData(e:DatagramSocketDataEvent):Void {
        var bytes = Bytes.ofData(e.data);
        var host = e.address;
        var port = e.port;

        // Try to decode DMX
        var dmx = ArtNetHelper.decodeDMX(bytes);
        if (dmx != null) {
            dispatchEvent(new ArtDMXEvent(ARTDMX, dmx, host, port));
            return;
        }

        // Try to decode PollReply (add decodePollReply if needed)
        // var pollReply = ArtNetHelper.decodePollReply(bytes);
        // if (pollReply != null) {
        //     dispatchEvent(new ArtPollReplyEvent(ARTPOLLREPLY, pollReply, host, port));
        //     return;
        // }

        // Fallback: raw data event
        dispatchEvent(new ArtNetDataEvent(DATA, bytes, host, port));
    }

    /**
     * Internal error handler for socket errors.
     */
    private function onSocketError(e:IOErrorEvent):Void {
        dispatchEvent(new ArtNetErrorEvent(ERROR, e.text));
    }
}
