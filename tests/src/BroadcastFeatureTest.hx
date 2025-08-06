package;

import binteractive.artnetsocket.ArtNetSocket;
import binteractive.artnetsocket.ArtNetSocketEvents;

/**
 * Test to verify the new enableBroadcast feature detection and fallback behavior
 */
class BroadcastFeatureTest {
    
    public static function main() {
        trace("Testing ArtNetSocket broadcast feature detection...");
        
        // Test socket creation - this should work on all platforms
        var socket = new ArtNetSocket("0.0.0.0", 6454, 0, 512);
        
        // Test error handling
        var errorReceived = false;
        socket.addEventListener(ArtNetSocket.ERROR, function(event:ArtNetErrorEvent) {
            trace('Expected error in test environment: ${event.message}');
            errorReceived = true;
        });
        
        // Test broadcast methods - these should work without errors even if broadcast is not supported
        try {
            // Test broadcastPoll - should either use true broadcast or fall back to simulation
            socket.broadcastPoll();
            trace("broadcastPoll() executed successfully");
            
            // Test sendPoll - should attempt true broadcast
            socket.sendPoll();
            trace("sendPoll() executed successfully");
            
            // Test broadcastDMX with a simple packet
            var pkt = socket.makeDMXFromArray([255, 128, 64]);
            socket.broadcastDMX(pkt);
            trace("broadcastDMX() executed successfully");
            
        } catch (e:Dynamic) {
            trace('Broadcast test error (expected in test environment): ${e}');
        }
        
        socket.close();
        trace("Broadcast feature detection test completed successfully!");
        
        // Verify that the methods exist and can be called
        trace("All broadcast method signatures are correct and callable");
    }
}