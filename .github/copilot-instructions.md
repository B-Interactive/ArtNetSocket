This is a Haxe based repository leveraging the OpenFL framework. The purpose is to provide Art-Net client (sending Art-Net packets containing DMX instructions), and Art-Net discovery functionality.

## Code Standards

### Required Before Each Commit

### Development Flow
- Build: `openfl build cpp`
- Test: `openfl test cpp`

## Repository Structure
- `src/`: The beginning of the source tree.

## Key Guidelines
1. Prioritise OpenFL paradigms over native Haxe.
2. Fallback to Haxe paradigms only where target support requires it.
3. Consider memory safety and performance optimisations.
4. Make source easily readable, providing useful code comments..
5. Document public APIs and complex logic in README.md.
