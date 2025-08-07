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
 * - Supports sending ArtDMX packets, broadcasting DMX (on cpp/neko only), and ArtPoll (discovery on cpp/neko only).
 * - Exposes event-based API for integration with OpenFL/Haxe projects.
 *
 * NOTE: DMX and ArtPoll broadcasting use native UDP broadcast on cpp/neko targets.
 * On other targets, broadcast operations will throw an error as they are not supported.
 */
class ArtNetSocket extends EventDispatcher {
    // Event type constants for listeners.
    public static inline var ARTDMX:String = "artdmx";
    public static inline var ARTPOLLREPLY:String = "artpollreply";
    public static inline var DATA:String = "data";
    public static inline var ERROR:String = "error";
    
    // Default Art-Net UDP port
    public static inline var DEFAULT_PORT:Int = 6454;

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
        this.port = port != null ? port : DEFAULT_PORT;
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
     * @param pkt ArtDMXPacket structure (created via makeDMXFromArray, makeDMXFromMap, or makeDMXFromByteArray)
     * @param host Target IP address
     * @param port Target UDP port (default 6454)
     */
    public function sendDMX(pkt:ArtDMXPacket, host:String, port:Int = DEFAULT_PORT):Void {
        if (socket == null) return;
        var bytes:ByteArray = ArtNetProtocolUtil.encodeDMX(pkt);
        try {
            socket.send(bytes, host, port);
        } catch (e:Dynamic) {
            dispatchEvent(new ArtNetErrorEvent(ERROR, "Failed to send DMX packet: " + Std.string(e)));
        }
    }

    /**
     * Broadcasts an ArtDMX packet via UDP broadcast to 255.255.255.255.
     * For cpp and neko targets, uses sys.net.UdpSocket directly for true UDP broadcast.
     * For all other targets, throws an error as UDP broadcast is not supported.
     * @param pkt ArtDMXPacket structure
     * @param port Target UDP port (default 6454)
     */
    public function broadcastDMX(pkt:ArtDMXPacket, port:Int = DEFAULT_PORT):Void {
        #if (cpp || neko)
            var bytes:ByteArray = ArtNetProtocolUtil.encodeDMX(pkt);
            var udpSocket = new sys.net.UdpSocket();
            try {
                udpSocket.setBroadcast(true);
                udpSocket.sendTo(bytes.getData(), 0, bytes.length, 
                    new sys.net.Host("255.255.255.255"), port);
                udpSocket.close();
            } catch (e:Dynamic) {
                if (udpSocket != null) udpSocket.close();
                dispatchEvent(new ArtNetErrorEvent(ERROR, "Failed to broadcast DMX packet: " + Std.string(e)));
            }
        #else
            dispatchEvent(new ArtNetErrorEvent(ERROR, "DMX broadcast (broadcastDMX) is only supported on cpp and neko targets."));
        #end
    }



    /**
     * Sends an ArtPoll packet via UDP broadcast to 255.255.255.255.
     * For cpp and neko targets, uses sys.net.UdpSocket directly for true UDP broadcast.
     * For all other targets, throws an error as UDP broadcast is not supported.
     * @param port Target UDP port (default 6454)
     */
    public function sendPoll(port:Int = DEFAULT_PORT):Void {
        #if (cpp || neko)
            var bytes:ByteArray = ArtNetProtocolUtil.encodePoll();
            var udpSocket = new sys.net.UdpSocket();
            try {
                udpSocket.setBroadcast(true);
                udpSocket.sendTo(bytes.getData(), 0, bytes.length, 
                    new sys.net.Host("255.255.255.255"), port);
                udpSocket.close();
            } catch (e:Dynamic) {
                if (udpSocket != null) udpSocket.close();
                dispatchEvent(new ArtNetErrorEvent(ERROR, "Failed to send ArtPoll broadcast: " + Std.string(e)));
            }
        #else
            dispatchEvent(new ArtNetErrorEvent(ERROR, "ArtPoll broadcast (sendPoll) is only supported on cpp and neko targets."));
        #end
    }

