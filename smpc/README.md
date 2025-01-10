# Secure Multi-Party Computation for Weighted Sum

## Project Overview
This project implements a cryptographic method to compute the weighted sum of inputs from multiple parties without revealing their individual inputs. The implementation uses **secret sharing** to achieve this goal.

### Objective
To compute the weighted sum:

**S = Σ (w_i * x_i)**

where:
- **n**: Number of players
- **x_i**: Secret input of party **i**
- **w_i**: Public weights associated with each input

The computation ensures that no party learns the inputs **x_j** of any other party **j ≠ i**.

## Steps to Run the Program

### Prerequisites
- Lua (tested with version 5.4+)
- `luasocket` library for network communication

### Setup
```bash
git clone <repository_url>
cd <repository_name>
luarocks install luasocket
```

### Run
```bash
lua participant.lua [number of participants]
```

