This is a Haxe based repository leveraging the OpenFL framework. The purpose is to provide Art-Net client (sending Art-Net packets containing DMX instructions), and Art-Net discovery functionality.

## Key Features
- Provides Art-Net client functionality (send Art-Net packets containing DMX instructions).
- Provides Art-Net discovery, so Art-Net nodes can be discovered and detailed.
- Provides support for persistent DMX buffer per ArtNetSocket (default enabled).

### Required Before Each Commit

### Development Flow
- Build: `openfl build cpp`
- Test: `openfl test cpp`

## Repository Structure
- `src/`: The beginning of the source tree.
- `examples/`: Contains comprehensive examples of usage.
- `tests/`: Contains tests to ensure successful builds.

## Libraries and Frameworks
- Primarily leverage OpenFL paradigms, based on OpenFL latest release version.
- Reference the OpenFL API at https://api.openfl.org/ and codebase at https://github.com/openfl/openfl
- Then, if no OpenFL solution exists, leverage Lime paradigms.
- Reference the Lime API at https://lime.openfl.org/api/ and codebase at https://github.com/openfl/lime
- Apply code optimisation based on the latest release version of Haxe.
- Reference the Haxe API at https://api.haxe.org/ and codebase at https://github.com/HaxeFoundation/haxe

## Key Guidelines
- Consider memory safety and performance optimisations.
- Simulate UDP broadcasts as UDP broadcast is not supported by OpenFL DatagramSocket.
- Make source easily readable, always providing useful code comments.
- Ensure README.md consistently reflects up-to-date features of the API.
- Ensure comprehensive examples under examples/ remain up-to-date.
