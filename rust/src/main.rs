use clap::{Parser, Subcommand};
use anyhow::{Result, Context};
use std::path::PathBuf;
use torrent_client::{Metainfo, download::DownloadManager, tracker};

#[derive(Parser)]
#[command(name = "torrent-client")]
#[command(about = "A simple BitTorrent client", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Download a torrent file
    Download {
        /// Path to the .torrent file
        torrent_file: PathBuf,
        
        /// Output directory for downloaded files
        #[arg(short, long, default_value = "./downloads")]
        output: String,
        
        /// Port to listen on
        #[arg(short, long, default_value = "6881")]
        port: u16,
    },
    
    /// Show information about a torrent file
    Info {
        /// Path to the .torrent file
        torrent_file: PathBuf,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    
    match cli.command {
        Commands::Download { torrent_file, output, port } => {
            download_torrent(torrent_file, &output, port).await?;
        }
        Commands::Info { torrent_file } => {
            show_info(torrent_file)?;
        }
    }
    
    Ok(())
}

async fn download_torrent(torrent_path: PathBuf, output_dir: &str, port: u16) -> Result<()> {
    println!("Loading torrent file: {:?}", torrent_path);
    let metainfo = Metainfo::from_file(&torrent_path)
        .context("Failed to load torrent file")?;
    
    println!("Torrent: {}", metainfo.info.name);
    println!("Size: {} bytes", metainfo.info.total_length);
    println!("Pieces: {}", metainfo.num_pieces());
    println!("Info hash: {}", metainfo.info_hash_hex());
    println!();
    
    // Generate peer ID
    let peer_id = tracker::generate_peer_id();
    
    // Contact tracker
    println!("Contacting tracker: {}", metainfo.announce);
    let tracker_request = tracker::TrackerRequest {
        info_hash: metainfo.info_hash,
        peer_id,
        port,
        uploaded: 0,
        downloaded: 0,
        left: metainfo.info.total_length as u64,
    };
    
    let tracker_response = tracker::announce(&metainfo.announce, &tracker_request)
        .await
        .context("Failed to contact tracker")?;
    
    println!("Found {} peers", tracker_response.peers.len());
    println!("Tracker interval: {} seconds", tracker_response.interval);
    println!();
    
    if tracker_response.peers.is_empty() {
        println!("No peers available. Cannot download.");
        return Ok(());
    }
    
    // Initialize download manager
    println!("Starting download to: {}", output_dir);
    let manager = DownloadManager::new(metainfo, output_dir, peer_id)?;
    
    // Start download
    println!("Connecting to peers...");
    manager.download_from_peers(tracker_response.peers).await?;
    
    println!("\n✓ Download complete!");
    
    Ok(())
}

fn show_info(torrent_path: PathBuf) -> Result<()> {
    let metainfo = Metainfo::from_file(&torrent_path)
        .context("Failed to load torrent file")?;
    
    println!("Torrent Information");
    println!("===================");
    println!("Name: {}", metainfo.info.name);
    println!("Announce URL: {}", metainfo.announce);
    println!("Info Hash: {}", metainfo.info_hash_hex());
    println!("Total Size: {} bytes ({:.2} MB)", 
        metainfo.info.total_length,
        metainfo.info.total_length as f64 / 1_048_576.0);
    println!("Piece Length: {} bytes", metainfo.info.piece_length);
    println!("Number of Pieces: {}", metainfo.num_pieces());
    println!();
    
    println!("Files:");
    for (i, file) in metainfo.info.files.iter().enumerate() {
        println!("  {}. {} ({} bytes)", 
            i + 1,
            file.path.join("/"),
            file.length);
    }
    
    Ok(())
}
