// Quick magnet link tester
use librqbit::{Session, AddTorrent};
use std::env;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args: Vec<String> = env::args().collect();
    
    if args.len() < 2 {
        eprintln!("Usage: magnet_test <magnet_link>");
        return Ok(());
    }
    
    let magnet = &args[1];
    let output = std::env::current_dir()?.join("test_downloads");
    std::fs::create_dir_all(&output)?;
    
    println!("🔗 Testing Magnet Link Backend");
    println!("📦 Magnet: {}", magnet);
    println!();
    
    let session = Session::new(output).await?;
    println!("✅ Session created!");
    
    let handle = match session.add_torrent(AddTorrent::from_url(magnet), None).await? {
        librqbit::AddTorrentResponse::Added(_, h) => h,
        librqbit::AddTorrentResponse::AlreadyManaged(_, h) => h,
        _ => anyhow::bail!("Unexpected response"),
    };
    
    println!("✅ Torrent added! Monitoring for 60 seconds...\n");
    
    for i in 0..30 {
        let stats = handle.stats();
        
        if let Some(live) = &stats.live {
            let peers = live.snapshot.peer_stats.live;
            let progress_mb = stats.progress_bytes / 1_000_000;
            let total_mb = stats.total_bytes / 1_000_000;
            let speed = (live.download_speed.mbps as f64) / 1_000_000.0;
            
            println!("[{:03}s] Peers: {:3} | Progress: {:4} MB / {:4} MB | Speed: {:.2} MB/s", 
                i * 2, peers, progress_mb, total_mb, speed);
        } else {
            println!("[{:03}s] Initializing... (fetching metadata)", i * 2);
        }
        
        tokio::time::sleep(std::time::Duration::from_secs(2)).await;
    }
    
    println!("\n✅ Test completed successfully!");
    Ok(())
}
