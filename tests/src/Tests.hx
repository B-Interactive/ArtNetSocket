package;

import binteractive.artnetsocket.ArtNetSocket;
import binteractive.artnetsocket.ArtNetSocketEvents;
import openfl.utils.ByteArray;

/**
 * Simple test to verify README.md examples compile correctly
 */
class Tests {
    
    public static function main() {
        // Create socket for sending/receiving Art-Net DMX (universe 0, 512 channels)
        var socket = new ArtNetSocket("0.0.0.0", ArtNetSocket.DEFAULT_PORT, 0, 512);

        // Listen for incoming DMX packets
        socket.addEventListener(ArtNetSocket.ARTDMX, function(event) {
            trace('Got DMX from ${event.host}:${event.port}');
            trace('Universe: ' + event.packet.universe);
            trace('Channels: ' + event.packet.length);
            // Print first 8 channel values
            event.packet.data.position = 0;
            for (i in 0...8) trace(event.packet.data.readUnsignedByte());
        });

        // Listen for Art-Net Poll responses (ArtPollReply packets)
        socket.addEventListener(ArtNetSocket.ARTPOLLREPLY, function(event) {
            trace('Art-Net node discovered at ${event.host}:${event.port}');
            trace('Short name: ' + event.packet.shortName);
            trace('Long name: ' + event.packet.longName);
            trace('IP: ' + event.packet.ip);
            // You may want to store node info, send DMX, etc.
        });

        // Discover Art-Net nodes on the local network (cpp/neko targets only)
        socket.discoverNodes();

        // Send DMX (channels 1,2,3 set to 255,128,64)
        var pkt = socket.makeDMXFromArray([255, 128, 64]);
        // Broadcast DMX (cpp/neko targets only)
        #if (cpp || neko)
        socket.broadcastDMX(pkt);
        #else
        // Use sendDMX for specific nodes on other targets
        socket.sendDMX(pkt, "192.168.1.100");
        #end

        // Send DMX to a specific node (by IP)
        socket.sendDMX(pkt, "192.168.1.100");

        // Clean up when done
        socket.close();
    }
}
