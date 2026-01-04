# Running on Linux - Quick Start Guide

## Building on Linux (Much Easier!)

On Linux, you don't need Visual Studio or any special setup! Just Rust.

### Prerequisites

```bash
# Install Rust (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Restart your terminal or run:
source $HOME/.cargo/env
```

### Clone and Build

```bash
# Clone the repository
git clone https://github.com/ybsa/TorrentsD.git
cd TorrentsD

# Build (release mode for better performance)
cargo build --release

# That's it! No Visual Studio, no SDK needed!
```

### Run the Torrent Client

```bash
# Show help
./target/release/torrent-client --help

# View torrent info
./target/release/torrent-client info path/to/file.torrent

# Download a torrent
./target/release/torrent-client download path/to/file.torrent -o ./downloads
```

### Quick Test

```bash
# Create a test torrent
cargo run --example create_test_torrent

# View the test torrent info
cargo run --release -- info test.torrent
```

## Example: Download a Legal Torrent

```bash
# Download a Debian ISO torrent file first
wget https://cdimage.debian.org/debian-cd/current/amd64/bt-cd/debian-12.4.0-amd64-netinst.iso.torrent

# View torrent info
./target/release/torrent-client info debian-12.4.0-amd64-netinst.iso.torrent

# Download it
./target/release/torrent-client download debian-12.4.0-amd64-netinst.iso.torrent -o ~/Downloads
```

## Troubleshooting

### If you get "cargo: command not found"

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### If you get linker errors

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install build-essential pkg-config libssl-dev

# Fedora/RHEL
sudo dnf install gcc pkg-config openssl-devel

# Arch
sudo pacman -S base-devel openssl
```

## Performance

On Linux, the build will be much faster:

- ✅ No Windows SDK needed
- ✅ No Visual Studio needed  
- ✅ GCC/Clang works out of the box
- ✅ Faster compile times
- ✅ Better performance

## Usage Examples

### View Torrent Information

```bash
$ ./target/release/torrent-client info debian.torrent

Torrent Information
===================
Name: debian-12.4.0-amd64-netinst.iso
Announce URL: http://bttracker.debian.org:6969/announce
Info Hash: a1b2c3d4e5f6...
Total Size: 659554304 bytes (629.00 MB)
Piece Length: 262144 bytes
Number of Pieces: 2516

Files:
  1. debian-12.4.0-amd64-netinst.iso (659554304 bytes)
```

### Download a Torrent

```bash
$ ./target/release/torrent-client download debian.torrent -o ~/Downloads

Loading torrent file: debian.torrent
Torrent: debian-12.4.0-amd64-netinst.iso
Size: 659554304 bytes
Pieces: 2516
Info hash: a1b2c3d4e5f6...

Contacting tracker: http://bttracker.debian.org:6969/announce
Found 47 peers
Tracker interval: 1800 seconds

Starting download to: ~/Downloads
Connecting to peers...
✓ Piece 1/2516 complete
✓ Piece 2/2516 complete
✓ Piece 3/2516 complete
...
✓ Download complete!
```

## All Done

That's it! No complex setup needed on Linux. Just:

1. Install Rust
2. Clone and build
3. Run!

Much simpler than Windows! 🎉
