package binteractive.artnetsocket;

import openfl.utils.ByteArray;
import binteractive.artnetsocket.ArtNetTypes;
import haxe.ds.StringMap;

/**
 * Art-Net protocol helper for DMX, Poll, and PollReply packets.
 * All buffers are Little Endian per Art-Net specification.
 * Compatible with Haxe 4.3.7 and OpenFL 9.4.1.
 *
 * This library supports both non-persistent and persistent DMX buffer modes.
 * In persistent mode, unspecified channel values retain their previous state.
 * In non-persistent mode, unspecified channel values default to zero.
 */
class ArtNetHelper {
    /** Art-Net Protocol ID (8 bytes, zero-padded) */
    public static final ARTNET_ID:String = "Art-Net\x00";
    public static final OP_POLL:Int = 0x2000;
    public static final OP_POLLREPLY:Int = 0x2100;
    public static final OP_DMX:Int = 0x5000;

    /** DMX universe size (channels) */
    public static final DMX_SIZE:Int = 512;

    /** Persistent buffer for DMX values (shared across all universes) */
    private static var persistentDMXBuffer:ByteArray = null;

    /** Persistent mode flag */
    private static var persistentMode:Bool = false;

    /**
     * Enable or disable persistent DMX buffer mode.
     * @param enable true for persistent mode, false for non-persistent mode
     */
    public static function setPersistentMode(enable:Bool):Void {
        persistentMode = enable;
        if (persistentMode && persistentDMXBuffer == null) {
            // Initialize buffer to zero for all channels
            persistentDMXBuffer = new ByteArray();
            for (i in 0...DMX_SIZE) persistentDMXBuffer.writeByte(0);
            persistentDMXBuffer.position = 0;
        }
    }

    /**
     * Clears the persistent DMX buffer to zero (all channels).
     */
    public static function clearPersistentBuffer():Void {
        if (persistentDMXBuffer != null) {
            persistentDMXBuffer.position = 0;
            for (i in 0...DMX_SIZE) persistentDMXBuffer[i] = 0;
        }
    }

