package b_interactive.artnetsocket;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;

/**
 * ArtNetHelper
 *
 * Provides static methods to serialize and deserialize Art-Net packet types:
 * - ArtDMX (DMX data, send/receive)
 * - ArtPoll (discovery request, send only)
 * - ArtPollReply (discovery response, receive only)
 *
 * All buffers are Little Endian per Art-Net specification.
 */
class ArtNetHelper {
    /** Art-Net Protocol ID (8 bytes, zero-padded) */
    public static inline var ARTNET_ID:String = "Art-Net\0";
    public static inline var OP_POLL:Int = 0x2000;
    public static inline var OP_POLLREPLY:Int = 0x2100;
    public static inline var OP_DMX:Int = 0x5000;

    /**
     * Serializes an ArtDMXPacket into a Bytes buffer.
     * @param pkt ArtDMXPacket structure (see typedef)
     * @return Bytes ready for sending via UDP
     */
    public static function encodeDMX(pkt:ArtDMXPacket):Bytes {
        var buf = new BytesBuffer();
        buf.addString(ARTNET_ID); // 8 bytes: "Art-Net\0"
        buf.addInt16(OP_DMX);     // OpCode: ArtDMX
        buf.addInt16(pkt.protocolVersion); // Protocol version, commonly 14
        buf.addByte(pkt.sequence);
        buf.addByte(pkt.physical);
        buf.addInt16(pkt.universe);
        buf.addInt16(pkt.length);
        buf.add(pkt.data.sub(0, pkt.length));
        return buf.getBytes();
    }

    /**
     * Parses a Bytes buffer into an ArtDMXPacket structure.
     * @param data Bytes buffer (minimum 18 bytes)
     * @return ArtDMXPacket or null if invalid
     */
    public static function decodeDMX(data:Bytes):Null<ArtDMXPacket> {
        if (data.length < 18) return null;
        if (data.sub(0,8).toString() != ARTNET_ID) return null;
        var opcode = data.getUInt16(8);
        if (opcode != OP_DMX) return null;
        var len = data.getUInt16(16);
        return {
            protocolVersion: data.getUInt16(10),
            sequence: data.get(12),
            physical: data.get(13),
            universe: data.getUInt16(14),
            length: len,
            data: data.sub(18, len)
        };
    }

    /**
     * Serializes a minimal ArtPoll packet (standard for node discovery).
     * @return Bytes ready for sending via UDP
     */
    public static function encodePoll():Bytes {
        var buf = new BytesBuffer();
        buf.addString(ARTNET_ID); // 8 bytes
        buf.addInt16(OP_POLL);
        buf.addInt16(14); // Protocol version
        buf.addByte(0);   // TalkToMe
        buf.addByte(0);   // Priority
        return buf.getBytes();
    }

    /**
     * Parses an ArtPollReply packet from Bytes.
     * @param data Bytes buffer (minimum 239 bytes)
     * @return ArtPollReplyPacket or null if invalid
     */
    public static function decodePollReply(data:Bytes):Null<ArtPollReplyPacket> {
        if (data.length < 239) return null;
        if (data.sub(0,8).toString() != ARTNET_ID) return null;
        var opcode = data.getUInt16(8);
        if (opcode != OP_POLLREPLY) return null;

        // ArtPollReply field offsets per Art-Net 4 specification
        var ip = '${data.get(10)}.${data.get(11)}.${data.get(12)}.${data.get(13)}';
        var port = data.getUInt16(14);
        var version = data.getUInt16(16);
        var shortName = readZString(data, 26, 18);
        var longName = readZString(data, 44, 64);
        var nodeReport = readZString(data, 108, 64);
        var mac = [for(i in 201...207) data.get(i)];
        var bindIp = '${data.get(198)}.${data.get(199)}.${data.get(200)}.${data.get(201)}';
        var oem = data.getUInt16(174);
        var numPorts = data.getUInt16(172);
        var portTypes:Array<Int> = [];
        for (i in 174...178) portTypes.push(data.get(i));
        var goodInput = [for(i in 178...182) data.get(i)];
        var goodOutput = [for(i in 182...186) data.get(i)];
        var swIn = [for(i in 186...190) data.get(i)];
        var swOut = [for(i in 190...194) data.get(i)];
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
     * Inspects received data and parses it as a known Art-Net packet type if possible.
     * @param data Incoming UDP data
     * @return {type:String, packet:Dynamic} or null if not recognized
     */
    public static function detectAndParse(data:Bytes):Null<{type:String, packet:Dynamic}> {
        if (data.length < 10) return null;
        if (data.sub(0,8).toString() != ARTNET_ID) return null;
        var opcode = data.getUInt16(8);
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

/**
 * ArtDMXPacket: structure for Art-Net DMX data.
 * Only DMX payload up to 'length' bytes is valid.
 */
typedef ArtDMXPacket = {
    var protocolVersion:Int;
    var sequence:Int;
    var physical:Int;
    var universe:Int;
    var length:Int;
    var data:Bytes;
}

/**
 * ArtPollReplyPacket: structure for Art-Net discovery reply.
 */
typedef ArtPollReplyPacket = {
    var ip:String;
    var port:Int;
    var version:Int;
    var shortName:String;
    var longName:String;
    var nodeReport:String;
    var oem:Int;
    var numPorts:Int;
    var portTypes:Array<Int>;
    var goodInput:Array<Int>;
    var goodOutput:Array<Int>;
    var swIn:Array<Int>;
    var swOut:Array<Int>;
    var mac:Array<Int>;
    var bindIp:String;
    var style:Int;
}
