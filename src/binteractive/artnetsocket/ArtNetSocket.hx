package binteractive.artnetsocket;

import openfl.events.DatagramSocketDataEvent;
import openfl.events.IOErrorEvent;
import openfl.net.DatagramSocket;
import openfl.utils.ByteArray;
import openfl.events.EventDispatcher;
import binteractive.artnetsocket.ArtNetSocketEvents;
import binteractive.artnetsocket.ArtNetTypes;
import binteractive.artnetsocket.ArtNetProtocolUtil;
import binteractive.artnetsocket.ArtNetNetworkUtil;

/**
 * ArtNetSocket
 *
 * Handles Art-Net UDP communication for DMX lighting control.
 * - Binds to a local UDP port for receiving/sending Art-Net packets.
 * - Supports sending ArtDMX packets, broadcasting DMX (simulated), and ArtPoll (discovery).
 * - Exposes event-based API for integration with OpenFL/Haxe projects.
 *
 * NOTE: Broadcast is simulated for maximum compatibility, sending packets
 * to each IP in the local subnet. This is because OpenFL's DatagramSocket
 * does not reliably support true UDP broadcast on all platforms.
 */
class ArtNetSocket extends EventDispatcher {
    // Event type constants for listeners.
    public static inline var ARTDMX:String = "artdmx";
    public static inline var ARTPOLLREPLY:String = "artpollreply";
    public static inline var DATA:String = "data";
    public static inline var ERROR:String = "error";

    private var socket:DatagramSocket; // UDP socket for Art-Net communication
    private var port:Int;              // UDP port to bind
    private var address:String;        // Local address to bind

    public var defaultUniverse:Int;    // Default Art-Net universe for DMX packets
    public var defaultLength:Int;      // Default DMX packet length
    public var persistentDMX:Bool;     // Whether to use persistent DMX buffering (default true)
    
    private var dmxBuffer:Array<Int>;  // Persistent DMX buffer for retaining channel values

    /**
     * Constructor: Initializes and binds the UDP socket.
     * @param address Local IP address to bind (default "0.0.0.0" for all interfaces)
     * @param port UDP port to bind (default 6454 for Art-Net)
     * @param defaultUniverse Default universe for DMX packets (default 0)
     * @param defaultLength Default DMX packet length (default 512)
     */
    public function new(?address:String, ?port:Int, ?defaultUniverse:Int, ?defaultLength:Int) {
        super();
        this.address = address != null ? address : "0.0.0.0";
        this.port = port != null ? port : 6454;
        this.defaultUniverse = defaultUniverse != null ? defaultUniverse : 0;
        this.defaultLength = defaultLength != null ? defaultLength : 512;
        this.persistentDMX = true; // Default to persistent DMX buffering
        
        // Initialize DMX buffer with 512 channels, all set to 0
        this.dmxBuffer = new Array<Int>();
        for (i in 0...512) {
            this.dmxBuffer[i] = 0;
        }

        // Check platform support for UDP sockets.
        if (!DatagramSocket.isSupported) {
            dispatchEvent(new ArtNetErrorEvent(ERROR, "DatagramSocket is not supported on this platform."));
            return;
        }

        // Create and bind the UDP socket.
        socket = new DatagramSocket();
        socket.addEventListener(DatagramSocketDataEvent.DATA, onSocketData);
        socket.addEventListener(IOErrorEvent.IO_ERROR, onSocketError);

        try {
            socket.bind(this.port, this.address);
            socket.receive();
        } catch (e:Dynamic) {
            dispatchEvent(new ArtNetErrorEvent(ERROR, "Failed to bind DatagramSocket: " + Std.string(e)));
        }
    }

    /**
     * Closes the socket and removes event listeners.
     * Safe to call multiple times.
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
     * Sends an ArtDMX packet to a specific IP address.
     * @param pkt ArtDMXPacket structure (created via makeDMXPacket)
     * @param host Target IP address
     * @param port Target UDP port (default 6454)
     */
    public function sendDMX(pkt:ArtDMXPacket, host:String, port:Int = 6454):Void {
        if (socket == null) return;
        var bytes:ByteArray = ArtNetProtocolUtil.encodeDMX(pkt);
        try {
            socket.send(bytes, host, port);
        } catch (e:Dynamic) {
            dispatchEvent(new ArtNetErrorEvent(ERROR, "Failed to send DMX packet: " + Std.string(e)));
        }
    }

