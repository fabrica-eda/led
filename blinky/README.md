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
4. Texo 0.1.2's native ECP5 bitstream flow generated the configuration and
   SRAM bitstream.

The Rust workspace uses pinned Struo and Celox Git dependencies for simulation,
synthesis, mapping, and post-map verification. Texo is installed as a released
CLI with `fabricaup`; no Struo, Texo, or Celox source checkout is needed:

```sh
./build.sh
```

`build.sh` fetches the verified ECP5 target pack, runs the Cargo verifier, then
uses Texo 0.1.2 for place-and-route and native bitstream generation. No external
P&R tool is required. To run only simulation, Struo synthesis, mapping, and
post-map verification:

```sh
cargo run --locked --release -p verify-blinky
```

To fetch or refresh the target pack separately:

```sh
./prepare-architecture.sh
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

This path is hardware-verified on the ECP5 5G evaluation board: JTAG detection
reported ID `0x81113043`, and the generated `Top.bit` completed SRAM erase,
configuration loading, and finalization with openFPGALoader.
