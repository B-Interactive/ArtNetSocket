# ArtNetSocket for Haxe

Cross-platform, event-driven UDP socket tailored for Art-Net (OpenFL/Haxe 4.3+).  
Uses OpenFL's DatagramSocket for all supported targets (cpp, hashlink, neko, AIR/Flash).

## Pre-Release Software
This is pre-release software undergoing active development. Chances are it will not work at all... yet.

**Features:**
- Simple DMX send/receive (ArtDMX, ArtPoll, ArtPollReply)
- Automatic network config (subnet, broadcast)
- Event-driven protocol parsing
- Typed packets and helpers
- **Persistent DMX buffer mode for efficient sparse channel updates**

## Installation

```bash
haxelib git artnetsocket https://github.com/B-Interactive/artnetsocket
```

## Usage Example

```haxe
import binteractive.artnetsocket.ArtNetSocket;
import binteractive.artnetsocket.ArtNetHelper;

var socket = new ArtNetSocket(); // or pass your config path

socket.addEventListener(ArtNetSocket.ARTDMX, function(e) {
    var dmx = cast(e, ArtDMXEvent).packet;
    trace('Received DMX: ' + dmx.universe + ' len=' + dmx.length);
});

socket.addEventListener(ArtNetSocket.ARTPOLLREPLY, function(e) {
    var reply = cast(e, ArtPollReplyEvent).packet;
    trace('Received ArtPollReply from ' + reply.ip + ': ' + reply.shortName);
});

socket.addEventListener(ArtNetSocket.ERROR, function(e) {
    trace('Socket error: ' + cast(e, ArtNetErrorEvent).message);
});

// Send DMX to one address (non-persistent mode, array form)
var dmx = ArtNetHelper.makeDMXPacket([0,0,255,255,0,0,0,0]);
socket.sendDMX(dmx, "192.168.1.100");

// Broadcast DMX
socket.broadcastDMX(dmx);

// Broadcast ArtPoll (node discovery)
socket.sendPoll();
```

---

## ArtNetHelper DMX Packet Construction

ArtNetHelper provides a simple way to create an ArtDMXPacket for sending DMX data.  
**Supports both persistent and non-persistent buffer modes.**

### Non-Persistent Mode (Default)

- Any unspecified, `null`, or `-1` channel value is assumed to be **0** each time you call `makeDMXPacket`.
- You must provide all channel values you wish to set for every packet.

```haxe
// Method 1: From an array of DMX values (channels 0..N)
var pkt = ArtNetHelper.makeDMXPacket([0, 255, 128, 0, ...]); // Unspecified/null/-1 channels = 0

// Method 2: Specify options using an object
var pkt = ArtNetHelper.makeDMXPacket({
    universe: 0,
    values: [10, 20, 30, ...] // DMX values (array). Unspecified/null/-1 channels = 0
});

// Method 3: Advanced usage with a Haxe Map
var map = new Map<String, Dynamic>();
map.set("universe", 0);
map.set("length", 512);
map.set("data", myByteArray); // ByteArray containing DMX data
var pkt = ArtNetHelper.makeDMXPacket(map);
```

### Persistent Mode

Enable persistent mode to let the library **retain a DMX buffer behind the scenes**:
- Any channel value set to `null` or `-1` in the input will **not change** that channel; its previous value is retained from the buffer.
- Only non-null, non--1 values in your input array or object will update the corresponding channel.
- All other channels keep their previous values.

```haxe
// Enable persistent mode
ArtNetHelper.setPersistentMode(true);

// Update channels 10-14 only (other channels retain their previous values)
ArtNetHelper.makeDMXPacket([
  null, null, null, null, null, null, null, null, null, null, // channels 0-9: no change
  255, null, 128, -1, 75 // channels 10-14: update as specified
]);

// Update channels 5 and 13 only (sparse)
ArtNetHelper.makeDMXPacket({ channels: [5, 13], values: [100, 255] });

// You can always get a copy of the buffer:
var currentBuffer = ArtNetHelper.getPersistentBuffer();

// Disable persistent mode (reverts to non-persistent behavior)
ArtNetHelper.setPersistentMode(false);

// Reset persistent buffer to zero if needed
ArtNetHelper.clearPersistentBuffer();
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
