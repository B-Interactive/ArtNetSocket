import binteractive.artnetsocket.ArtNetSocket;
import binteractive.artnetsocket.ArtNetSocketEvents;
import openfl.utils.ByteArray;

class DMXController {
    private var socket:ArtNetSocket;
    private var connectedNodes:Map<String, ArtPollReplyPacket> = new Map();

    public function new() {
        // Create socket bound to all interfaces, standard Art-Net port
        // Default universe 0, 512 channels, with persistent DMX buffering enabled
        socket = new ArtNetSocket("0.0.0.0", ArtNetSocket.DEFAULT_PORT, 0, 512);

        // Set up event listeners to handle incoming Art-Net traffic
        setupEventHandlers();

        // Discover Art-Net nodes on the network
        discoverNodes();

        // Start sending DMX data
        startDMXOutput();
    }

    /**
     * Configure event handlers for all Art-Net packet types
     */
    private function setupEventHandlers():Void {
        // Handle incoming DMX data (from other controllers or nodes)
        socket.addEventListener(ArtNetSocket.ARTDMX, onDMXReceived);

        // Handle node discovery responses (learn about available DMX nodes/fixtures)
        socket.addEventListener(ArtNetSocket.ARTPOLLREPLY, onNodeDiscovered);

        // Handle raw/unknown Art-Net packets for debugging
        socket.addEventListener(ArtNetSocket.DATA, onRawDataReceived);

        // Handle socket errors (network issues, binding failures, etc.)
        socket.addEventListener(ArtNetSocket.ERROR, onSocketError);
    }

    /**
     * Event handler: Process received DMX data from other controllers
     * Useful for implementing DMX merging, monitoring, or pass-through functionality
     */
    private function onDMXReceived(event:ArtDMXEvent):Void {
        var dmxPacket = event.packet;

        trace('DMX received from ${event.host}:${event.port}');
        trace('  Universe: ${dmxPacket.universe}');
        trace('  Channels: ${dmxPacket.length}');
        trace('  Sequence: ${dmxPacket.sequence}');

        // Extract DMX channel values from the received packet
        var channelData:Array<Int> = [];
        dmxPacket.data.position = 0;
        for (i in 0...dmxPacket.length) {
            channelData.push(dmxPacket.data.readUnsignedByte());
        }

        // Process the received DMX data (e.g., merge with local data, display, etc.)
        trace('  First 8 channels: ${channelData.slice(0, 8)}');

        // Example: Forward received data to another universe
        if (dmxPacket.universe == 0) {
            // Retransmit to universe 1 with modified data
            var forwardPacket = socket.makeDMXFromArray(channelData, 1, dmxPacket.length);
            socket.broadcastDMX(forwardPacket);
        }
    }

    /**
     * Event handler: Process node discovery responses
     * Build a registry of available Art-Net devices on the network
     */
    private function onNodeDiscovered(event:ArtPollReplyEvent):Void {
        var node = event.packet;
        var nodeId = '${event.host}:${event.port}';

        // Store node information for later reference
        connectedNodes.set(nodeId, node);

        trace('Art-Net node discovered: ${nodeId}');
        trace('  Name: "${node.shortName}" / "${node.longName}"');
        trace('  IP: ${node.ip}, Bind IP: ${node.bindIp}');
        trace('  Version: ${node.version}, OEM: ${node.oem}');
        trace('  Ports: ${node.numPorts}');

        // Log input/output port configuration
        for (i in 0...node.numPorts) {
            var portType = i < node.portTypes.length ? node.portTypes[i] : 0;
            var inputGood = i < node.goodInput.length ? node.goodInput[i] : 0;
            var outputGood = i < node.goodOutput.length ? node.goodOutput[i] : 0;
            trace('  Port ${i}: Type=${portType}, Input=${inputGood}, Output=${outputGood}');
        }

        // Example: Send DMX specifically to this newly discovered node
        sendWelcomePattern(event.host);
    }

    /**
     * Event handler: Process raw/unknown packets for debugging
     */
    private function onRawDataReceived(event:ArtNetDataEvent):Void {
        trace('Raw Art-Net data from ${event.host}:${event.port} (${event.data.length} bytes)');
        // Could implement custom packet parsing here
    }

