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

Install Rust with rustup and the native build prerequisites:

```sh
sudo apt update
sudo apt install build-essential clang
```

Install Texo 0.1.2 with the released `fabricaup` installer:

```sh
curl --proto '=https' --tlsv1.2 -sSf \
  https://raw.githubusercontent.com/fabrica-eda/fabricaup/main/install.sh | \
  FABRICAUP_INIT_SKIP=1 sh
export PATH="$HOME/.fabrica/bin:$PATH"
fabricaup install v0.1.2
```

Run the complete flow:

```sh
./build.sh
```

This fetches Texo's verified ECP5 target pack, runs RTL simulation, Struo
synthesis and mapping, Celox post-map simulation, then uses Texo 0.1.2 for
place-and-route and native ECP5 bitstream generation. The SRAM bitstream is
written to `blinky/build/Top.bit`.

Generated files stay under `blinky/build/` and are not committed. Programming
from WSL2 with `openFPGALoader` is documented in
[blinky/README.md](blinky/README.md).