    /**
     * Simulates broadcast of an ArtDMX packet by sending to each host in the local subnet.
     * This works around unreliable platform broadcast support.
     * @param pkt ArtDMXPacket structure
     * @param port Target UDP port (default 6454)
     * @param subnetPrefix Optional subnet prefix (e.g., "192.168.1.") for custom broadcast range
     */
    public function broadcastDMX(pkt:ArtDMXPacket, port:Int = 6454, ?subnetPrefix:String):Void {
        if (socket == null) return;
        var bytes:ByteArray = ArtNetProtocolUtil.encodeDMX(pkt);

        // Determine subnet prefix (default: using first local IPv4 address)
        var subnet = subnetPrefix;
        if (subnet == null) {
            var ips = ArtNetNetworkUtil.getLocalIPv4s();
            if (ips.length > 0) {
                var ipParts = ips[0].split(".");
                if (ipParts.length == 4) {
                    subnet = ipParts[0] + "." + ipParts[1] + "." + ipParts[2] + ".";
                }
            }
        }
        if (subnet == null) subnet = "192.168.1.";

        // Send DMX to each IP in the subnet (1-254)
        for (i in 1...255) {
            var target = subnet + i;
            // Optionally skip sending to own IP
            if (target != this.address) {
                try {
                    socket.send(bytes, target, port);
                } catch (e:Dynamic) {
                    // Ignore errors for unreachable hosts
                }
            }
        }
    }

    /**
     * Simulates broadcast of an ArtPoll packet by sending to each host in the local subnet.
     * This works around unreliable platform broadcast support.
     * @param port Target UDP port (default 6454)
     * @param subnetPrefix Optional subnet prefix (e.g., "192.168.1.") for custom broadcast range
     */
    public function broadcastPoll(port:Int = 6454, ?subnetPrefix:String):Void {
        if (socket == null) return;
        var bytes:ByteArray = ArtNetProtocolUtil.encodePoll();

        // Determine subnet prefix (default: using first local IPv4 address)
        var subnet = subnetPrefix;
        if (subnet == null) {
            var ips = ArtNetNetworkUtil.getLocalIPv4s();
            if (ips.length > 0) {
                var ipParts = ips[0].split(".");
                if (ipParts.length == 4) {
                    subnet = ipParts[0] + "." + ipParts[1] + "." + ipParts[2] + ".";
                }
            }
        }
        if (subnet == null) subnet = "192.168.1.";

        // Send ArtPoll to each IP in the subnet (1-254)
        for (i in 1...255) {
            var target = subnet + i;
            if (target != this.address) {
                try {
                    socket.send(bytes, target, port);
                } catch (e:Dynamic) {
                    // Ignore errors for unreachable hosts
                }
            }
        }
    }

    /**
     * Sends an ArtPoll packet (legacy, single address: broadcast)
     * Provided for API compatibility, but may not work on all platforms.
     * Prefer broadcastPoll for reliability.
     * @param port Target UDP port (default 6454)
     */
    public function sendPoll(port:Int = 6454):Void {
        if (socket == null) return;
        var bytes:ByteArray = ArtNetProtocolUtil.encodePoll();
        try {
            socket.send(bytes, "255.255.255.255", port);
        } catch (e:Dynamic) {
            dispatchEvent(new ArtNetErrorEvent(ERROR, "Failed to send ArtPoll packet: " + Std.string(e)));
        }
    }