    /**
     * Returns a copy of the current persistent DMX buffer.
     */
    public static function getPersistentBuffer():ByteArray {
        if (persistentDMXBuffer == null) return null;
        var buf = new ByteArray();
        buf.writeBytes(persistentDMXBuffer, 0, DMX_SIZE);
        buf.position = 0;
        return buf;
    }

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
     * Create an ArtDMXPacket from DMX data.
     *
     * Usage (non-persistent mode):
     *   - makeDMXPacket([value0, value1, ...]) // all values specified, length = array length
     *   - makeDMXPacket({universe:0, values:[...]}) // all values specified
     *   - makeDMXPacket(map) // all values specified
     *
     * Usage (persistent mode):
     *   - makeDMXPacket({channel:10, values:[23,44,51]}) // updates channel 10-12 only, other channels unchanged
     *   - makeDMXPacket({channels:[10,12,15], values:[23,44,51]}) // updates channels 10,12,15
     *   - makeDMXPacket({universe:0, values:[...]}) // overwrites channels 0..N with values, rest unchanged
     *   - makeDMXPacket({universe:0, data:myPartialByteArray, offset:10}) // updates buffer at offset 10
     *
     * If not in persistent mode, any unspecified channel values are zero.
     *
     * @param input Various forms (see above)
     * @return ArtDMXPacket
     */
    public static function makeDMXPacket(input:Dynamic):ArtDMXPacket {
        var universe:Int = 0;
        var length:Int = DMX_SIZE;
        var resultBuffer:ByteArray;

        // Select buffer: persistent or fresh
        if (persistentMode) {
            if (persistentDMXBuffer == null) {
                persistentDMXBuffer = new ByteArray();
                for (i in 0...DMX_SIZE) persistentDMXBuffer.writeByte(0);
                persistentDMXBuffer.position = 0;
            }
            // Work on a copy (to avoid accidental mutation)
            resultBuffer = getPersistentBuffer();
        } else {
            resultBuffer = new ByteArray();
            for (i in 0...DMX_SIZE) resultBuffer.writeByte(0);
            resultBuffer.position = 0;
        }

        // Array<Int> input: update sequentially from channel 0
        if (Std.is(input, Array)) {
            var arr:Array<Int> = cast input;
            length = arr.length;
            for (i in 0...arr.length)
                resultBuffer[i] = arr[i];
        }
        // Object with fields
        else if (Reflect.isObject(input) && !Std.is(input, StringMap)) {
            if (Reflect.hasField(input, "universe"))
                universe = Reflect.field(input, "universe");

            // Sequential values (starting at channel 0 or at specified channel/offset)
            if (Reflect.hasField(input, "values")) {
                var vals:Array<Int> = Reflect.field(input, "values");
                if (Reflect.hasField(input, "channel")) {
                    var channel:Int = Reflect.field(input, "channel");
                    for (i in 0...vals.length)
                        if (channel + i < DMX_SIZE)
                            resultBuffer[channel + i] = vals[i];
                } else if (Reflect.hasField(input, "channels")) {
                    var channels:Array<Int> = Reflect.field(input, "channels");
                    for (i in 0...vals.length)
                        if (i < channels.length && channels[i] < DMX_SIZE)
                            resultBuffer[channels[i]] = vals[i];
                } else {
                    // Default: start at channel 0
                    for (i in 0...vals.length)
                        resultBuffer[i] = vals[i];
                }
            }
            // ByteArray input with optional offset
            if (Reflect.hasField(input, "data")) {
                var data:ByteArray = Reflect.field(input, "data");
                var offset:Int = 0;
                if (Reflect.hasField(input, "offset"))
                    offset = Reflect.field(input, "offset");
                for (i in 0...data.length)
                    if (offset + i < DMX_SIZE)
                        resultBuffer[offset + i] = data[i];
            }
            if (Reflect.hasField(input, "length"))
                length = Reflect.field(input, "length");
        }
        // StringMap for advanced
        else if (Std.is(input, StringMap)) {
            var map:StringMap<Dynamic> = cast input;
            if (map.exists("universe")) universe = map.get("universe");
            if (map.exists("length")) length = map.get("length");
            if (map.exists("data")) {
                var data:ByteArray = map.get("data");
                var offset:Int = map.exists("offset") ? map.get("offset") : 0;
                for (i in 0...data.length)
                    if (offset + i < DMX_SIZE)
                        resultBuffer[offset + i] = data[i];
            } else if (map.exists("channels") && map.exists("values")) {
                var channels:Array<Int> = map.get("channels");
                var vals:Array<Int> = map.get("values");
                for (i in 0...vals.length)
                    if (i < channels.length && channels[i] < DMX_SIZE)
                        resultBuffer[channels[i]] = vals[i];
            } else if (map.exists("channel") && map.exists("values")) {
                var channel:Int = map.get("channel");
                var vals:Array<Int> = map.get("values");
                for (i in 0...vals.length)
                    if (channel + i < DMX_SIZE)
                        resultBuffer[channel + i] = vals[i];
            } else if (map.exists("values")) {
                var vals:Array<Int> = map.get("values");
                for (i in 0...vals.length)
                    resultBuffer[i] = vals[i];
            }
        }
        else throw "Invalid argument for makeDMXPacket";

        // If in persistent mode, update persistent buffer
        if (persistentMode) {
            for (i in 0...DMX_SIZE)
                persistentDMXBuffer[i] = resultBuffer[i];
        }

        // Limit length to DMX_SIZE
        if (length > DMX_SIZE) length = DMX_SIZE;
        // Copy data for packet
        var packetData = new ByteArray();
        packetData.writeBytes(resultBuffer, 0, length);
        packetData.position = 0;

        // ArtDMXPacket may use a structure or constructor; adjust if needed
        return ArtDMXPacket.create(universe, length, packetData);
    }
}
