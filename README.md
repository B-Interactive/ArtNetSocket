# ArtNetSocket for Haxe

An optimised, cross-platform Art-Net UDP socket for Haxe and OpenFL.

---

**Jump to:**  
[Features](#features) | [Usage Example](#usage-example) | [Event Types](#event-types) | [OpenFL Target Compatibility](#openfl-target-compatibility) | [Minimum Haxe and OpenFL Versions](#minimum-haxe-and-openfl-versions) | [Art-Net Protocol Compatibility](#art-net-protocol-compatibility) | [Web Browser UDP Support](#web-browser-udp-support) | [License](#license)

---

## Features

- **Send/receive ArtDMX** (DMX data, event-driven)
- **Send ArtPoll** (for Art-Net node discovery)
- **Receive/parse ArtPollReply** (discovery replies, exposes node info)
- **Event-driven API:** Fires `ArtDMXEvent`, `ArtPollReplyEvent`, `ArtNetDataEvent`, `ArtNetErrorEvent`
- **Native and AIR/Flash:** Uses polling thread for native targets; event-based for AIR/Flash

## Usage Example

```haxe
import b_interactive.artnetsocket.ArtNetSocket;
import b_interactive.artnetsocket.ArtNetHelper;
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

// Send DMX to a node
var dmx = {
  protocolVersion: 14,
  sequence: 1,
  physical: 0,
  universe: 0,
  length: 512,
  data: Bytes.alloc(512)
};
socket.sendDMX(dmx, "192.168.1.100");

// Handle errors
socket.addEventListener(ArtNetSocket.ERROR, function(e) {
    trace('Socket error: ' + cast(e, ArtNetErrorEvent).message);
});
```

## Event Types

- `ArtNetSocket.ARTDMX` (`ArtDMXEvent`): DMX data received
- `ArtNetSocket.ARTPOLLREPLY` (`ArtPollReplyEvent`): Node discovery reply
- `ArtNetSocket.DATA` (`ArtNetDataEvent`): Unparsed UDP data
- `ArtNetSocket.ERROR` (`ArtNetErrorEvent`): Socket error

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

## Minimum Haxe and OpenFL Versions

| Library | Minimum Version | Recommended Version         |
|---------|----------------|----------------------------|
| Haxe    | 4.0.0          | 4.3.7+                     |
| OpenFL  | 8.0.0          | 9.x+                       |

- The library uses modern Haxe types (`haxe.io.Bytes`, etc.) and OpenFL event APIs.
- Haxe 3.x and OpenFL 7.x or older will require changes and are not officially supported.

## Art-Net Protocol Compatibility

This library is designed to interoperate with all mainstream Art-Net II, III, and IV hardware and software for standard DMX data and network discovery.

- **ArtDMX:** Fully supported for all Art-Net 2, 3, and 4 nodes and controllers. The packet structure follows the core Art-Net specification and will be understood by all compliant devices.
- **ArtPoll & ArtPollReply:** Discovery (sending ArtPoll, receiving and parsing ArtPollReply) matches the protocol standards from Art-Net 2 forward. Essential node details (IP, names, universes, etc.) are parsed and exposed.
- **Protocol Versioning:** The library uses protocol version 14 (Art-Net 4) by default; all Art-Net 2/3/4 nodes will interoperate correctly.
- **Limitations:** Advanced Art-Net 4 features (such as IPv6 support, extended diagnostics, or support for extra-large universe counts) are not explicitly implemented. The core features implemented here cover nearly all real-world Art-Net usage.

**Summary:**  
For standard DMX transport and node discovery, this library is compatible with any Art-Net 2/3/4 node or controller you are likely to encounter.

## Web Browser UDP Support

**General UDP networking is not available in web browsers.**  
Browsers do not expose raw UDP socket APIs to user code for security reasons.

- **WebRTC DataChannels** use UDP internally but are only for peer-to-peer comms and do not offer generic UDP socket access.
- **WebTransport (UDP/QUIC)** is not a general UDP socket and only works with compatible servers.
- **No browser (Chrome, Firefox, Safari, Edge, etc.) supports arbitrary UDP for Art-Net or similar protocols.**
- **Workaround:** Use a native application or a WebSocket-to-UDP bridge for browser-based tools.

## License

MIT License.  
Attribution: Based on https://github.com/jahewson/ArtNetSocket, extended and documented by David Armstrong (B-Interactive).
