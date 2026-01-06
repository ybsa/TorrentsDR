mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. */
mod api;

// pub mod torrent; 
// pub mod bencode;
// pub mod download;

// Re-export specific structs if needed, or just let api/simple handle it.
// For now, we will rely on librqbit and api/simple.rs for logic.


use std::sync::Arc;
use tokio::sync::OnceCell;
use librqbit::Session;

static SESSION: OnceCell<Arc<Session>> = OnceCell::const_new();

/// Get or initialize the global librqbit session
pub async fn get_session() -> anyhow::Result<Arc<Session>> {
    // Check if already initialized
    if let Some(session) = SESSION.get() {
        return Ok(session.clone());
    }
    
    // Initialize the session
    let session_dir = std::env::temp_dir().join("torrent_dr_session");
    std::fs::create_dir_all(&session_dir).ok();
    
    // v8 API: Session::new() returns Result<Arc<Session>>
    let session = Session::new(session_dir)
        .await
        .map_err(|e| anyhow::anyhow!("Failed to create session: {}", e))?;
    
    // Try to set it (ignore if already set by another thread)
    let _ = SESSION.set(session.clone());
    
    Ok(SESSION.get().unwrap().clone())
}

// Re-export types used in Flutter API
pub use api::simple::{TorrentInfo, FileInfo, AppTorrentStatus};
