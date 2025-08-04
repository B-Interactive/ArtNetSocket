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
     *   - Array<Null<Int>>: DMX values for channels [0..N]
     *   - Object/StringMap:
     *       - "data": ByteArray (DMX values for channels)
     *       - "universe": Art-Net universe (overrides default)
     *       - "length": Number of channels to send (overrides default)
     *
     * @param input DMX data (array, object, or StringMap)
     * @param ?universe Optional universe override
     * @param ?length Optional length override
     * @return ArtDMXPacket structure ready for sending
     */
    public function makeDMXPacket(input:Dynamic, ?universe:Int, ?length:Int):ArtDMXPacket {
        var finalUniverse = universe != null ? universe : defaultUniverse;
        var finalLength = length != null ? length : defaultLength;
        var resultBuffer:ByteArray = new ByteArray();

        // Initialize buffer to zero for all 512 DMX channels.
        for (i in 0...512) resultBuffer.writeByte(0);
        resultBuffer.position = 0;

        // Array input: [DMX1, DMX2, ...]
        if (Std.is(input, Array)) {
            var arr:Array<Null<Int>> = cast input;
            finalLength = arr.length;
            for (i in 0...arr.length) {
                var v:Null<Int> = arr[i];
                // Null/-1 means 0 (failsafe)
                resultBuffer[i] = (v == null || v == -1) ? 0 : v;
            }
        }
        // Object input: {data: ByteArray, universe: Int, length: Int}
        else if (Reflect.isObject(input) && !Std.is(input, StringMap)) {
            if (Reflect.hasField(input, "universe")) finalUniverse = Reflect.field(input, "universe");
            if (Reflect.hasField(input, "length")) finalLength = Reflect.field(input, "length");
            if (Reflect.hasField(input, "data")) {
                var data:ByteArray = Reflect.field(input, "data");
                finalLength = data.length;
                for (i in 0...data.length)
                    if (i < 512)
                        resultBuffer[i] = data[i];
            }
        }
        // StringMap input: same as object, but using map methods
        else if (Std.is(input, StringMap)) {
            var map:StringMap<Dynamic> = cast input;
            if (map.exists("universe")) finalUniverse = map.get("universe");
            if (map.exists("length")) finalLength = map.get("length");
            if (map.exists("data")) {
                var data:ByteArray = map.get("data");
                finalLength = data.length;
                for (i in 0...data.length)
                    if (i < 512)
                        resultBuffer[i] = data[i];
            }
        }
        else throw "Invalid argument for makeDMXPacket";

        // Clamp length to 512 channels
        if (finalLength > 512) finalLength = 512;

        // Copy buffer data for output
        var packetData = new ByteArray();
        packetData.writeBytes(resultBuffer, 0, finalLength);
        packetData.position = 0;

        // Return a structure matching ArtDMXPacket typedef
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
                var protocolVersion:Int = ba.readUnsignedByte() << 8 | ba.readUnsignedByte();
                var sequence:Int = ba.readUnsignedByte();
                var physical:Int = ba.readUnsignedByte();
                var universe:Int = ba.readUnsignedByte() | (ba.readUnsignedByte() << 8);
                var length:Int = ba.readUnsignedByte() | (ba.readUnsignedByte() << 8);

                var data:ByteArray = new ByteArray();
                if (length > 0 && length <= 512 && ba.bytesAvailable >= length) {
                    ba.readBytes(data, 0, length);
                }
                data.position = 0;

                var packet:ArtNetTypes.ArtDMXPacket = {
                    protocolVersion: protocolVersion,
                    sequence: sequence,
                    physical: physical,
                    universe: universe,
                    length: length,
                    data: data
                };
                dispatchEvent(new ArtDMXEvent(ARTDMX, packet, host, port));

            case ArtNetProtocolUtil.OP_POLL:
                // ArtPoll requests are typically only relevant for nodes.
                // You may optionally dispatch a custom event or just ignore.

            case 0x2100: // ArtPollReply
                // Move parsing to ArtNetProtocolUtil for clarity
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
