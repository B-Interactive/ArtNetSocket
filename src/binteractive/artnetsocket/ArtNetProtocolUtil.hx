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
    public static inline var OP_DMX:Int = 0x5000;            // OpCode for ArtDMX
    public static inline var OP_POLL:Int = 0x2000;           // OpCode for ArtPoll
    public static inline var OP_POLL_REPLY:Int = 0x2100;     // OpCode for ArtPollReply


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
     * Decodes an ArtDMX packet from a ByteArray.
     * @param ba ByteArray positioned just after the header and opcode.
     * @return ArtDMXPacket structure or null if invalid.
     */
    public static function decodeDMX(ba:ByteArray):ArtDMXPacket {
        // Position should be after header and opcode.
        // The next two bytes are protocol version (big endian)
        var protocolVersion:Int = ba.readUnsignedByte() << 8 | ba.readUnsignedByte();
        var sequence:Int = ba.readUnsignedByte();
        var physical:Int = ba.readUnsignedByte();
        var universe:Int = ba.readUnsignedByte() | (ba.readUnsignedByte() << 8);
        var length:Int = ba.readUnsignedByte() | (ba.readUnsignedByte() << 8);

        if (length < 1 || length > 512 || ba.bytesAvailable < length) {
            return null;
        }

        var data:ByteArray = new ByteArray();
        ba.readBytes(data, 0, length);
        data.position = 0;

        // Convert to Bytes for compatibility with ArtDMXPacket typedef
        #if (haxe_ver >= "4.0.0")
        var haxeBytes = haxe.io.Bytes.ofData(data);
        #else
        var haxeBytes = haxe.io.Bytes.alloc(length);
        for (i in 0...length) haxeBytes.set(i, data[i]);
        #end

        return {
            protocolVersion: protocolVersion,
            sequence: sequence,
            physical: physical,
            universe: universe,
            length: length,
            data: haxeBytes
        };
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
     * Decodes an ArtPollReply packet from a ByteArray.
     * @param ba ByteArray positioned just after the opcode.
     * @return ArtPollReplyPacket structure.
     */
    public static function decodePollReply(ba:ByteArray):ArtPollReplyPacket {
        // This expects ba.position is at the start of the packet (after header+opcode)
        // If not, adjust as needed.
        // For compatibility: skip protocol version bytes if present (depends on implementation)
        // For ArtPollReply, after header/opcode, protocol version is usually 2 bytes (skip)
        ba.position += 2;

        var ipBytes:Array<Int> = [];
        for (i in 0...4) ipBytes.push(ba.readUnsignedByte());
        var ip = ipBytes.join(".");

        var portVal = ba.readUnsignedShort();
        var version = ba.readUnsignedShort();
        var shortName = ba.readUTFBytes(18);
        var longName = ba.readUTFBytes(18);
        var nodeReport = ba.readUTFBytes(64);
        var oem = ba.readUnsignedShort();
        var numPorts = ba.readUnsignedByte();

        var portTypes:Array<Int> = [];
        for (i in 0...4) portTypes.push(ba.readUnsignedByte());

        var goodInput:Array<Int> = [];
        for (i in 0...4) goodInput.push(ba.readUnsignedByte());

        var goodOutput:Array<Int> = [];
        for (i in 0...4) goodOutput.push(ba.readUnsignedByte());

        var swIn:Array<Int> = [];
        for (i in 0...4) swIn.push(ba.readUnsignedByte());

        var swOut:Array<Int> = [];
        for (i in 0...4) swOut.push(ba.readUnsignedByte());

        var mac:Array<Int> = [];
        for (i in 0...6) mac.push(ba.readUnsignedByte());

        var bindIpBytes:Array<Int> = [];
        for (i in 0...4) bindIpBytes.push(ba.readUnsignedByte());
        var bindIp = bindIpBytes.join(".");

        var style = ba.readUnsignedByte();

        return {
            ip: ip,
            port: portVal,
            version: version,
            shortName: shortName,
            longName: longName,
            nodeReport: nodeReport,
            oem: oem,
            numPorts: numPorts,
            portTypes: portTypes,
            goodInput: goodInput,
            goodOutput: goodOutput,
            swIn: swIn,
            swOut: swOut,
            mac: mac,
            bindIp: bindIp,
            style: style
        };
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
