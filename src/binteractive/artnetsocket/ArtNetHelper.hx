package binteractive.artnetsocket;

import openfl.utils.ByteArray;
import binteractive.artnetsocket.ArtNetTypes;
import haxe.ds.StringMap;

/**
 * Art-Net protocol helper for DMX, Poll, and PollReply packets.
 * All buffers are Little Endian per Art-Net specification.
 * Compatible with Haxe 4.3.7 and OpenFL 9.4.1.
 *
 * Persistent DMX buffer mode supports sparse array updates:
 *   - In persistent mode, use `null` or `-1` to indicate "no change" for a channel.
 *   - In non-persistent mode, `null` or `-1` is treated as DMX value 0 (failsafe).
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
        // Initialize persistent buffer if enabling persistent mode
        if (persistentMode && persistentDMXBuffer == null) {
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
     * @return ByteArray containing current persistent DMX state, or null if buffer not initialized
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
     * Array input:
     *   - In persistent mode: use `null` or `-1` to leave channel unchanged. Other values update the channel.
     *   - In non-persistent mode: `null` or `-1` is treated as DMX value 0 (failsafe).
     * Object input:
     *   - "values": array of DMX values (see array rules above)
     *   - "channel": start index for "values" array
     *   - "channels": sparse list of indices, "values" as parallel array
     *   - "data": ByteArray (raw DMX values)
     *   - "offset": start index for "data" ByteArray
     *   - "universe": Art-Net universe (default 0)
     *   - "length": number of channels to send (default 512)
     * Map input:
     *   - Same as object input, but uses StringMap
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

        // Handle array input: Array<Null<Int>>
        if (Std.is(input, Array)) {
            var arr:Array<Null<Int>> = cast input;
            length = arr.length;
            for (i in 0...arr.length) {
                var v:Null<Int> = arr[i];
                if (persistentMode) {
                    // Only update channel if value is not null and not -1
                    if (v != null && v != -1)
                        resultBuffer[i] = v;
                    // else: leave buffer unchanged for this channel
                } else {
                    // Non-persistent: null/-1 means 0 (failsafe)
                    resultBuffer[i] = (v == null || v == -1) ? 0 : v;
                }
            }
        }
        // Handle object input
        else if (Reflect.isObject(input) && !Std.is(input, StringMap)) {
            if (Reflect.hasField(input, "universe"))
                universe = Reflect.field(input, "universe");

            // "values" field: sequential or sparse updates
            if (Reflect.hasField(input, "values")) {
                var vals:Array<Null<Int>> = Reflect.field(input, "values");
                if (Reflect.hasField(input, "channel")) {
                    // Start at specified channel index
                    var channel:Int = Reflect.field(input, "channel");
                    for (i in 0...vals.length) {
                        var v:Null<Int> = vals[i];
                        if (channel + i < DMX_SIZE) {
                            if (persistentMode) {
                                if (v != null && v != -1)
                                    resultBuffer[channel + i] = v;
                            } else {
                                resultBuffer[channel + i] = (v == null || v == -1) ? 0 : v;
                            }
                        }
                    }
                } else if (Reflect.hasField(input, "channels")) {
                    // Sparse channel indices
                    var channels:Array<Int> = Reflect.field(input, "channels");
                    for (i in 0...vals.length) {
                        if (i < channels.length && channels[i] < DMX_SIZE) {
                            var v:Null<Int> = vals[i];
                            if (persistentMode) {
                                if (v != null && v != -1)
                                    resultBuffer[channels[i]] = v;
                            } else {
                                resultBuffer[channels[i]] = (v == null || v == -1) ? 0 : v;
                            }
                        }
                    }
                } else {
                    // Default: sequential from channel 0
                    for (i in 0...vals.length) {
                        var v:Null<Int> = vals[i];
                        if (persistentMode) {
                            if (v != null && v != -1)
                                resultBuffer[i] = v;
                        } else {
                            resultBuffer[i] = (v == null || v == -1) ? 0 : v;
                        }
                    }
                }
            }
            // "data" field: ByteArray, with optional offset
            if (Reflect.hasField(input, "data")) {
                var data:ByteArray = Reflect.field(input, "data");
                var offset:Int = 0;
                if (Reflect.hasField(input, "offset"))
                    offset = Reflect.field(input, "offset");
                for (i in 0...data.length)
                    if (offset + i < DMX_SIZE)
                        resultBuffer[offset + i] = data[i];
            }
            // "length" field: number of channels to send
            if (Reflect.hasField(input, "length"))
                length = Reflect.field(input, "length");
        }
        // Handle StringMap input (advanced)
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
                var vals:Array<Null<Int>> = map.get("values");
                for (i in 0...vals.length)
                    if (i < channels.length && channels[i] < DMX_SIZE) {
                        var v:Null<Int> = vals[i];
                        if (persistentMode) {
                            if (v != null && v != -1)
                                resultBuffer[channels[i]] = v;
                        } else {
                            resultBuffer[channels[i]] = (v == null || v == -1) ? 0 : v;
                        }
                    }
            } else if (map.exists("channel") && map.exists("values")) {
                var channel:Int = map.get("channel");
                var vals:Array<Null<Int>> = map.get("values");
                for (i in 0...vals.length)
                    if (channel + i < DMX_SIZE) {
                        var v:Null<Int> = vals[i];
                        if (persistentMode) {
                            if (v != null && v != -1)
                                resultBuffer[channel + i] = v;
                        } else {
                            resultBuffer[channel + i] = (v == null || v == -1) ? 0 : v;
                        }
                    }
            } else if (map.exists("values")) {
                var vals:Array<Null<Int>> = map.get("values");
                for (i in 0...vals.length) {
                    var v:Null<Int> = vals[i];
                    if (persistentMode) {
                        if (v != null && v != -1)
                            resultBuffer[i] = v;
                    } else {
                        resultBuffer[i] = (v == null || v == -1) ? 0 : v;
                    }
                }
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
