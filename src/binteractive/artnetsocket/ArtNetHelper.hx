package binteractive.artnetsocket;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.ds.Map;
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
        ba.writeUTFBytes(ARTNET_ID); // 8 bytes
        writeUInt16LE(ba, OP_POLL);
        writeUInt16LE(ba, 14); // Protocol version
        ba.writeByte(0);   // TalkToMe
        ba.writeByte(0);   // Priority
        ba.position = 0;
        return Bytes.ofData(ba);
    }

    /**
     * Parses an ArtPollReply packet from Bytes.
     * @param data Bytes buffer (minimum 239 bytes)
     * @return ArtPollReplyPacket or null if invalid
     */
    public static function decodePollReply(data:Bytes):Null<ArtPollReplyPacket> {
        if (data.length < 239) return null;
        if (data.sub(0,8).toString() != ARTNET_ID) return null;
        var opcode = readUInt16LE(data, 8);
        if (opcode != OP_POLLREPLY) return null;

        // ArtPollReply field offsets per Art-Net 4 specification
        var ip = '${data.get(10)}.${data.get(11)}.${data.get(12)}.${data.get(13)}';
        var port = readUInt16LE(data, 14);
        var version = readUInt16LE(data, 16);
        var shortName = readZString(data, 26, 18);
        var longName = readZString(data, 44, 64);
        var nodeReport = readZString(data, 108, 64);
        var mac = [for(i in 201...207) data.get(i)];
        var bindIp = '${data.get(198)}.${data.get(199)}.${data.get(200)}.${data.get(201)}';
        var oem = readUInt16LE(data, 174);
        var numPorts = readUInt16LE(data, 172);
        var portTypes = [for (i in 174...178) data.get(i)];
        var goodInput = [for (i in 178...182) data.get(i)];
        var goodOutput = [for (i in 182...186) data.get(i)];
        var swIn = [for (i in 186...190) data.get(i)];
        var swOut = [for (i in 190...194) data.get(i)];
        var style = data.get(213);

        return {
            ip: ip,
            port: port,
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
     * Helper to create a valid ArtDMXPacket with an easy channel/value API.
     * You may provide:
     *   - values: Array<{channel:Int, value:Int}>
     *   - map: Map<Int, Int>
     *   - array: Array<Int>
     *   - data: Bytes
     */
    public static function makeDMXPacket(params:{
        ?universe:Int,
        ?length:Int,
        ?protocolVersion:Int,
        ?sequence:Int,
        ?physical:Int,
        ?values:Array<{channel:Int, value:Int}>,
        ?map:Map<Int, Int>,
        ?array:Array<Int>,
        ?data:Bytes
    }):ArtDMXPacket {
        var universe = params.universe ?? 0;
        var protocolVersion = params.protocolVersion ?? 14;
        var sequence = params.sequence ?? 0;
        var physical = params.physical ?? 0;
        var data:Bytes = null;
        var length:Int = params.length ?? 512;

        if (params.data != null) {
            data = params.data;
            length = params.length ?? data.length;
            if (data.length < length) throw "ArtDMXPacket: Provided data buffer too short";
        } else if (params.array != null) {
            length = params.array.length;
            if (length < 1 || length > 512) throw "ArtDMXPacket: DMX length must be 1-512";
            data = Bytes.alloc(length);
            for (i in 0...length) data.set(i, params.array[i]);
        } else {
            if (length < 1 || length > 512) throw "ArtDMXPacket: DMX length must be 1-512";
            data = Bytes.alloc(length);
            if (params.values != null) {
                for (entry in params.values) {
                    if (entry.channel >= 1 && entry.channel <= length)
                        data.set(entry.channel - 1, entry.value);
                }
            }
            if (params.map != null) {
                for (ch in params.map.keys()) {
                    var value = params.map.get(ch);
                    if (ch >= 1 && ch <= length) data.set(ch - 1, value);
                }
            }
        }

        return {
            protocolVersion: protocolVersion,
            sequence: sequence,
            physical: physical,
            universe: universe,
            length: length,
            data: data
        };
    }

    /**
     * Inspects received data and parses it as a known Art-Net packet type if possible.
     * @param data Incoming UDP data
     * @return {type:String, packet:Dynamic} or null if not recognized
     */
    public static function detectAndParse(data:Bytes):Null<{type:String, packet:Dynamic}> {
        if (data.length < 10) return null;
        if (data.sub(0,8).toString() != ARTNET_ID) return null;
        var opcode = readUInt16LE(data, 8);
        switch (opcode) {
            case OP_DMX:
                var pkt = decodeDMX(data);
                if (pkt != null) return { type: "ArtDMX", packet: pkt };
            case OP_POLLREPLY:
                var pkt = decodePollReply(data);
                if (pkt != null) return { type: "ArtPollReply", packet: pkt };
            default:
        }
        return null;
    }

    /**
     * Reads a zero-terminated ASCII string from a Bytes buffer.
     * @param bytes Source buffer
     * @param start Starting index
     * @param maxLen Maximum length to read
     * @return Decoded string
     */
    static function readZString(bytes:Bytes, start:Int, maxLen:Int):String {
        var end = start;
        while (end < start + maxLen && bytes.get(end) != 0) end++;
        return bytes.sub(start, end - start).toString();
    }
}
