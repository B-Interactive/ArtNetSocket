package binteractive.artnetsocket;

import haxe.io.Bytes;
import openfl.events.Event;
import binteractive.artnetsocket.ArtNetTypes;

/**
 * Event: ArtDMX (DMX data) received.
 */
class ArtDMXEvent extends Event {
    public var dmx:ArtDMXPacket;
    public var host:String;
    public var port:Int;
    public function new(type:String, dmx:ArtDMXPacket, host:String, port:Int) {
        super(type, false, false);
        this.dmx = dmx;
        this.host = host;
        this.port = port;
    }
}

/**
 * Event: ArtPollReply (node discovery) received.
 */
class ArtPollReplyEvent extends Event {
    public var info:ArtPollReplyPacket;
    public var host:String;
    public var port:Int;
    public function new(type:String, info:ArtPollReplyPacket, host:String, port:Int) {
        super(type, false, false);
        this.info = info;
        this.host = host;
        this.port = port;
    }
}

/**
 * Event: Raw UDP data received (for unparsed/unknown packets).
 */
class ArtNetDataEvent extends Event {
    public var data:Bytes;
    public var host:String;
    public var port:Int;
    public function new(type:String, data:Bytes, host:String, port:Int) {
        super(type, false, false);
        this.data = data;
        this.host = host;
        this.port = port;
    }
}

/**
 * Event: Socket error.
 */
class ArtNetErrorEvent extends Event {
    public var message:String;
    public function new(type:String, message:String) {
        super(type, false, false);
        this.message = message;
    }
}
