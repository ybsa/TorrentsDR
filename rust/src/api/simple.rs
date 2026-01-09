use crate::frb_generated::StreamSink;
use crate::get_session;
use librqbit::{AddTorrent, AddTorrentOptions};
use std::time::Duration;

/// Initialize the Rust library (called once at app startup)
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[derive(Debug, Clone)]
#[flutter_rust_bridge::frb(serialize)]
pub struct AppTorrentStatus {
    pub total_pieces: u32,
    pub completed_pieces: u32,
    pub peers: u32,
    pub speed_mbps: f64,
    pub downloading: bool,
    pub is_fetching_metadata: bool,
    pub status_message: String,
    pub error: Option<String>,
    pub total_bytes: u64,      // Total size in bytes
    pub downloaded_bytes: u64, // Downloaded so far in bytes
}

#[derive(Debug, Clone)]
#[flutter_rust_bridge::frb(serialize)]
pub struct TorrentInfo {
    pub name: String,
    pub total_size: usize,
    pub piece_count: usize,
    pub piece_length: usize,
    pub files: Vec<FileInfo>,
    pub info_hash: String,
    pub announce: String,
}

#[derive(Debug, Clone)]
#[flutter_rust_bridge::frb(serialize)]
pub struct FileInfo {
    pub path: String,
    pub size: usize,
}

#[derive(Debug, Clone)]
#[flutter_rust_bridge::frb(serialize)]
pub struct MagnetInfo {
    pub url: String,
    pub info_hash: String,
    pub name: Option<String>,
    pub trackers: Vec<String>,
}

pub fn parse_magnet(uri: String) -> anyhow::Result<MagnetInfo> {
    // Rudimentary Parsing - sufficient for now
    let url = url::Url::parse(&uri).map_err(|e| anyhow::anyhow!(e))?;
    if url.scheme() != "magnet" {
        return Err(anyhow::anyhow!("Not a magnet link"));
    }
    
    let mut info_hash = String::new();
    let mut name = None;
    let mut trackers = Vec::new();
    
    for (key, value) in url.query_pairs() {
        match key.as_ref() {
            "xt" => {
                if value.starts_with("urn:btih:") {
                   info_hash = value.strip_prefix("urn:btih:").unwrap().to_string();
                }
            },
            "dn" => name = Some(value.to_string()),
            "tr" => trackers.push(value.to_string()),
            _ => {}
        }
    }
    
    if info_hash.is_empty() {
        return Err(anyhow::anyhow!("No info hash found"));
    }
    
    Ok(MagnetInfo {
        url: uri,
        info_hash,
        name,
        trackers
    })
}


pub async fn get_torrent_info_file(path: String) -> anyhow::Result<TorrentInfo> {
    let session = get_session().await?;
    let bytes = std::fs::read(&path)?;
    
    // Add torrent paused to inspect metadata
    let add_result = session.add_torrent(
        AddTorrent::from_bytes(bytes),
        Some(AddTorrentOptions {
            paused: true,
            overwrite: true,
            ..Default::default()
        })
    ).await?;
    
    let handle = add_result.into_handle()
        .ok_or(anyhow::anyhow!("Failed to create torrent handle"))?;
        
    // For a local .torrent file, metadata should be available immediately
    let stats = handle.stats();
    
    // Build info structure (simplified for v8)
    let result = TorrentInfo {
        name: "Local Torrent".to_string(), // TODO: extract name from bytes if needed, or use filename
        total_size: stats.total_bytes as usize,
        piece_count: 0,
        piece_length: 0,
        files: vec![FileInfo {
            path: "content".to_string(),
            size: stats.total_bytes as usize,
        }],
        info_hash: format!("{:?}", handle.id()),
        announce: String::new(),
    };
    
    // Clean up
    let _ = session.delete(librqbit::api::TorrentIdOrHash::Id(handle.id()), false).await;
    
    Ok(result)
}

