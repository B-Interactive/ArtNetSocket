# ArtNetSocket for Haxe

Cross-platform, event-driven UDP socket tailored for Art-Net (OpenFL/Haxe 4.3+).  
Uses OpenFL's DatagramSocket for all supported targets (cpp, hashlink, neko, AIR/Flash).

## Pre-Release Software
**This is pre-release software undergoing active development. Chances are it will not work at all... yet.**

---

**Features:**
- Simple DMX send/receive (ArtDMX, ArtPoll, ArtPollReply)
- Automatic network config (subnet, broadcast)
- Event-driven protocol parsing
- Typed packets and helpers
- Persistent DMX buffer mode for efficient sparse channel updates

## Installation

```bash
haxelib git artnetsocket https://github.com/B-Interactive/artnetsocket
```

## Usage Example

```haxe
import binteractive.artnetsocket.ArtNetSocket;
import binteractive.artnetsocket.ArtNetSocketEvents;
import openfl.utils.ByteArray;

class DMXController {
    private var socket:ArtNetSocket;
    private var connectedNodes:Map<String, ArtPollReplyPacket> = new Map();
    
    public function new() {
        // Create socket bound to all interfaces, standard Art-Net port 6454
        // Default universe 0, 512 channels, with persistent DMX buffering enabled
        socket = new ArtNetSocket("0.0.0.0", 6454, 0, 512);
        
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
            var forwardPacket = socket.makeDMXPacket(channelData, 1, dmxPacket.length);
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
        var pkt1 = socket.makeDMXPacket([255, null, 128, null, 64]);
        socket.broadcastDMX(pkt1);
        trace("Sent DMX with array input - channels 1,3,5 set, others persistent");
        
        // Example 2: Map input for sparse channel updates
        // Perfect for controlling individual fixtures without affecting others
        var channelMap = new Map<Int,Int>();
        channelMap.set(10, 200);  // Set channel 10 (dimmer) to 200
        channelMap.set(11, 150);  // Set channel 11 (red) to 150  
        channelMap.set(12, 100);  // Set channel 12 (green) to 100
        channelMap.set(13, 50);   // Set channel 13 (blue) to 50
        var pkt2 = socket.makeDMXPacket(channelMap);
        socket.broadcastDMX(pkt2);
        trace("Sent DMX with map input - updated RGB fixture channels 10-13");
        
        // Example 3: ByteArray input for maximum efficiency
        // Useful when receiving DMX data from other sources or file playback
        var ba = new ByteArray();
        for (i in 0...16) {
            ba.writeByte(Math.floor(Math.random() * 255)); // Random pattern
        }
        var pkt3 = socket.makeDMXPacket(ba);
        socket.sendDMX(pkt3, "192.168.1.100");  // Send to specific node
        trace("Sent DMX with ByteArray input - 16 random values to specific node");
        
        // Example 4: Override universe and length per packet
        var pkt4 = socket.makeDMXPacket([255, 128, 64], 2, 3);  // Universe 2, 3 channels
        socket.broadcastDMX(pkt4);
        trace("Sent DMX to universe 2 with 3 channels");
        
        // Example 5: Non-persistent mode (original behavior)
        socket.persistentDMX = false;
        var pkt5 = socket.makeDMXPacket([100, null, 200]);  // null becomes 0
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
            var pkt = socket.makeDMXPacket(fadePattern);
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
```

---

## ArtNetSocket DMX Packet Construction

ArtNetSocket provides a simple way to create an ArtDMXPacket for sending DMX data.  
**Supports both persistent and non-persistent buffer modes.**

### Persistent Mode (Default)

Persistent mode is enabled by default. The library **retains a DMX buffer behind the scenes**:
- Any channel value set to `null` or `-1` in array input will **not change** that channel; its previous value is retained from the buffer.
- Only non-null, non--1 values in your input array will update the corresponding channel.
- All other channels keep their previous values.
- Map and ByteArray inputs always overwrite the channels they specify.

```haxe
var socket = new ArtNetSocket(); // persistentDMX defaults to true

// Method 1: Array input - update specific channels, others retain previous values
var pkt = socket.makeDMXPacket([255, null, 128, -1, 75]); // channels 1 and 3 unchanged

// Method 2: Map input for sparse updates
var channelMap = new Map<Int,Int>();
channelMap.set(5, 100);   // Set channel 5 to 100
channelMap.set(13, 255);  // Set channel 13 to 255
var pkt = socket.makeDMXPacket(channelMap); // Other channels retain previous values

// Method 3: ByteArray input (overwrites channels 0..N)
var ba = new ByteArray();
ba.writeByte(50);
ba.writeByte(75);
ba.writeByte(100);
var pkt = socket.makeDMXPacket(ba); // Channels 0-2 set, others retain values
```

### Non-Persistent Mode

Disable persistent mode to reset the buffer before each packet:
- Any unspecified, `null`, or `-1` channel value is assumed to be **0** each time you call `makeDMXPacket`.
- You must provide all channel values you wish to set for every packet.

