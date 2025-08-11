# ArtNetSocket for Haxe

Cross-platform, event-driven UDP socket tailored for Art-Net (OpenFL/Haxe 4.3+).  
Uses OpenFL's DatagramSocket for all supported targets (cpp, hashlink, neko, AIR/Flash).

## Pre-Release Software
**This is pre-release software undergoing active development. Chances are it will not work at all... yet.**

---

**Features:**
- Simple DMX send/receive (ArtDMX)
- Event-driven protocol parsing
- Typed packets and helpers
- Persistent DMX buffer mode for efficient sparse channel updates
- Exposed DEFAULT_PORT constant (6454) for Art-Net standard port

**Note:** ArtPoll / ArtPollReply discovery is currently not supported due to limitations with UDP broadcast reception in Haxe's sys.net.UdpSocket.

## Installation

```bash
haxelib git artnetsocket https://github.com/B-Interactive/artnetsocket
```

## Usage Example

```haxe
import binteractive.artnetsocket.ArtNetSocket;
import binteractive.artnetsocket.ArtNetSocketEvents;

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

// Note: ArtPoll discovery is currently not supported due to UDP broadcast reception limitations
// Art-Net Poll responses (ArtPollReply packets) cannot be received with Haxe's sys.net.UdpSocket

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
```

---

## ArtNetSocket DMX Packet Construction

ArtNetSocket provides three explicit methods to create ArtDMXPackets for sending DMX data with different input types.  
**Supports both persistent and non-persistent buffer modes.**

### Available Methods

- `makeDMXFromArray(arr:Array<Int>, ?universe:Int, ?length:Int):ArtDMXPacket`
- `makeDMXFromMap(map:haxe.ds.IntMap<Int>, ?universe:Int, ?length:Int):ArtDMXPacket`
- `makeDMXFromByteArray(ba:ByteArray, ?universe:Int, ?length:Int):ArtDMXPacket`

### Persistent Mode (Default)

Persistent mode is enabled by default. The library **retains a DMX buffer behind the scenes**:
- Any channel value set to `null` or `-1` in array input will **not change** that channel; its previous value is retained from the buffer.
- Only non-null, non--1 values in your input array will update the corresponding channel.
- All other channels keep their previous values.
- Map and ByteArray inputs always overwrite the channels they specify.

```haxe
var socket = new ArtNetSocket(); // persistentDMX defaults to true

// Method 1: Array input - update specific channels, others retain previous values
var pkt = socket.makeDMXFromArray([255, null, 128, -1, 75]); // channels 1 and 3 unchanged

// Method 2: IntMap input for sparse updates
var channelMap = new haxe.ds.IntMap<Int>();
channelMap.set(5, 100);   // Set channel 5 to 100
channelMap.set(13, 255);  // Set channel 13 to 255
var pkt = socket.makeDMXFromMap(channelMap); // Other channels retain previous values

// Method 3: ByteArray input (overwrites channels 0..N)
var ba = new ByteArray();
ba.writeByte(50);
ba.writeByte(75);
ba.writeByte(100);
var pkt = socket.makeDMXFromByteArray(ba); // Channels 0-2 set, others retain values
```

### Non-Persistent Mode

Disable persistent mode to reset the buffer before each packet:
- Any unspecified, `null`, or `-1` channel value is assumed to be **0** each time you call the DMX methods.
- You must provide all channel values you wish to set for every packet.

```haxe
// Disable persistent mode
socket.persistentDMX = false;

// Array input - unspecified/null/-1 channels become 0
var pkt = socket.makeDMXFromArray([255, null, 128, -1]); // Results in [255, 0, 128, 0, 0, 0, ...]

// Map and ByteArray inputs work the same, but other channels are 0
var channelMap = new haxe.ds.IntMap<Int>();
channelMap.set(10, 255);
var pkt = socket.makeDMXFromMap(channelMap); // Channel 10 = 255, all others = 0
```

---

## Event Types

- **ArtNetSocket.ARTDMX**: `ArtDMXEvent` - DMX packet received.
- **ArtNetSocket.DATA**: `ArtNetDataEvent` - Raw UDP data received.
- **ArtNetSocket.ERROR**: `ArtNetErrorEvent` - Error occurred.

**Note:** ArtNetSocket.ARTPOLLREPLY events are not supported due to UDP broadcast reception limitations.

---

## OpenFL Target Compatibility

This library is designed for use with OpenFL (Haxe 4.0.0 or newer) and supports the following targets:

| Target         | Status         | Notes                                                         |
|----------------|---------------|---------------------------------------------------------------|
| neko           | ✅ Fully Supported | Full support for ArtNetSocket.sendDMX() and ArtNetSocket.broadcastDMX() |
| cpp            | ✅ Fully Supported | Full support for ArtNetSocket.sendDMX() and ArtNetSocket.broadcastDMX() |
| hl             | ⚠️ Partial      | ArtNetSocket.sendDMX() is supported, but broadcastDMX() is **not supported** |
| flash/AIR      | ⚠️ Partial      | ArtNetSocket.sendDMX() is supported. AIR 51.0.0 adds broadcast support, but OpenFL/Haxe utilization is **uncertain**—please verify for your setup. |
| js (HTML5)     | ❌ Not supported | Browsers block UDP sockets                                  |
| java           | ⚠️ Untested    | Should work if `sys.net.UdpSocket` is available; platform bugs may exist |
| android/ios    | ⚠️ Untested    | May require permissions and additional setup                 |

**Notes:**
- Native desktop targets (neko, cpp) have full DMX send and broadcast support.
- HashLink does not support UDP broadcast.
- AIR/Flash may support broadcast with AIR 51.0.0+, but OpenFL/Haxe integration is not confirmed.
- Java, Android, and iOS support remains untested.
- JavaScript/HTML5 targets are not supported due to browser security restrictions on UDP.

**ArtPoll Discovery Support:**
- ArtPoll / ArtPollReply discovery is **currently not supported** due to limitations with UDP broadcast reception in Haxe's sys.net.UdpSocket.

**DMX Broadcasting Support:**
- `broadcastDMX()`: True UDP broadcast to 255.255.255.255 - **only supported on cpp and neko targets**

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
- **ArtPoll & ArtPollReply:** Discovery is currently not supported due to limitations with UDP broadcast reception in Haxe's sys.net.UdpSocket. While ArtPoll packets can be sent, ArtPollReply responses cannot be received.
- **Protocol Versioning:** The library uses protocol version 14 (Art-Net 4) by default; all Art-Net 2/3/4 nodes will interoperate correctly.
- **Limitations:** Advanced Art-Net 4 features (such as IPv6 support, extended diagnostics, or support for extra-large universe counts) are not explicitly implemented. The core features implemented he[...]

**Summary:**  
For standard DMX transport, this library is compatible with any Art-Net 2/3/4 node or controller you are likely to encounter. Node discovery via ArtPoll is currently not supported.

---

## License

MIT License.  
Attribution: Based on https://github.com/jahewson/ArtNetSocket, extended and documented by David Armstrong (B-Interactive).
