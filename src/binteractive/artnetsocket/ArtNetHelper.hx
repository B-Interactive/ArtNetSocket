package binteractive.artnetsocket;

import openfl.utils.ByteArray;
import binteractive.artnetsocket.ArtNetTypes;

/**
 * Art-Net protocol helper for DMX, Poll, and PollReply packets.
 * All buffers are Little Endian per Art-Net specification.
 * Compatible with Haxe 4.3.7 and OpenFL 9.4.1.
 */
class ArtNetHelper {
    /** Art-Net Protocol ID (8 bytes, zero-padded) */
    public static final ARTNET_ID:String = "Art-Net\x00";
    public static final OP_POLL:Int = 0x2000;
    public static final OP_POLLREPLY:Int = 0x2100;
    public static final OP_DMX:Int = 0x5000;

    /**
     * Write a 16-bit integer (short) in little-endian order.
     * OpenFL's ByteArray uses little-endian by default.
     */
    private static function writeUInt16LE(ba:ByteArray, value:Int):Void {
        ba.writeByte(value & 0xFF);
        ba.writeByte((value >> 8) & 0xFF);
    }

    /**
     * Read a 16-bit unsigned integer (short) in little-endian order.
     */
    private static function readUInt16LE(ba:ByteArray, pos:Int):Int {
        return ba[pos] | (ba[pos + 1] << 8);
    }

    /**
     * Serializes an ArtDMXPacket into a ByteArray buffer.
     * @param pkt ArtDMXPacket structure
     * @return ByteArray ready for sending via UDP
     */
    public static function encodeDMX(pkt:ArtDMXPacket):ByteArray {
        var ba = new ByteArray();
        ba.endian = "littleEndian";
        ba.writeUTFBytes(ARTNET_ID); // 8 bytes: "Art-Net\0"
        writeUInt16LE(ba, OP_DMX); // OpCode: ArtDMX
        writeUInt16LE(ba, pkt.protocolVersion); // Protocol version
        ba.writeByte(pkt.sequence);
        ba.writeByte(pkt.physical);
        writeUInt16LE(ba, pkt.universe);
        writeUInt16LE(ba, pkt.length);
        ba.writeBytes(pkt.data, 0, pkt.length);
        ba.position = 0;
        return ba;
    }

    /**
     * Parses a ByteArray buffer into an ArtDMXPacket structure.
     * @param ba ByteArray buffer (minimum 18 bytes)
     * @return ArtDMXPacket or null if invalid
     */
    public static function decodeDMX(ba:ByteArray):Null<ArtDMXPacket> {
        if (ba.length < 18) return null;
        if (ba.readUTFBytes(8) != ARTNET_ID) return null;
        var opcode = readUInt16LE(ba, 8);
        if (opcode != OP_DMX) return null;
        var protocolVersion = readUInt16LE(ba, 10);
        var sequence = ba[12];
        var physical = ba[13];
        var universe = readUInt16LE(ba, 14);
        var len = readUInt16LE(ba, 16);
        if (ba.length < 18 + len) return null;
        var data = new ByteArray();
        ba.position = 18;
        ba.readBytes(data, 0, len);
        data.position = 0;
        // Restore position for further parsing if required
        ba.position = 0;
        return {
            protocolVersion: protocolVersion,
            sequence: sequence,
            physical: physical,
            universe: universe,
            length: len,
            data: data
        };
    }

    /**
     * Serializes a minimal ArtPoll packet (standard for node discovery).
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

    // Add decodePollReply if needed for your use case!
}