    /**
     * Event handler: Handle socket errors with appropriate recovery
     */
    private function onSocketError(event:ArtNetErrorEvent):Void {
        trace('ArtNetSocket error: ${event.message}');

        // Example error recovery strategies
        if (event.message.indexOf("bind") != -1) {
            trace("Network binding failed - check if port 6454 is available");
        } else if (event.message.indexOf("send") != -1) {
            trace("Send failed - check network connectivity");
        }

        // Could implement automatic reconnection logic here
    }

    /**
     * Discover Art-Net nodes on the network by broadcasting ArtPoll
     */
    private function discoverNodes():Void {
        trace("Broadcasting ArtPoll to discover nodes...");

        // Use broadcastPoll for reliable cross-platform discovery
        // This sends to all IPs in the local subnet (more reliable than true broadcast)
        socket.broadcastPoll();

        // Alternative: Use legacy single-address broadcast (may not work on all platforms)
        // socket.sendPoll();
    }

    /**
     * Demonstrate various DMX output patterns using different input methods
     */
    private function startDMXOutput():Void {
        // Example 1: Array input with persistent buffering (default behavior)
        // Set channels 1, 3, and 5 to specific values, leave others unchanged
        var pkt1 = socket.makeDMXFromArray([255, null, 128, null, 64]);
        socket.broadcastDMX(pkt1);
        trace("Sent DMX with array input - channels 1,3,5 set, others persistent");

        // Example 2: Map input for sparse channel updates
        // Perfect for controlling individual fixtures without affecting others
        var channelMap = new haxe.ds.IntMap<Int>();
        channelMap.set(10, 200);  // Set channel 10 (dimmer) to 200
        channelMap.set(11, 150);  // Set channel 11 (red) to 150
        channelMap.set(12, 100);  // Set channel 12 (green) to 100
        channelMap.set(13, 50);   // Set channel 13 (blue) to 50
        var pkt2 = socket.makeDMXFromMap(channelMap);
        socket.broadcastDMX(pkt2);
        trace("Sent DMX with map input - updated RGB fixture channels 10-13");

        // Example 3: ByteArray input for maximum efficiency
        // Useful when receiving DMX data from other sources or file playback
        var ba = new ByteArray();
        for (i in 0...16) {
            ba.writeByte(Math.floor(Math.random() * 255)); // Random pattern
        }
        var pkt3 = socket.makeDMXFromByteArray(ba);
        socket.sendDMX(pkt3, "192.168.1.100");  // Send to specific node
        trace("Sent DMX with ByteArray input - 16 random values to specific node");

        // Example 4: Override universe and length per packet
        var pkt4 = socket.makeDMXFromArray([255, 128, 64], 2, 3);  // Universe 2, 3 channels
        socket.broadcastDMX(pkt4);
        trace("Sent DMX to universe 2 with 3 channels");

        // Example 5: Non-persistent mode (original behavior)
        socket.persistentDMX = false;
        var pkt5 = socket.makeDMXFromArray([100, null, 200]);  // null becomes 0
        socket.broadcastDMX(pkt5);
        trace("Sent DMX in non-persistent mode - null values became 0");

        // Restore persistent mode
        socket.persistentDMX = true;
    }

    /**
     * Send a welcome pattern to a newly discovered node
     */
    private function sendWelcomePattern(nodeIP:String):Void {
        // Create a simple fade-in pattern on the first 8 channels
        for (level in 0...256) {
            var fadePattern:Array<Int> = [];
            for (ch in 0...8) {
                fadePattern.push(level);
            }
            var pkt = socket.makeDMXFromArray(fadePattern);
            socket.sendDMX(pkt, nodeIP);
        }
        trace('Sent welcome fade pattern to node at ${nodeIP}');
    }

    /**
     * Clean up socket resources when done
     */
    public function cleanup():Void {
        if (socket != null) {
            socket.close();
            trace("ArtNetSocket closed");
        }
    }
}

// Usage:
var controller = new DMXController();
// ... do other work ...
// controller.cleanup(); // Call when shutting down
