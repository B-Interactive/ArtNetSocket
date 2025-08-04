package binteractive.artnetsocket;

import openfl.utils.ByteArray;
import binteractive.artnetsocket.ArtNetTypes;

/**
 * ArtNetProtocolUtil
 *
 * Stateless utilities for encoding Art-Net protocol packets.
 * Use to serialize ArtDMX and ArtPoll packets for transmission.
 */
class ArtNetProtocolUtil {
    public static inline var ARTNET_ID:String = "Art-Net\x00"; // Art-Net signature
    public static inline var OP_POLL:Int = 0x2000;           // OpCode for ArtPoll
    public static inline var OP_DMX:Int = 0x5000;            // OpCode for ArtDMX

    /**
     * Encodes an ArtDMXPacket into a ByteArray for UDP transmission.
     * @param pkt ArtDMXPacket structure
     * @return ByteArray containing ArtDMX packet
     */
    public static function encodeDMX(pkt:ArtDMXPacket):ByteArray {
        var ba = new ByteArray();
        ba.endian = "littleEndian";
        ba.writeUTFBytes(ARTNET_ID); // 8 bytes: "Art-Net\0"
        writeUInt16LE(ba, OP_DMX);   // OpCode
        writeUInt16LE(ba, pkt.protocolVersion);
        ba.writeByte(pkt.sequence);
        ba.writeByte(pkt.physical);
        writeUInt16LE(ba, pkt.universe); // Universe
        writeUInt16LE(ba, pkt.length);   // DMX data length
        ba.writeBytes(pkt.data, 0, pkt.length); // DMX data
        ba.position = 0;
        return ba;
    }

    /**
     * Encodes a minimal ArtPoll packet for node discovery.
     * @return ByteArray ready for sending via UDP
     */
    public static function encodePoll():ByteArray {
        var ba = new ByteArray();
        ba.endian = "littleEndian";
        ba.writeUTFBytes(ARTNET_ID); // 8 bytes: "Art-Net\0"
        writeUInt16LE(ba, OP_POLL);
        writeUInt16LE(ba, 14); // Protocol version
        ba.writeByte(0); // TalkToMe
        ba.writeByte(0); // Priority
        ba.position = 0;
        return ba;
    }

    /**
     * Helper: Writes a 16-bit unsigned integer in little-endian order.
     * @param ba Target ByteArray
     * @param value Integer value to write
     */
    private static function writeUInt16LE(ba:ByteArray, value:Int):Void {
        ba.writeByte(value & 0xFF);
        ba.writeByte((value >> 8) & 0xFF);
    }
}
