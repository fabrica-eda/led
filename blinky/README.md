# LFE5UM5G-85F-EVN blinky

This project drives the eight evaluation-board LEDs from bits 23 through 16 of
a 24-bit counter. The design assumes the Struo board target
`LFE5UM5G-85F-EVN` and its FTDI-provided 12 MHz clock.

## Board setup

- Short JP2 so the FTDI 12 MHz clock reaches FPGA pin A10.
- Leave JP1 open so the on-board FTDI remains enabled.
- Connect and power the board through its FTDI USB port.
- The push button on P4 is an active-low asynchronous reset.

## Verified flow

The generated artifacts under `build/` are produced from `src/Top.veryl`:

1. Celox 0.4 from the pinned Cargo Git dependency simulated 196,608 RTL cycles.
2. Struo synthesized 68 nodes and 24 registers into 40 ECP5 cells, signed off
   mapping equivalence, and Celox 0.3 verified the mapped netlist for 196,608
   cycles.
3. Texo placed 69 physical cells, routed 84 nets through 542 PIPs, and met the
   12 MHz setup and hold constraints.
4. Texo's native ECP5 bitstream flow generated the Project Trellis
   configuration and verified an `ecppack`/`ecpunpack` round trip.

The Rust verification and native PnR flow is one Cargo workspace with pinned Git
dependencies, so separate Struo, Texo, and Celox checkouts are not needed:

```sh
./build.sh
```

`build.sh` runs the pinned Cargo verifier and produces `build/Top.bit` directly
from the Texo checkpoint using Project Trellis. No external P&R tool is required.
To run only simulation, Struo synthesis, and Texo place-and-route:

```sh
./prepare-architecture.sh
cargo run --locked --release -p verify-blinky
```

## Program SRAM from WSL2

The FTDI USB device must first be attached to WSL2. From an elevated Windows
terminal, install/configure usbipd-win if needed, then bind and attach the
board's bus ID:

```powershell
winget install --interactive --exact dorssel.usbipd-win
usbipd list
usbipd bind --busid <BUSID>
usbipd attach --wsl --busid <BUSID>
```

Install `openFPGALoader`, then run in WSL2:

```sh
sudo apt install openfpgaloader
./blinky/program.sh
```

The script uses openFPGALoader's `ecp5_evn` target for the board's FT2232H JTAG
interface. It loads SRAM only; power cycling restores the board's previous
configuration.
