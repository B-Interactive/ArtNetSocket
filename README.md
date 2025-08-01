# ArtNetSocket for Haxe

An optimised, cross-platform Art-Net UDP socket for Haxe and OpenFL.

---

**Jump to:**  
[Features](#features) | [Installation](#installation) | [Usage Example](#usage-example) | [Simplified DMX Packet Helper](#simplified-dmx-packet-helper) | [Event Types](#event-types) | [OpenFL Target Compatibility](#openfl-target-compatibility) | [Minimum Haxe and OpenFL Versions](#minimum-haxe-and-openfl-versions) | [Art-Net Protocol Compatibility](#art-net-protocol-compatibility) | [Web Browser UDP Support](#web-browser-udp-support) | [License](#license)

---

## Features

- **Send/receive ArtDMX** (DMX data, event-driven)
- **Send ArtPoll** (for Art-Net node discovery)
- **Receive/parse ArtPollReply** (discovery replies, exposes node info)
- **Event-driven API:** Fires `ArtDMXEvent`, `ArtPollReplyEvent`, `ArtNetDataEvent`, `ArtNetErrorEvent`
- **Native and AIR/Flash:** Uses polling thread for native targets; event-based for AIR/Flash

## Installation

```bash
haxelib git artnetsocket https://github.com/B-Interactive/artnetsocket
```

## Usage Example

```haxe
import binteractive.artnetsocket.ArtNetSocket;
import binteractive.artnetsocket.ArtNetHelper;
import haxe.io.Bytes;

// Create socket on Art-Net port
var socket = new ArtNetSocket(6454);

// Listen for DMX data
socket.addEventListener(ArtNetSocket.ARTDMX, function(e) {
    var evt = cast(e, ArtDMXEvent);
    trace('DMX from ${evt.host}:${evt.port} universe ${evt.dmx.universe} data size: ${evt.dmx.length}');
});

// Listen for node discovery replies
socket.addEventListener(ArtNetSocket.ARTPOLLREPLY, function(e) {
    var evt = cast(e, ArtPollReplyEvent);
    trace('Node: ${evt.info.shortName} @ ${evt.info.ip} Universes: ${evt.info.numPorts}');
});

// Send ArtPoll (broadcast discovery request)
socket.sendPoll();

// Send a DMX packet with just channels 1 and 5 set (all others zero)
var dmx = ArtNetHelper.makeDMXPacket({
  universe: 0,
  values: [
    { channel: 1, value: 255 },
    { channel: 5, value: 42 }
  ]
});
socket.sendDMX(dmx, "192.168.1.100");

// Or send a block of DMX values using an array (dense, 0-based: array[0] = channel 1)
var dmxBlock = ArtNetHelper.makeDMXPacket({
  universe: 1,
  array: [255, 128, 0, 0, 42] // Channels 1-5
});
socket.sendDMX(dmxBlock, "192.168.1.100");

// Or set a few DMX slots using a map/dictonary (all others zero)
var channelMap = new Map<Int, Int>();
channelMap.set(1, 100);
channelMap.set(4, 200);
var dmxPacket = ArtNetHelper.makeDMXPacket({
  universe: 2,
  map: channelMap
});
socket.sendDMX(dmxMap, "192.168.1.100");

// Handle errors
socket.addEventListener(ArtNetSocket.ERROR, function(e) {
    trace('Socket error: ' + cast(e, ArtNetErrorEvent).message);
});
```

---

## Simplified DMX Packet Helper

You can easily construct DMX packets using the `ArtNetHelper.makeDMXPacket()` function, which supports several user-friendly ways to specify channel data:

- **Dense array** (`array: [Int]`):  
  Set DMX values for channels 1..N where `array[0]` is channel 1, `array[1]` is channel 2, etc. The packet length will be `array.length`.
  ```haxe
  // Sets channel 1 to 255, 2 to 128, 3 to 0, 4 to 0, 5 to 42
  var pkt = ArtNetHelper.makeDMXPacket({array: [255, 128, 0, 0, 42]});
  ```

- **Sparse channel/value list** (`values: [{channel, value}]`):  
  Set specific DMX channels by index (1-based), all others are zero.
  ```haxe
  var pkt = ArtNetHelper.makeDMXPacket({
    values: [ {channel: 1, value: 255}, {channel: 2, value: 128}, {channel: 5, value: 42} ]
  });
  ```

- **Map/object** (`map: {channel: value}`):  
  Like `values`, but as an object with channel numbers as keys; all others zero.
  ```haxe
  var pkt = ArtNetHelper.makeDMXPacket([ 1 => 255, 2 => 128, 5 => 42 ]);
  ```
  
  
- **Raw Bytes** (`data: Bytes`):  
  Use an existing `Bytes` object. Highest priority; all other options ignored.
  ```haxe
  var bytes = Bytes.alloc(3); bytes.set(1, 255); bytes.set(2, 128); bytes.set(5, 42);
  var pkt = ArtNetHelper.makeDMXPacket({data: bytes});
  ```

**Other options:**
- `universe`: Art-Net universe (default 0)
- `length`: Number of DMX slots (default 512; if using array or data, inferred)
- `protocolVersion`: Art-Net protocol version (default 14)
- `sequence`: Sequence number (default 0)
- `physical`: Physical port (default 0)

**Priority:**  
If you provide `data`, it is used as-is. If you provide `array`, it is used next. Otherwise, `values` and `map` are used to fill a zeroed buffer of length `length` (default 512).

---

## Event Types

- `ArtNetSocket.ARTDMX` (`ArtDMXEvent`): DMX data received
- `ArtNetSocket.ARTPOLLREPLY` (`ArtPollReplyEvent`): Node discovery reply
- `ArtNetSocket.DATA` (`ArtNetDataEvent`): Unparsed UDP data
- `ArtNetSocket.ERROR` (`ArtNetErrorEvent`): Socket error

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
| Haxe    | 4.0.0          | 4.3.7+                     |
| OpenFL  | 8.0.0          | 9.x+                       |

- The library uses modern Haxe types (`haxe.io.Bytes`, etc.) and OpenFL event APIs.
- Haxe 3.x and OpenFL 7.x or older will require changes and are not officially supported.

---

## Art-Net Protocol Compatibility

This library is designed to interoperate with all mainstream Art-Net II, III, and IV hardware and software for standard DMX data and network discovery.

- **ArtDMX:** Fully supported for all Art-Net 2, 3, and 4 nodes and controllers. The packet structure follows the core Art-Net specification and will be understood by all compliant devices.
- **ArtPoll & ArtPollReply:** Discovery (sending ArtPoll, receiving and parsing ArtPollReply) matches the protocol standards from Art-Net 2 forward. Essential node details (IP, names, universes, etc.) are parsed and exposed.
- **Protocol Versioning:** The library uses protocol version 14 (Art-Net 4) by default; all Art-Net 2/3/4 nodes will interoperate correctly.
- **Limitations:** Advanced Art-Net 4 features (such as IPv6 support, extended diagnostics, or support for extra-large universe counts) are not explicitly implemented. The core features implemented here cover nearly all real-world Art-Net usage.

**Summary:**  
For standard DMX transport and node discovery, this library is compatible with any Art-Net 2/3/4 node or controller you are likely to encounter.

---

## Web Browser UDP Support

**General UDP networking is not available in web browsers.**  
Browsers do not expose raw UDP socket APIs to user code for security reasons.

- **WebRTC DataChannels** use UDP internally but are only for peer-to-peer comms and do not offer generic UDP socket access.
- **WebTransport (UDP/QUIC)** is not a general UDP socket and only works with compatible servers.
- **No browser (Chrome, Firefox, Safari, Edge, etc.) supports arbitrary UDP for Art-Net or similar protocols.**
- **Workaround:** Use a native application or a WebSocket-to-UDP bridge for browser-based tools.

---

## License

MIT License.  
Attribution: Based on https://github.com/jahewson/ArtNetSocket, extended and documented by David Armstrong (B-Interactive).