```haxe
// Disable persistent mode
socket.persistentDMX = false;

// Array input - unspecified/null/-1 channels become 0
var pkt = socket.makeDMXPacket([255, null, 128, -1]); // Results in [255, 0, 128, 0, 0, 0, ...]

// Map and ByteArray inputs work the same, but other channels are 0
var channelMap = new Map<Int,Int>();
channelMap.set(10, 255);
var pkt = socket.makeDMXPacket(channelMap); // Channel 10 = 255, all others = 0
```

**Tip:**  
Use persistent mode for efficient, incremental updates to DMX universes—especially useful for real-time and interactive applications.  
Use `null` or `-1` to indicate "no change" to a channel when updating with arrays or objects in persistent mode.

---

## Event Types

- **ArtNetSocket.ARTDMX**: `ArtDMXEvent` - DMX packet received.
- **ArtNetSocket.ARTPOLLREPLY**: `ArtPollReplyEvent` - PollReply packet received.
- **ArtNetSocket.DATA**: `ArtNetDataEvent` - Raw UDP data received.
- **ArtNetSocket.ERROR**: `ArtNetErrorEvent` - Error occurred.

---

## Configuration: `artnetsocket.config.json`

ArtNetSocket can read its network configuration from an optional JSON file, typically named `artnetsocket.config.json`.  
This file allows you to specify network settings such as IP address, UDP port, and subnet to override auto-detection.

**Example `artnetsocket.config.json`:**
```json
{
  "address": "192.168.1.10",
  "port": 6454,
  "subnet": "192.168.1."
}
```

**Usage:**
- Pass the config file path to the constructor:  
  ```haxe
  var socket = new ArtNetSocket("artnetsocket.config.json");
  ```
- If omitted, the default path `"artnetsocket.config.json"` is used.
- If no file is found, ArtNetSocket auto-detects the local interface and subnet.

**Config Fields:**
- `address`: (string) The local network interface to bind. If unset, auto-detected.
- `port`: (int) UDP port to bind. Default is 6454.
- `subnet`: (string) Subnet prefix for broadcast/discovery. Example: `"192.168.1."`.

You can customize your network environment by editing the config file, or rely on automatic detection for simple cases.

---

## OpenFL Target Compatibility

This library is designed for use with OpenFL (Haxe 4.0.0 or newer) and supports the following targets:

| Target         | Status         | Notes                                                         |
|----------------|---------------|---------------------------------------------------------------|
| neko           | ✅ Supported   | Uses `sys.net.UdpSocket` and polling thread                  |
| hl             | ✅ Supported   | Uses `sys.net.UdpSocket` and polling thread                  |
| cpp            | ✅ Supported   | Uses `sys.net.UdpSocket` and polling thread                  |
| flash/AIR      | ✅ Supported   | Uses `openfl.net.DatagramSocket` (event-driven)              |
| js (HTML5)     | ❌ Not supported | Browsers block UDP sockets                                  |
| java           | ⚠️ Untested    | Should work if `sys.net.UdpSocket` is available; platform bugs may exist |
| android/ios    | ⚠️ Untested    | May require permissions and additional setup                 |

**Notes:**
- Native desktop targets (neko, hl, cpp) use a background polling thread for UDP receive.
- Flash/AIR targets use OpenFL’s event-driven DatagramSocket.
- JavaScript/HTML5 targets are not supported due to browser security restrictions on UDP.
- Java, Android, and iOS support is untested in production; please report your results or PRs!

---

## Minimum Haxe and OpenFL Versions

| Library | Minimum Version | Recommended Version         |
|---------|----------------|----------------------------|
| Haxe    | 4.2.0          | 4.3.7+                     |
| OpenFL  | 9.2.0          | 9.4.1+                       |

- Relies on `openfl.net.DatagramSocket`, which is available in OpenFL 9.2.0 and later.
- Makes use of the `final` static field and `Map` improvements, which are available in Haxe 4.2.0 and later.
- Versions older than Haxe 4.2.0 and OpenFL 9.2.0 will require changes and are not officially supported.

---

## Art-Net Protocol Compatibility

This library is designed to interoperate with all mainstream Art-Net II, III, and IV hardware and software for standard DMX data and network discovery.

- **ArtDMX:** Fully supported for all Art-Net 2, 3, and 4 nodes and controllers. The packet structure follows the core Art-Net specification and will be understood by all compliant devices.
- **ArtPoll & ArtPollReply:** Discovery (sending ArtPoll, receiving and parsing ArtPollReply) matches the protocol standards from Art-Net 2 forward. Essential node details (IP, names, universes, etc.)[...]
- **Protocol Versioning:** The library uses protocol version 14 (Art-Net 4) by default; all Art-Net 2/3/4 nodes will interoperate correctly.
- **Limitations:** Advanced Art-Net 4 features (such as IPv6 support, extended diagnostics, or support for extra-large universe counts) are not explicitly implemented. The core features implemented he[...]

**Summary:**  
For standard DMX transport and node discovery, this library is compatible with any Art-Net 2/3/4 node or controller you are likely to encounter.

---

## License

MIT License.  
Attribution: Based on https://github.com/jahewson/ArtNetSocket, extended and documented by David Armstrong (B-Interactive).