pub async fn start_download(
    source: String,
    output_dir: String,
    stream_sink: StreamSink<AppTorrentStatus>,
    _selected_file_indices: Option<Vec<usize>>, // Ignored for now
) -> anyhow::Result<()> {
    let session = get_session().await?;
    
    let add_torrent = if source.starts_with("magnet:") {
        AddTorrent::from_url(&source)
    } else {
        // Assume file path
        let bytes = std::fs::read(&source)?;
        AddTorrent::from_bytes(bytes)
    };
    
    // Starting download for source
    
    // Try to add torrent - librqbit v8 handles duplicates with overwrite option
    let add_result = session.add_torrent(
        add_torrent,
        Some(AddTorrentOptions {
            output_folder: Some(output_dir.into()),
            overwrite: true, // This should handle existing torrents
            ..Default::default()
        })
    ).await;
    
    // Get the handle - either from new add or handle error for existing
    let handle = match add_result {
        Ok(managed) => {
            managed.into_handle().ok_or(anyhow::anyhow!("Failed to create torrent handle"))?
        },
        Err(e) => {
            // If add failed, try to find existing torrent in session
            // Add failed, looking for existing torrent
            
            // Find existing torrent by iterating through session
            use std::cell::RefCell;
            let found_handle: RefCell<Option<_>> = RefCell::new(None);
            session.with_torrents(|torrents| {
                for (_, handle) in torrents {
                    // Just get the first active one for now
                    // In production, match by info_hash
                    *found_handle.borrow_mut() = Some(handle.clone());
                    break;
                }
            });
            
            found_handle.into_inner().ok_or(anyhow::anyhow!("Torrent not found in session: {}", e))?
        }
    };
    
    // Status Loop
    loop {
        let stats = handle.stats();
        
        // v8 API: check if we have metadata
        let has_metadata = stats.total_bytes > 0;
        let is_fetching_metadata = !has_metadata;
        
        // Calculate total pieces from total bytes / piece length (estimate)
        let total_pieces = if stats.total_bytes > 0 {
            ((stats.total_bytes as f64 / 16384.0).ceil()) as u32 // Assume 16KB pieces
        } else {
            0
        };
        
        // v8: Calculate completed pieces from progress_bytes
        let completed = if stats.total_bytes > 0 {
            ((stats.progress_bytes as f64 / 16384.0).floor()) as u32
        } else {
            0
        };
        
        // v8 API: peer count from snapshot if live stats available
        let peer_count = if let Some(live) = &stats.live {
            live.snapshot.peer_stats.live as u32
        } else {
            0
        };
        
        let status_message = if is_fetching_metadata {
            format!("Fetching Metadata... ({} peers)", peer_count)
        } else if stats.progress_bytes >= stats.total_bytes && stats.total_bytes > 0 {
            "Complete".to_string()
        } else if peer_count == 0 {
            "Searching for peers...".to_string()
        } else {
            format!("Downloading ({} peers)", peer_count)
        };
        
        // v8: download_speed.mbps is already in megabits/sec, convert to MB/s
        // 1 Mbps = 0.125 MB/s (divide by 8)
        let speed_mbps = if let Some(live) = &stats.live {
            live.download_speed.mbps as f64 / 8.0
        } else {
            0.0
        };
        
        let status = AppTorrentStatus {
            total_pieces,
            completed_pieces: completed,
            peers: peer_count,
            speed_mbps,
            downloading: !is_fetching_metadata && stats.progress_bytes < stats.total_bytes,
            is_fetching_metadata,
            status_message,
            error: None,
            total_bytes: stats.total_bytes,
            downloaded_bytes: stats.progress_bytes,
        };
        
        if stream_sink.add(status).is_err() {
            // Stream closed by UI
            break;
        }
        
        // v8: Check if download is complete
        if stats.progress_bytes >= stats.total_bytes && stats.total_bytes > 0 {
            break;
        }
        
        tokio::time::sleep(Duration::from_secs(1)).await;
    }
    
    Ok(())
}

