//! Torrent Core Library
//! 
//! Public API for use by Flutter/external applications.

pub mod bencode;
pub mod torrent;
pub mod tracker;
pub mod peer;
pub mod download;
pub mod storage;

// Re-export main types for easy access
pub use torrent::Metainfo;
pub use tracker::{TrackerRequest, TrackerResponse, announce, generate_peer_id};
pub use download::DownloadManager;
pub use storage::Storage;

/// Download a torrent file to the specified output directory.
/// This is the main entry point for the library.
pub async fn download_torrent(
    torrent_path: &str,
    output_dir: &str,
) -> anyhow::Result<()> {
    use std::sync::Arc;
    
    let metainfo = Metainfo::from_file(torrent_path)?;
    let peer_id = generate_peer_id();
    
    // Create storage
    let storage = Storage::new(output_dir, &metainfo)?;
    
    // Create download manager
    let manager = DownloadManager::new(
        Arc::new(metainfo.clone()),
        Arc::new(std::sync::Mutex::new(storage)),
        peer_id,
    );
    
    // Get initial peers from tracker
    let tracker_request = TrackerRequest {
        info_hash: metainfo.info_hash,
        peer_id,
        port: 6881,
        uploaded: 0,
        downloaded: 0,
        left: metainfo.info.total_length as u64,
    };
    
    let response = announce(&metainfo.announce, &tracker_request).await?;
    
    // Start download
    manager.download_from_peers(response.peers).await?;
    
    Ok(())
}

/// Get information about a torrent file without downloading.
pub fn get_torrent_info(torrent_path: &str) -> anyhow::Result<TorrentInfo> {
    let metainfo = Metainfo::from_file(torrent_path)?;
    
    Ok(TorrentInfo {
        name: metainfo.info.name.clone(),
        total_size: metainfo.info.total_length,
        piece_count: metainfo.info.pieces.len(),
        piece_length: metainfo.info.piece_length,
        files: metainfo.info.files.iter().map(|f| FileInfo {
            path: f.path.join("/"),
            size: f.length,
        }).collect(),
        info_hash: hex::encode(metainfo.info_hash),
        announce: metainfo.announce.clone(),
    })
}

/// Information about a torrent file.
#[derive(Debug, Clone)]
pub struct TorrentInfo {
    pub name: String,
    pub total_size: usize,
    pub piece_count: usize,
    pub piece_length: usize,
    pub files: Vec<FileInfo>,
    pub info_hash: String,
    pub announce: String,
}

/// Information about a file in the torrent.
#[derive(Debug, Clone)]
pub struct FileInfo {
    pub path: String,
    pub size: usize,
}
