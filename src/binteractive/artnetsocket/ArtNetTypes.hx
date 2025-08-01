package binteractive.artnetsocket;

import haxe.io.Bytes;

typedef ArtDMXPacket = {
    var protocolVersion:Int;
    var sequence:Int;
    var physical:Int;
    var universe:Int;
    var length:Int;
    var data:Bytes;
}

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
