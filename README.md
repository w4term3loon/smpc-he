# MinIPC - Minimal IPC Library for Lua

This component complements the Secure Multi-Party Computation and Secure Two-Party Vector Product Proofs of Concept using the Paillier Cryptosystem.
Below is a brief overview of the IPC functionalities. Detailed descriptions of the two implementations can be found in their respective folders.

## Overview
MiniPC is a lightweight Inter-Process Communication (IPC) library for Lua that provides robust TCP socket communication with automatic retry mechanisms. It simplifies client-server communication patterns with an emphasis on reliability and ease of use.

### Key Features
- Simple server-client socket communication
- Automatic retry mechanism for network operations
- Support for broadcast messages
- Custom callback handling
- Built-in logging system

## Prerequisites
- Lua 5.4+
- LuaSocket library

## Installation
1. Install LuaSocket:
```bash
luarocks install luasocket
```

2. Include the library in your project:
```lua
local minipc = require("minipc.lua")
```

## API Reference

### Configuration
```lua
minipc.ip   -- Server IP address (default: "127.0.0.1")
minipc.port -- Server port (default: 6969)
```

### Logging Functions
```lua
-- Standard logging
minipc.log(message)

-- Secure logging (only visual)
minipc.sec(message)
```

### Network Operations

#### Server Mode
```lua
minipc:serve(message, broadcast, callback)
```
Parameters:
- `message`: Data to send to clients
- `broadcast`: Number of clients to serve (default: 1)
- `callback`: Optional custom handler function(clients, message)

#### Client Mode
```lua
minipc:eat(callback)
```
Parameters:
- `callback`: Optional custom handler function(client)
Returns:
- Received data from server

### Retry Mechanism
```lua
minipc.retry(task, retries, delay)
```
Parameters:
- `task`: Function to retry
- `retries`: Maximum retry attempts (default: 4)
- `delay`: Initial delay in seconds (default: 1)

## Usage Examples

### Basic Server
```lua
local minipc = require("minipc.lua")

-- Serve a message to one client
minipc:serve("Hello, client!")
```

### Basic Client
```lua
local minipc = require("minipc.lua")

-- Receive a message
local message = minipc:eat()
print(message)  -- Outputs: Hello, client!
```

### Broadcasting
```lua
-- Server broadcasting to multiple clients
minipc:serve("Broadcast message", 3)
```

### Custom Callbacks
```lua
-- Server with custom handling
minipc:serve("data", 2, function(clients, message)
    for _, client in ipairs(clients) do
        client:send(message .. " processed\n")
    end
end)

-- Client with custom handling
local result = minipc:eat(function(client)
    local data = client:receive()
    return data .. " acknowledged"
end)
```

### Retry Pattern
```lua
minipc.retry(function()
    return minipc:serve("Important message")
end, 5, 2)
```

## Error Handling
- All network operations are wrapped in error handling
- Failed operations throw descriptive errors
- Retry mechanism helps handle temporary network issues
- Socket resources are properly cleaned up

## Security Features
- Secure logging option for sensitive data
- Proper socket cleanup
- Error handling for connection failures

## Limitations
- TCP-only communication
- Synchronous operations
- Single server instance per port
- Basic error handling

## Future Improvements
- Async operation support
- Multiple server instances
- UDP support
- Enhanced error recovery
- Connection pooling

