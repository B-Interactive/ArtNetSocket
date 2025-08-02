package binteractive.artnetsocket;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
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
    private static function readUInt16LE(bytes:Bytes, pos:Int):Int {
        return bytes.get(pos) | (bytes.get(pos + 1) << 8);
    }

    /**
     * Serializes an ArtDMXPacket into a Bytes buffer.
     * @param pkt ArtDMXPacket structure
     * @return Bytes ready for sending via UDP
     */
    public static function encodeDMX(pkt:ArtDMXPacket):Bytes {
        var ba = new ByteArray();
        ba.endian = "littleEndian";
        ba.writeUTFBytes(ARTNET_ID); // 8 bytes: "Art-Net\0"
        writeUInt16LE(ba, OP_DMX); // OpCode: ArtDMX
        writeUInt16LE(ba, pkt.protocolVersion); // Protocol version
        ba.writeByte(pkt.sequence);
        ba.writeByte(pkt.physical);
        writeUInt16LE(ba, pkt.universe);
        writeUInt16LE(ba, pkt.length);
        ba.writeBytes(Bytes.ofData(pkt.data.getData()), 0, pkt.length);
        ba.position = 0;
        return Bytes.ofData(ba);
    }

    /**
     * Parses a Bytes buffer into an ArtDMXPacket structure.
     * @param data Bytes buffer (minimum 18 bytes)
     * @return ArtDMXPacket or null if invalid
     */
    public static function decodeDMX(data:Bytes):Null<ArtDMXPacket> {
        if (data.length < 18) return null;
        if (data.sub(0,8).toString() != ARTNET_ID) return null;
        var opcode = readUInt16LE(data, 8);
        if (opcode != OP_DMX) return null;
        var len = readUInt16LE(data, 16);
        return {
            protocolVersion: readUInt16LE(data, 10),
            sequence: data.get(12),
            physical: data.get(13),
            universe: readUInt16LE(data, 14),
            length: len,
            data: data.sub(18, len)
        };
    }

    /**
     * Serializes a minimal ArtPoll packet (standard for node discovery).
     * @return Bytes ready for sending via UDP
     */
    public static function encodePoll():Bytes {
        var ba = new ByteArray();
        ba.endian = "littleEndian";
        ba.writeUTFBytes(ARTNET_ID); // 8 bytes: "Art-Net\0"
        writeUInt16LE(ba, OP_POLL);
        writeUInt16LE(ba, 14); // Protocol version
        ba.writeByte(0); // TalkToMe
        ba.writeByte(0); // Priority
        ba.position = 0;
        return Bytes.ofData(ba);
    }

    // Add decodePollReply if needed for your use case!
}
