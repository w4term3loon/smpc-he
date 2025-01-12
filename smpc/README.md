# Secure Multi-Party Computation for Weighted Sum

## Overview

This project demonstrates a cryptographic protocol to compute the weighted sum:

**S = Σ (w\_i \* x\_i)**

where:

- **x\_i**: Secret input of participant **i**
- **w\_i**: Public weight for **x\_i**

The protocol ensures input privacy, so no participant learns another's secret input.

## Prerequisites

- Lua 5.4+
- `luasocket` (install via `luarocks`)

## Setup

1. Clone the repository:
   ```bash
   git clone <repository_url>
   cd <repository_name>
   ```
2. Install dependencies:
   ```bash
   luarocks install luasocket
   ```

## Run

The **first participant** must declare the total number of participants. If omitted, the default value is `3`. Other participants connect automatically.

### Example

#### First Participant:

Run the following command to start the first participant:

```bash
lua participant.lua [number_of_participants]
```

- Replace `[number_of_participants]` with the desired total.
- If omitted, the default number of participants is `3`.

#### Other Participants:

Subsequent participants can join with:

```bash
lua participant.lua
```

