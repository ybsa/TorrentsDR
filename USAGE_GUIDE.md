# How to Download Torrents - Complete Guide

## Quick Overview

Your torrent client works like this:

1. Get a `.torrent` file
2. Run: `torrent-client download file.torrent`
3. The client downloads the files for you!

---

## Step-by-Step Tutorial

### Step 1: Build the Client

**On Linux:**

```bash
git clone https://github.com/ybsa/TorrentsD.git
cd TorrentsD
cargo build --release
```

**On Windows (after Visual Studio setup):**

```powershell
git clone https://github.com/ybsa/TorrentsD.git
cd TorrentsD
cargo build --release
```

### Step 2: Get a Torrent File

You need a `.torrent` file first. Here are some legal sources:

**Option A: Download a Linux ISO (Legal & Common)**

```bash
# Ubuntu Desktop
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.3-desktop-amd64.iso.torrent

# Debian
wget https://cdimage.debian.org/debian-cd/current/amd64/bt-cd/debian-12.4.0-amd64-netinst.iso.torrent

# Any Linux distro from their official website
```

**Option B: Use Any Torrent Website**

- Go to any torrent site
- Download the `.torrent` file (not magnet link - we don't support those yet)
- Save it to your computer

### Step 3: View Torrent Information (Optional)

Before downloading, check what's in the torrent:

```bash
./target/release/torrent-client info ubuntu.torrent
```

**Example output:**

```
Torrent Information
===================
Name: ubuntu-22.04.3-desktop-amd64.iso
Announce URL: https://torrent.ubuntu.com/announce
Info Hash: abc123def456...
Total Size: 4900000000 bytes (4.56 GB)
Piece Length: 524288 bytes
Number of Pieces: 9346

Files:
  1. ubuntu-22.04.3-desktop-amd64.iso (4900000000 bytes)
```

### Step 4: Download the Torrent

**Basic download (to current directory):**

```bash
./target/release/torrent-client download ubuntu.torrent
```

**Download to specific folder:**

```bash
./target/release/torrent-client download ubuntu.torrent -o ~/Downloads
```

**What happens:**

1. ✅ Client reads the `.torrent` file
2. ✅ Contacts the tracker to find peers
3. ✅ Connects to peers (up to 5 simultaneously)
4. ✅ Downloads pieces and verifies them with SHA-1
5. ✅ Assembles the final file(s)
6. ✅ Shows progress as it downloads

**Example output during download:**

```
Loading torrent file: ubuntu.torrent
Torrent: ubuntu-22.04.3-desktop-amd64.iso
Size: 4900000000 bytes
Pieces: 9346
Info hash: abc123def456...

Contacting tracker: https://torrent.ubuntu.com/announce
Found 52 peers
Tracker interval: 1800 seconds

Starting download to: ./downloads
Connecting to peers...
✓ Piece 1/9346 complete
✓ Piece 2/9346 complete
✓ Piece 3/9346 complete
✓ Piece 4/9346 complete
...
✓ Piece 9346/9346 complete

✓ Download complete!
```

---

## Complete Examples

### Example 1: Download Ubuntu ISO

```bash
# 1. Get the torrent file
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.3-desktop-amd64.iso.torrent

# 2. Check info (optional)
./target/release/torrent-client info ubuntu-22.04.3-desktop-amd64.iso.torrent

# 3. Download it
./target/release/torrent-client download ubuntu-22.04.3-desktop-amd64.iso.torrent -o ~/Downloads

# 4. The ISO will be saved in ~/Downloads/ubuntu-22.04.3-desktop-amd64.iso
```

### Example 2: Download Any Torrent

```bash
# 1. You have a torrent file: movie.torrent

# 2. View what's inside
./target/release/torrent-client info movie.torrent

# 3. Download it to a specific folder
./target/release/torrent-client download movie.torrent -o ~/Videos

# 4. Files will be saved in ~/Videos/
```

### Example 3: Create and Test with Test Torrent

```bash
# 1. Create a test torrent
cargo run --example create_test_torrent

# 2. This creates:
#    - test.torrent (the torrent file)
#    - test_file.txt (the actual file)

# 3. View the test torrent
./target/release/torrent-client info test.torrent

# 4. Download it (just for testing)
./target/release/torrent-client download test.torrent -o ./test_downloads

# Note: This won't actually download from peers since it's a local test,
# but it shows the client works!
```

---

## Command Reference

### View Torrent Info

```bash
torrent-client info <torrent-file>

# Example
torrent-client info example.torrent
```

**Shows:**

- Torrent name
- Tracker URL
- Info hash (unique ID)
- Total size
- Number of pieces
- List of files

### Download Torrent

```bash
torrent-client download <torrent-file> [options]

# Basic
torrent-client download file.torrent

# Specify output directory
torrent-client download file.torrent -o ~/Downloads

# Short form
torrent-client download file.torrent --output ./downloads
```

**Options:**

- `-o, --output <DIR>` - Output directory (default: `./downloads`)
- `-p, --port <PORT>` - Port to listen on (default: `6881`)

### Show Help

```bash
torrent-client --help
```

---

## What You Need

### Required

1. ✅ A `.torrent` file
2. ✅ Internet connection
3. ✅ Working tracker URL in the torrent
4. ✅ Available peers

### NOT Supported Yet

- ❌ Magnet links (need DHT)
- ❌ Seeding/uploading
- ❌ UDP trackers (only HTTP/HTTPS)

---

## Finding Torrent Files

### Legal Sources

1. **Linux Distributions** - Ubuntu, Debian, Fedora, etc.
2. **Open Source Software** - Many projects distribute via torrents
3. **Public Domain Content** - Archive.org, Internet Archive
4. **Creative Commons** - Music, videos with CC licenses

### How to Get `.torrent` Files

- Look for "Download via BitTorrent" or torrent icon
- Click it and save the `.torrent` file
- **Don't** use magnet links (they start with `magnet:?`)

---

## Troubleshooting

### "No peers available"

**Problem:** Tracker returned 0 peers  
**Solutions:**

- Try a different, more popular torrent
- Check if the tracker URL is still active
- Make sure you're connected to the internet

### "Failed to contact tracker"

**Problem:** Can't reach the tracker  
**Solutions:**

- Check internet connection
- Tracker might be down - try a different torrent
- Some trackers block certain IPs

### Download is slow

**Possible reasons:**

- Few peers available
- Slow peers
- Your internet connection speed
- The torrent is old/unpopular

---

## Real-World Usage

### Download Ubuntu (4.5 GB ISO)

```bash
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.3-desktop-amd64.iso.torrent
./target/release/torrent-client download ubuntu-22.04.3-desktop-amd64.iso.torrent -o ~/Downloads
# Wait 10-30 minutes depending on your connection
```

### Download Smaller Files First

```bash
# Try Debian netinst (smaller, ~600 MB)
wget https://cdimage.debian.org/debian-cd/current/amd64/bt-cd/debian-12.4.0-amd64-netinst.iso.torrent
./target/release/torrent-client download debian-12.4.0-amd64-netinst.iso.torrent
```

---

## Summary

**Three simple steps:**

1. **Get a `.torrent` file** → Download from torrent site or Linux distro
2. **Run the command** → `torrent-client download file.torrent`
3. **Wait for download** → Client does everything automatically!

The client will:

- ✅ Contact the tracker
- ✅ Find peers
- ✅ Download pieces
- ✅ Verify integrity
- ✅ Save files

**That's it!** Your BitTorrent client is fully automated! 🚀
