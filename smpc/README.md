# Secure Multi-Party Computation for Weighted Sum

## Overview
This project implements a secure multi-party computation (MPC) protocol for calculating weighted sums while preserving input privacy. Each participant contributes a secret value to a weighted sum computation without revealing their individual inputs to other participants.

[](screenshot.png)

### Key Features
- Secret sharing-based privacy preservation
- Distributed weighted sum computation
- TCP-based secure communication between participants
- Perfect theoretical privacy without encryption
- Support for dynamic number of participants
- Built-in simulation capabilities for testing

## Technical Details
- Uses additive secret sharing over a Mersenne prime field (2^31 - 1)
- Implements secure distributed sum protocol
- Handles automatic share distribution and collection
- Provides verification of computation correctness
- Includes logging and debugging capabilities

## Prerequisites
- Lua 5.4 or higher
- LuaSocket library for network communication
- POSIX-compliant shell (for swarm simulation)

## Installation

1. Clone the repository:
```bash
git clone <repository_url>
cd <repository_name>
```

2. Install required dependencies:
```bash
luarocks install luasocket
```

## Usage

### Single Participant Mode

#### First Participant (Coordinator)
```bash
lua participant.lua [num_participants] [sec]
```
Parameters:
- `num_participants`: Total number of participants (optional, default: 3)
- `sec`: Enable secure data logging (optional)

#### Additional Participants
```bash
lua participant.lua [sec]
```
Parameters:
- `sec`: Enable secure data logging (optional)

### Swarm Simulation Mode
For testing with multiple simulated participants:
```bash
chmod +x swarm.sh
./swarm.sh [num_participants]
```

### Output and Logging
- Standard logs are written to stdout
- When `sec` flag is enabled, secure data (shares, secrets) are also logged
- Swarm simulation logs are stored in `log/{timestamp}/`
- Final results include verification of computation correctness

## Protocol Steps
1. Coordinator initialization and participant connection
2. Public parameter distribution (weights)
3. Secret value generation
4. Share generation and distribution
5. Partial sum calculation
6. Final weighted sum computation
7. Result verification

## Security Features
- Perfect privacy through secret sharing
- No information leakage during computation
- Secure against passive adversaries
- Maintains privacy with up to n-1 compromised participants

## Implementation Details
- Uses LuaSocket for reliable TCP communication
- Implements automatic retry mechanism for network operations
- Handles concurrent connections efficiently
- Provides error handling and recovery

## Testing and Verification
- Built-in correctness verification
- Automated testing through swarm simulation
- Log comparison for verification
- Support for different participant counts

## Limitations
- Requires honest participants (semi-honest security model)
- All participants must be online simultaneously
- Network latency affects performance
- Maximum participant count limited by Mersenne prime field

