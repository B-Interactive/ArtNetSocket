package binteractive.artnetsocket;

import openfl.events.EventDispatcher;
import openfl.events.Event;
import openfl.net.DatagramSocket;
import openfl.events.DatagramSocketDataEvent;
import openfl.events.IOErrorEvent;
import openfl.utils.ByteArray;
import binteractive.artnetsocket.ArtNetHelper;
import binteractive.artnetsocket.ArtNetSocketEvents;
import binteractive.artnetsocket.ArtNetTypes;
import binteractive.artnetsocket.ArtNetNetworkUtil;

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
     * Loads config and prioritizes explicit config values for address, port, and subnet.
     * @param configPath Optional: path to config file
     */
    public function new(configPath:String = "artnetsocket.config.json") {
        super();
        var config = ArtNetNetworkUtil.loadConfig(configPath);
        this.address = ArtNetNetworkUtil.getBindInterface(config);
        this.port = config.port;

        if (!DatagramSocket.isSupported) {
            dispatchEvent(new ArtNetErrorEvent(ERROR, "DatagramSocket is not supported on this platform."));
            return;
        }

        socket = new DatagramSocket();
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
     * Send an ArtDMX packet to a single address.
     * @param pkt ArtDMXPacket structure
     * @param host Target IP address
     * @param port Target UDP port (default 6454)
     */
    public function sendDMX(pkt:ArtDMXPacket, host:String, port:Int = 6454):Void {
        if (socket == null) return;
        var bytes:ByteArray = ArtNetHelper.encodeDMX(pkt);
        try {
            socket.send(host, port, bytes);
        } catch (e:Dynamic) {
            dispatchEvent(new ArtNetErrorEvent(ERROR, "Failed to send DMX: " + Std.string(e)));
        }
    }

    /**
     * Simulate UDP broadcast by sending to each address in configured or detected subnet.
     * @param pkt ArtDMXPacket structure
     * @param config Optional: network config to use
     */
    public function broadcastDMX(pkt:ArtDMXPacket, config:Dynamic = null):Void {
        if (socket == null) return;
        if (config == null) config = ArtNetNetworkUtil.loadConfig();
        var subnet = ArtNetNetworkUtil.getPrivateSubnet(config);
        var bytes:ByteArray = ArtNetHelper.encodeDMX(pkt);
        var localIP = ArtNetNetworkUtil.getBindInterface(config);
        for (i in 1...255) {
            var ip = subnet + i;
            if (ip != localIP) {
                try {
                    socket.send(ip, port, bytes);
                } catch (e:Dynamic) {
                    // Optionally log errors per IP
                }
            }
        }
    }

    /**
     * Send an ArtPoll packet (node discovery) to every address in the subnet.
     * @param config Optional: network config to use
     */
    public function broadcastPoll(config:Dynamic = null):Void {
        if (socket == null) return;
        if (config == null) config = ArtNetNetworkUtil.loadConfig();
        var subnet = ArtNetNetworkUtil.getPrivateSubnet(config);
        var bytes:ByteArray = ArtNetHelper.encodePoll();
        var localIP = ArtNetNetworkUtil.getBindInterface(config);
        for (i in 1...255) {
            var ip = subnet + i;
            if (ip != localIP) {
                try {
                    socket.send(ip, port, bytes);
                } catch (e:Dynamic) {
                    // Optionally log errors per IP
                }
            }
        }
    }

    /**
     * Internal event handler for received UDP data.
     * Parses ArtDMX and ArtPollReply, dispatches events.
     */
    private function onSocketData(e:DatagramSocketDataEvent):Void {
        var bytes:ByteArray = e.data;
        var host = e.srcAddress;
        var port = e.srcPort;

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