pub async fn fetch_magnet_metadata(
    magnet_uri: String,
    timeout_secs: u32,
) -> anyhow::Result<TorrentInfo> {
    let session = get_session().await?;
    
    // Add torrent in paused state to just fetch metadata
    let add_result = session.add_torrent(
        AddTorrent::from_url(&magnet_uri),
        Some(AddTorrentOptions {
            paused: true, // Don't start downloading
            overwrite: true,
            ..Default::default()
        })
    ).await?;
    
    let handle = add_result.into_handle()
        .ok_or(anyhow::anyhow!("Failed to create torrent handle"))?;
    
    // Wait for metadata with timeout
    let deadline = tokio::time::Instant::now() + Duration::from_secs(timeout_secs as u64);
    
    loop {
        if tokio::time::Instant::now() > deadline {
            // Timeout - remove the torrent and fail
            let _ = session.delete(librqbit::api::TorrentIdOrHash::Id(handle.id()), false).await;
            return Err(anyhow::anyhow!("Timeout waiting for metadata"));
        }
        
        // v8: Check if we have metadata (stats.total_bytes > 0 means metadata loaded)
        let stats = handle.stats();
        if stats.total_bytes > 0 {
            // We have metadata! Build TorrentInfo
            // Note: In v8, we can't easily access the full torrent info structure
            // So we'll use a simplified approach with stats
            
            let result = TorrentInfo {
                name: "Downloaded Content".to_string(), // v8 limitation: can't easily get name from stats
                total_size: stats.total_bytes as usize,
                piece_count: 0, // v8: Can't easily get piece count
                piece_length: 0, // v8: Can't easily get piece length  
                files: vec![FileInfo {
                    path: "content".to_string(),
                    size: stats.total_bytes as usize,
                }],
                info_hash: format!("{:?}", handle.id()), // v8: Use torrent ID as hash
                announce: String::new(),
            };
            
            // Remove the torrent (we'll re-add it when user confirms)
            let _ = session.delete(librqbit::api::TorrentIdOrHash::Id(handle.id()), false).await;
            
            return Ok(result);
        }
        
        // v8: Log peer count for debugging
        let peer_count = if let Some(live) = &stats.live {
            live.snapshot.peer_stats.live
        } else {
            0
        };
        println!("PREVIEW: Waiting for metadata... {} peers connected, {} bytes", peer_count, stats.total_bytes);
        
        tokio::time::sleep(Duration::from_millis(500)).await;
    }
}

pub async fn get_torrents() -> anyhow::Result<Vec<AppTorrentStatus>> {
    let session = get_session().await?;
    let handles = session.with_torrents(|iter| {
        iter.map(|(_, handle)| handle.clone()).collect::<Vec<_>>()
    });
    let mut results = Vec::new();
    
    for handle in handles {
        let stats = handle.stats();
        
        let has_metadata = stats.total_bytes > 0;
        let is_fetching_metadata = !has_metadata;
        
        // Calculate total pieces from total bytes / piece length (estimate)
        let total_pieces = if stats.total_bytes > 0 {
            ((stats.total_bytes as f64 / 16384.0).ceil()) as u32 // Assume 16KB pieces
        } else {
            0
        };
        
        // v8: Calculate completed pieces from progress_bytes
        let completed = if stats.total_bytes > 0 {
            ((stats.progress_bytes as f64 / 16384.0).floor()) as u32
        } else {
            0
        };
        
        // v8 API: peer count from snapshot if live stats available
        let peer_count = if let Some(live) = &stats.live {
            live.snapshot.peer_stats.live as u32
        } else {
            0
        };
        
        // Check if finished
        let is_finished = stats.progress_bytes >= stats.total_bytes && stats.total_bytes > 0;
        let is_paused = handle.is_paused();

        let status_message = if is_fetching_metadata {
            format!("Fetching Metadata... ({} peers)", peer_count)
        } else if is_finished {
            "Complete".to_string()
        } else if is_paused {
            "Paused".to_string()
        } else if peer_count == 0 {
            "Searching for peers...".to_string()
        } else {
            format!("Downloading ({} peers)", peer_count)
        };
        
        // v8: download_speed.mbps is megabits/sec, convert to MB/s
        let speed_mbps = if let Some(live) = &stats.live {
            live.download_speed.mbps as f64 / 8.0
        } else {
            0.0
        };
        
        results.push(AppTorrentStatus {
            total_pieces,
            completed_pieces: completed,
            peers: peer_count,
            speed_mbps,
            downloading: !is_fetching_metadata && !is_finished && !is_paused,
            is_fetching_metadata,
            status_message,
            error: None,
            total_bytes: stats.total_bytes,
            downloaded_bytes: stats.progress_bytes,
        });
    }
    
    Ok(results)
}
