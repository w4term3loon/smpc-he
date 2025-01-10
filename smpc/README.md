# Secure Multi-Party Computation (SMPC) for Weighted Sum

## Project Overview
This project implements a cryptographic method to compute the weighted sum of inputs from multiple parties without revealing their individual inputs. The implementation uses **secret sharing** to achieve this goal.

### Objective
To compute the weighted sum:

\[ S = \sum_{i=1}^{n} w_i \cdot x_i \]

where:
- \( n \): Number of players
- \( x_i \): Secret input of party \( i \)
- \( w_i \): Public weights associated with each input

The computation ensures that no party learns the inputs \( x_j \) of any other party \( j \neq i \).

## Steps to Run the Program

### Prerequisites
- Lua (tested with version 5.4+)
- `luasocket` library for network communication

### Setup
1. Clone the repository:
   ```bash
   git clone <repository_url>
   cd <repository_name>
   ```

2. Install dependencies:
   ```bash
   luarocks install luasocket
   ```

### Running the Program

## Example
### Input
- Number of parties: 3
- Public weights: \( w_1 = 2, w_2 = 3, w_3 = 5 \)
- Secret inputs: \( x_1 = 10, x_2 = 20, x_3 = 30 \)

### Output
The program will compute:
\[ S = 2 \cdot 10 + 3 \cdot 20 + 5 \cdot 30 = 230 \]


