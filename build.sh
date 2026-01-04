#!/bin/bash
# Quick build and run script for Linux

echo "Building torrent client..."
cd ~/Projects/temp/TorrentsD || exit 1

# Pull latest changes
git pull

# Build in release mode
cargo build --release

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "Usage:"
    echo "  Info:     ./target/release/torrent-client info file.torrent"
    echo "  Download: ./target/release/torrent-client download file.torrent -o ~/Downloads"
    echo ""
else
    echo "❌ Build failed!"
    exit 1
fi
