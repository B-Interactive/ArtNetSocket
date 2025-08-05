package;

import binteractive.artnetsocket.ArtNetSocket;
import binteractive.artnetsocket.ArtNetSocketEvents;
import openfl.utils.ByteArray;

/**
 * Simple test to verify README.md examples compile correctly
 */
class Tests {
    
    public static function main() {
        trace("Testing ArtNetSocket README examples...");
        
        // Test basic socket creation
        var socket = new ArtNetSocket("0.0.0.0", 6454, 0, 512);
        
        // Test event handler setup (from README example)
        socket.addEventListener(ArtNetSocket.ARTDMX, function(event:ArtDMXEvent) {
            trace('DMX received from ${event.host}:${event.port}');
        });
        
        socket.addEventListener(ArtNetSocket.ARTPOLLREPLY, function(event:ArtPollReplyEvent) {
            trace('Node discovered: ${event.host}');
        });
        
        socket.addEventListener(ArtNetSocket.ERROR, function(event:ArtNetErrorEvent) {
            trace('Socket error: ${event.message}');
        });
        
        // Test different makeDMXPacket input methods from README
        
        // Array input
        var pkt1 = socket.makeDMXPacket([255, null, 128, null, 64]);
        trace("Array packet created successfully");
        
        // Map input 
        var channelMap = new haxe.ds.IntMap<Int>();
        channelMap.set(10, 200);
        channelMap.set(11, 150);
        var pkt2 = socket.makeDMXPacket(channelMap);
        trace("Map packet created successfully");
        
        // ByteArray input
        var ba = new ByteArray();
        ba.writeByte(100);
        ba.writeByte(200);
        var pkt3 = socket.makeDMXPacket(ba);
        trace("ByteArray packet created successfully");
        
        // Test persistent vs non-persistent modes
        socket.persistentDMX = false;
        var pkt4 = socket.makeDMXPacket([100, null, 200]);
        socket.persistentDMX = true;
        trace("Persistence mode test completed");
        
        socket.close();
        trace("All README examples compiled and executed successfully!");
    }
}
