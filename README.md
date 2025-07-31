# ArtNetSocket

Cross-platform, event-driven UDP socket for Art-Net and other UDP protocols, designed for Haxe/OpenFL projects.

## Features

- **Native support**: C++, HashLink, Neko
- **AIR/Flash support**: Uses `openfl.net.DatagramSocket`
- **Threaded polling**: On native, uses a background thread for non-blocking receive
- **Custom events**: Dispatches data and error events for easy integration

## Usage Example

```haxe
import b-interactive.artnetsocket.ArtNetSocket;
import haxe.io.Bytes;

var socket = new ArtNetSocket(6454); // Art-Net default port

socket.addEventListener(ArtNetSocket.DATA, function(e) {
    var evt = cast(e, ArtNetDataEvent);
    trace('Received from ' + evt.host + ':' + evt.port + ' data: ' + evt.data.length + ' bytes');
});

socket.addEventListener(ArtNetSocket.ERROR, function(e) {
    var evt = cast(e, ArtNetErrorEvent);
    trace('Error: ' + evt.message);
});

// To send data:
var data = Bytes.alloc(530);
socket.send(data, "192.168.1.50", 6454);
```

## Compatibility

| Target                | Supported | Notes                                      |
|-----------------------|:---------:|--------------------------------------------|
| C++ (native)          | ✅        |                                            |
| HashLink (HL)         | ✅        |                                            |
| Neko                  | ✅        |                                            |
| AIR (Flash desktop)   | ✅        |                                            |
| AIR (Mobile)          | ❌        | Not supported (no UDP on AIR mobile)       |
| HTML5 (browser)       | ❌        | Not supported (no UDP in browsers)         |
| JavaScript/Node.js    | ❌        | Not supported (no UDP in OpenFL/JS target) |
| Python, Java, C#, PHP | ❌        | Not supported                              |

## License

MIT License (see [LICENSE](LICENSE)).

## Attribution

This implementation is a simplified Haxe port based on:
- https://github.com/jahewson/ArtNetSocket

See [NOTICE](NOTICE) for further details.

## Author

- David Armstrong (B-Interactive)
