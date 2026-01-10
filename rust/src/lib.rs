mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. */
mod api;

use std::sync::Arc;
use tokio::sync::OnceCell;
use librqbit::Session;

static SESSION: OnceCell<Arc<Session>> = OnceCell::const_new();

/// Get or initialize the global librqbit session
/// Tries multiple paths for Android compatibility
pub async fn get_session() -> anyhow::Result<Arc<Session>> {
    // Check if already initialized
    if let Some(session) = SESSION.get() {
        return Ok(session.clone());
    }
    
    use librqbit::SessionOptions;
    
    // Try multiple paths - Android app data, then fallback paths
    let paths_to_try = vec![
        // Android internal app data (typical for BlueStacks/emulators)
        "/data/data/com.example.torrent_app/files/torrent_session".to_string(),
        // Android external storage
        "/storage/emulated/0/Android/data/com.example.torrent_app/files".to_string(),
        // Generic app data path
        "/data/user/0/com.example.torrent_app/files/torrent_session".to_string(),
        // Linux/Desktop fallback
        "/tmp/torrent_dr_session".to_string(),
        // Windows fallback
        std::env::temp_dir().join("torrent_dr_session").to_string_lossy().to_string(),
    ];
    
    let mut last_error: Option<anyhow::Error> = None;
    
    for path in paths_to_try {
        // Options with all persistence disabled for Android compatibility
        let options = SessionOptions {
            disable_dht: false,            // Keep DHT enabled
            disable_dht_persistence: true, // No DHT persistence
            persistence: None,             // No session persistence
            ..Default::default()
        };

        // Try to create directory
        let _ = std::fs::create_dir_all(&path);
        
        match Session::new_with_opts(path.clone().into(), options).await {
            Ok(session) => {
                let _ = SESSION.set(session.clone());
                return Ok(SESSION.get().unwrap().clone());
            }
            Err(e) => {
                last_error = Some(anyhow::anyhow!("Path {} failed: {}", path, e));
                continue;
            }
        }
    }
    
    // All paths failed - return the last error
    Err(last_error.unwrap_or_else(|| anyhow::anyhow!("No valid session path found")))
}

// Re-export types used in Flutter API
pub use api::simple::{TorrentInfo, FileInfo, AppTorrentStatus};
