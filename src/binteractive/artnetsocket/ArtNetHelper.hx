package binteractive.artnetsocket;

import openfl.utils.ByteArray;
import binteractive.artnetsocket.ArtNetTypes;
import haxe.ds.StringMap;

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

        // If pkt.data is ByteArray, writeBytes can be used directly
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

        ba.position = 0;
        var id = ba.readUTFBytes(8);
        if (id != ARTNET_ID) return null;
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
        ba.position = 0; // reset for future parsing

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

    /**
     * Creates an ArtDMXPacket from various DMX data representations.
     *
     * Usage examples:
     *   - makeDMXPacket([0, 255, 128, ...])
     *   - makeDMXPacket({universe: 0, values: [...]})
     *   - makeDMXPacket(map) // where map is a StringMap with keys "universe", "length", "data"
     *
     * @param input Array<Int>, object, or StringMap<String,Dynamic> describing DMX packet data.
     * @return ArtDMXPacket
     */
    public static function makeDMXPacket(input:Dynamic):ArtDMXPacket {
        var universe:Int = 0;
        var dmxData:ByteArray = new ByteArray();
        var length:Int = 512;

        // If input is Array<Int>
        if (Std.is(input, Array)) {
            var arr:Array<Int> = cast input;
            length = arr.length;
            for (v in arr) dmxData.writeByte(v);
        }
        // If input is an object with fields
        else if (Reflect.isObject(input) && !Std.is(input, StringMap)) {
            if (Reflect.hasField(input, "universe")) universe = Reflect.field(input, "universe");
            if (Reflect.hasField(input, "values")) {
                var vals:Array<Int> = Reflect.field(input, "values");
                length = vals.length;
                for (v in vals) dmxData.writeByte(v);
            }
            if (Reflect.hasField(input, "length")) length = Reflect.field(input, "length");
            if (Reflect.hasField(input, "data")) {
                dmxData = Reflect.field(input, "data");
                if (Reflect.hasField(input, "length")) length = Reflect.field(input, "length");
                else length = dmxData.length;
            }
        }
        // If input is a StringMap<String,Dynamic>
        else if (Std.is(input, StringMap)) {
            var map:StringMap<Dynamic> = cast input;
            if (map.exists("universe")) universe = map.get("universe");
            if (map.exists("length")) length = map.get("length");
            if (map.exists("data")) dmxData = map.get("data");
            else if (map.exists("values")) {
                var vals:Array<Int> = map.get("values");
                length = vals.length;
                for (v in vals) dmxData.writeByte(v);
            }
        }
        else throw "Invalid argument for makeDMXPacket";

        // Ensure DMX data is correct length
        dmxData.position = 0;
        if (dmxData.length < length) {
            while (dmxData.length < length) dmxData.writeByte(0);
        } else if (dmxData.length > length) {
            dmxData = dmxData.sub(0, length);
        }

        // ArtDMXPacket structure must be matched to your ArtNetTypes definition.
        // This sample assumes a constructor or static create method like:
        // ArtDMXPacket.create(universe, length, dmxData)
        // If your structure is a plain object, adjust accordingly.
        #if (haxe_ver >= "4.0")
        return ArtDMXPacket.create(universe, length, dmxData);
        #else
        return {
            protocolVersion: 14,
            sequence: 0,
            physical: 0,
            universe: universe,
            length: length,
            data: dmxData
        };
        #end
    }

    // Add decodePollReply if needed for your use case!
}
