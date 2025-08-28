# Conch Example

This example demonstrates a complete working setup of Conch with custom commands. It addresses the common issue of commands not appearing by showing the correct setup order and file structure.

## What This Example Shows

- ✅ **Correct initialization order** - `initiate_default_lifecycle()` before command registration
- ✅ **Proper file locations** - Server script in `server/`, client script in `client/`
- ✅ **Permission setup** - How to give players access to commands
- ✅ **Multiple command types** - Both `register()` and `register_quick()` examples

## File Structure

```
src/
├── server/
│   └── init.server.luau    # Server-side setup and command registration
├── client/
│   └── init.client.luau    # Client-side UI setup
└── shared/
    └── (shared modules)
```

## Key Points

1. **Server commands** are registered in `src/server/init.server.luau`
2. **Client setup** happens in `src/client/init.client.luau` 
3. **Initialization order matters** - `initiate_default_lifecycle()` must come before `register()`
4. **Players need permissions** - The example gives everyone `super-user` role for testing

## Running the Example

To build the place from scratch, use:

```bash
rojo build -o "example.rbxlx"
```

Next, open `example.rbxlx` in Roblox Studio and start the Rojo server:

```bash
rojo serve
```

## Testing Commands

1. **Open the console** - Press F4 in-game
2. **Try the commands**:
   - `meow` - Simple command that logs a message
   - `test PlayerName` - Command that takes a player argument

## Troubleshooting

If commands don't appear:
- Check that you're given the `super-user` role (happens automatically in this example)
- Verify both server and client scripts are running
- Make sure packages are in the correct location

For more help, see the [Troubleshooting Guide](https://alicesaidhi.github.io/conch/resources/getting-started/6-troubleshooting) or check out [the Rojo documentation](https://rojo.space/docs).