    /**
     * Creates an ArtDMXPacket from an Array of DMX channel values.
     * When persistentDMX is true (default), null or -1 values mean "no change" - 
     * those channels retain their previous values. When false, null or -1 become 0.
     *
     * @param arr Array of DMX values for channels [0..N], null or -1 values mean "no change" when persistentDMX is true
     * @param ?universe Optional universe override
     * @param ?length Optional length override
     * @return ArtDMXPacket structure ready for sending
     */
    public function makeDMXFromArray(arr:Array<Null<Int>>, ?universe:Int, ?length:Int):ArtDMXPacket {
        var finalUniverse = universe != null ? universe : defaultUniverse;
        var finalLength = length != null ? length : defaultLength;

        // If persistentDMX is false, reset buffer to zero
        if (!persistentDMX) {
            for (i in 0...512) {
                dmxBuffer[i] = 0;
            }
        }

        // Array<Int> input: DMX values for channels [0..N]
        finalLength = Std.int(Math.max(finalLength, arr.length));
        for (i in 0...arr.length) {
            if (i < 512) {
                var value:Null<Int> = arr[i];
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

        return createDMXPacket(finalUniverse, finalLength);
    }

    /**
     * Creates an ArtDMXPacket from an IntMap of per-channel updates.
     * When persistentDMX is true (default), only specified channels are updated,
     * others retain their previous values. When false, unspecified channels become 0.
     *
     * @param map Per-channel updates (channel index -> value)
     * @param ?universe Optional universe override
     * @param ?length Optional length override
     * @return ArtDMXPacket structure ready for sending
     */
    public function makeDMXFromMap(map:haxe.ds.IntMap<Int>, ?universe:Int, ?length:Int):ArtDMXPacket {
        var finalUniverse = universe != null ? universe : defaultUniverse;
        var finalLength = length != null ? length : defaultLength;

        // If persistentDMX is false, reset buffer to zero
        if (!persistentDMX) {
            for (i in 0...512) {
                dmxBuffer[i] = 0;
            }
        }

        // IntMap<Int> input: Per-channel updates
        for (channel in map.keys()) {
            if (channel >= 0 && channel < 512) {
                var value:Null<Int> = map.get(channel);
                if (value != null && value != -1) {
                    dmxBuffer[channel] = value;
                    // Update finalLength if needed to include this channel
                    finalLength = Std.int(Math.max(finalLength, channel + 1));
                }
            }
        }

        return createDMXPacket(finalUniverse, finalLength);
    }

    /**
     * Creates an ArtDMXPacket from a ByteArray containing DMX channel values.
     * When persistentDMX is true (default), only channels present in the ByteArray
     * are updated, others retain their previous values. When false, unspecified channels become 0.
     *
     * @param ba ByteArray containing DMX values for channels [0..N]
     * @param ?universe Optional universe override
     * @param ?length Optional length override
     * @return ArtDMXPacket structure ready for sending
     */
    public function makeDMXFromByteArray(ba:ByteArray, ?universe:Int, ?length:Int):ArtDMXPacket {
        var finalUniverse = universe != null ? universe : defaultUniverse;
        var finalLength = length != null ? length : defaultLength;

        // If persistentDMX is false, reset buffer to zero
        if (!persistentDMX) {
            for (i in 0...512) {
                dmxBuffer[i] = 0;
            }
        }

        // ByteArray input: DMX values for channels [0..N]
        finalLength = Std.int(Math.max(finalLength, ba.length));
        ba.position = 0;
        for (i in 0...ba.length) {
            if (i < 512) {
                dmxBuffer[i] = ba.readUnsignedByte();
            }
        }

        return createDMXPacket(finalUniverse, finalLength);
    }

    /**
     * Internal helper method to create the final ArtDMXPacket from the DMX buffer.
     * @param universe Universe number
     * @param length Number of channels
     * @return ArtDMXPacket structure
     */
    private function createDMXPacket(universe:Int, length:Int):ArtDMXPacket {
        // Clamp length to 512 channels
        if (length > 512) length = 512;

        // Create output ByteArray from buffer
        var packetData = new ByteArray();
        for (i in 0...length) {
            packetData.writeByte(dmxBuffer[i]);
        }
        packetData.position = 0;

        // Return ArtDMXPacket structure
        return {
            protocolVersion: 14,
            sequence: 0,
            physical: 0,
            universe: universe,
            length: length,
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
                if (pollReply.port == 0) pollReply.port = port;

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
