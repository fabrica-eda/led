# ECP5 LED template

This repository is a Cargo-workspace template for an eight-LED counter on the
Lattice ECP5 Versa 5G evaluation board (`LFE5UM5G-85F-EVN`). It combines
[Struo](https://github.com/fabrica-eda/struo),
[Texo](https://github.com/fabrica-eda/texo), and
[Celox](https://github.com/celox-sim/celox) without keeping separate source
checkouts in the project.

The design uses the FTDI-provided 12 MHz clock. Counter bits 23 through 16
drive the LEDs, producing the visible binary-count pattern.

## Build on Ubuntu 24.04 / WSL2

Install Rust with rustup, then install the native prerequisites:

```sh
sudo apt update
sudo apt install build-essential clang fpga-trellis fpga-trellis-database
```

Run the complete flow:

```sh
./build.sh
```

This generates the ECP5 architecture snapshot, runs RTL simulation, Struo
synthesis and mapping, Celox post-map simulation, Texo place-and-route,
native ECP5 configuration generation, and an `ecppack`/`ecpunpack` round-trip
check. The SRAM bitstream is written to `blinky/build/Top.bit`.

Generated files stay under `blinky/build/` and are not committed. Programming
through Windows Lattice Diamond or WSL2 `openFPGALoader` is documented in
[blinky/README.md](blinky/README.md).
