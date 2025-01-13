# Secure Multi-Party Computation for Weighted Sum

## Overview

This project demonstrates a cryptographic protocol to compute the weighted sum, while ensuring input privacy, so no participant learns another's secret input. Communication is achieved over TCP connections between the participants for reliable data transfer. Due to theoretical perfect-privacy, data encryption is not necessary.

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

#### First Participant:

Run the following command to start the first participant:

```bash
lua participant.lua [number_of_participants] [sec]
```

- Replace `[number_of_participants]` with the desired total.
- If omitted, the default number of participants is `3`.
- Use `sec` to output secure data aswell to `stdout`.

#### Other Participants:

Subsequent participants can join with:

```bash
lua participant.lua [sec]
```

#### Swarm simulation:

To simulate multiple participants in one process, run:

```bash
chmod +x swarm.sh
./swarm.sh [number_of_participants]
```

- Logs will be generated in `log/{timestamp}`
- Results are compared at the end.
