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
4. nextpnr packaged the same Struo mapped netlist for Project Trellis and
   reported 513.87 MHz maximum clock frequency against the 12 MHz constraint.
5. ecppack produced `build/Top.bit` and `build/Top.svf`.

The Rust verification and native PnR flow is one Cargo workspace with pinned Git
dependencies, so separate Struo, Texo, and Celox checkouts are not needed:

```sh
./build.sh
```

`build.sh` runs the pinned Cargo verifier and produces `build/Top.bit` using
nextpnr and Project Trellis. To run only simulation, Struo synthesis, and Texo
place-and-route:

```sh
./prepare-architecture.sh
cargo run --locked --release -p verify-blinky
```

## Program SRAM with Windows Diamond Programmer

The board can remain attached to Windows. With Lattice Diamond installed, run
this from WSL2:

```sh
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w ./blinky/program-diamond.ps1)"
```

`Top.diamond.xcf` fixes the expected JTAG device to `LFE5UM5G-85F` with ID
`0x81113043`; Diamond aborts before programming if the detected device differs.
The command log is written to `build/diamond-program.log`.

If a repeat run reports ID `0x7FFFFFFF`, press board button SW3 (PROGRAMN) or
power-cycle the board, then run the command again. SW3 clears the active SRAM
configuration without requiring a power cycle.

## Alternative: program directly from WSL2

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

Both methods load SRAM only; power cycling restores the board's previous
configuration.