    /**
     * Creates an ArtDMXPacket from DMX channel data.
     * Supported input types:
     *   - Array<Int>: DMX values for channels [0..N]
     *   - Map<Int,Int>: Per-channel updates (channel index -> value)
     *   - ByteArray: DMX values for channels [0..N]
     *
     * When persistentDMX is true (default), unspecified channels retain their
     * previous values. When false, the buffer is reset to zero before each packet.
     *
     * @param input DMX data (Array<Int>, Map<Int,Int>, or ByteArray)
     * @param ?universe Optional universe override
     * @param ?length Optional length override
     * @return ArtDMXPacket structure ready for sending
     */
    public function makeDMXPacket(input:Dynamic, ?universe:Int, ?length:Int):ArtDMXPacket {
        var finalUniverse = universe != null ? universe : defaultUniverse;
        var finalLength = length != null ? length : defaultLength;

        // If persistentDMX is false, reset buffer to zero
        if (!persistentDMX) {
            for (i in 0...512) {
                dmxBuffer[i] = 0;
            }
        }

        // Process input based on type
        if (Std.isOfType(input, Array)) {
            // Array<Int> or Array<Null<Int>> input: DMX values for channels [0..N]
            var arr:Array<Dynamic> = cast input;
            finalLength = Std.int(Math.max(finalLength, arr.length));
            for (i in 0...arr.length) {
                if (i < 512) {
                    var value = arr[i];
                    // When persistentDMX is true, null or -1 means "no change"
                    // When persistentDMX is false, null or -1 means 0
                    if (value != null && value != -1) {
                        dmxBuffer[i] = value;
                    } else if (!persistentDMX) {
                        dmxBuffer[i] = 0;
                    }
                    // When persistentDMX is true and value is null/-1, keep existing value
                }
            }
        }
        else if (Std.isOfType(input, haxe.ds.IntMap)) {
        // IntMap<Int> input: Per-channel updates
        var map:haxe.ds.IntMap<Int> = cast input;
        for (channel in map.keys()) {
            if (channel >= 0 && channel < 512) {
                var value = map.get(channel);
                if (value != null && value != -1) {
                    dmxBuffer[channel] = value;
                    // Update finalLength if needed to include this channel
                    finalLength = Std.int(Math.max(finalLength, channel + 1));
                }
            }
        }
    }
        else if (Std.isOfType(input, ByteArray)) {
            // ByteArray input: DMX values for channels [0..N]
            var byteArray:ByteArray = cast input;
            finalLength = Std.int(Math.max(finalLength, byteArray.length));
            byteArray.position = 0;
            for (i in 0...byteArray.length) {
                if (i < 512) {
                    dmxBuffer[i] = byteArray.readUnsignedByte();
                }
            }
        }
        else {
            throw "Invalid argument for makeDMXPacket. Supported types: Array<Int>, Map<Int,Int>, ByteArray";
        }

        // Clamp length to 512 channels
        if (finalLength > 512) finalLength = 512;

        // Create output ByteArray from buffer
        var packetData = new ByteArray();
        for (i in 0...finalLength) {
            packetData.writeByte(dmxBuffer[i]);
        }
        packetData.position = 0;

        // Return ArtDMXPacket structure
        return {
            protocolVersion: 14,
            sequence: 0,
            physical: 0,
            universe: finalUniverse,
            length: finalLength,
            data: packetData
        };
    }

    /**
     * Event handler for received UDP data.
     * Parses Art-Net packets and dispatches relevant events.
     * Supported packets:
     *   - ArtDMX: Triggers ARTDMX event with parsed DMX data.
     *   - ArtPollReply: Triggers ARTPOLLREPLY event with node info.
     *   - Other: Triggers DATA event with raw UDP data.
     *
     * @param e DatagramSocketDataEvent containing UDP packet data.
     */
    private function onSocketData(e:DatagramSocketDataEvent):Void {
        var ba:ByteArray = e.data;
        var host = e.srcAddress;
        var port = e.srcPort;

        ba.position = 0;
        // Check for valid Art-Net header
        var id:String = ba.readUTFBytes(8);
        if (id != ArtNetProtocolUtil.ARTNET_ID) {
            dispatchEvent(new ArtNetDataEvent(DATA, ba, host, port));
            return;
        }

        // Read opcode (little endian)
        var opCode:Int = ba.readUnsignedByte() | (ba.readUnsignedByte() << 8);

        switch (opCode) {
            case ArtNetProtocolUtil.OP_DMX:
                var dmxPacket:ArtNetTypes.ArtDMXPacket = ArtNetProtocolUtil.decodeDMX(ba);
                if (dmxPacket != null) {
                    dispatchEvent(new ArtDMXEvent(ARTDMX, dmxPacket, host, port));
                }
            case ArtNetProtocolUtil.OP_POLL:
                // ArtPoll requests are typically only relevant for nodes.
                // You may optionally dispatch a custom event or just ignore.

            case ArtNetProtocolUtil.OP_POLL_REPLY: // ArtPollReply
                var pollReply:ArtNetTypes.ArtPollReplyPacket = ArtNetProtocolUtil.decodePollReply(ba);

                // Ensure required fields are set (fallback to sender if not present)
                if (pollReply.ip == null || pollReply.ip == "") pollReply.ip = host;
                if (pollReply.bindIp == null || pollReply.bindIp == "") pollReply.bindIp = host;
                if (pollReply.port == null) pollReply.port = port;

                dispatchEvent(new ArtPollReplyEvent(ARTPOLLREPLY, pollReply, host, port));

            default:
                // Fallback for unrecognized packets: raw data
                dispatchEvent(new ArtNetDataEvent(DATA, ba, host, port));
        }
    }


    /**
     * Event handler for socket errors.
     * Dispatches an error event with the message.
     * @param e IOErrorEvent
     */
    private function onSocketError(e:IOErrorEvent):Void {
        dispatchEvent(new ArtNetErrorEvent(ERROR, "Socket IO error: " + Std.string(e)));
    }
}
