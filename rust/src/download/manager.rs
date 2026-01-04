use anyhow::{Result, Context};
use tokio::sync::mpsc;
use std::sync::{Arc, Mutex};
use std::net::SocketAddr;
use crate::torrent::Metainfo;
use crate::peer::{PeerConnection, Message};
use crate::storage::Storage;
use super::piece::Piece;

pub struct DownloadManager {
    metainfo: Arc<Metainfo>,
    pieces: Arc<Mutex<Vec<Piece>>>,
    storage: Arc<Mutex<Storage>>,
    peer_id: [u8; 20],
}

impl DownloadManager {
    pub fn new(metainfo: Metainfo, output_dir: &str, peer_id: [u8; 20]) -> Result<Self> {
        let num_pieces = metainfo.num_pieces();
        let piece_length = metainfo.info.piece_length;
        let total_length = metainfo.info.total_length;
        
        let mut pieces = Vec::with_capacity(num_pieces);
        for i in 0..num_pieces {
            let length = if i == num_pieces - 1 {
                // Last piece might be smaller
                total_length - (i * piece_length)
            } else {
                piece_length
            };
            
            let hash = *metainfo.piece_hash(i).unwrap();
            pieces.push(Piece::new(i, length, hash));
        }
        
        let storage = Storage::new(&metainfo, output_dir)?;
        
        Ok(DownloadManager {
            metainfo: Arc::new(metainfo),
            pieces: Arc::new(Mutex::new(pieces)),
            storage: Arc::new(Mutex::new(storage)),
            peer_id,
        })
    }
    
    pub async fn download_from_peers(&self, initial_peers: Vec<SocketAddr>) -> Result<()> {
        let (tx, mut rx) = mpsc::channel(500); // Increased buffer
        
        let active_peers = Arc::new(std::sync::atomic::AtomicUsize::new(0));
        let peers_queue = Arc::new(Mutex::new(std::collections::VecDeque::from(initial_peers.clone())));
        
        // Track known peers to avoid duplicates from re-announces
        let known_peers = Arc::new(Mutex::new(std::collections::HashSet::new()));
        {
            let mut known = known_peers.lock().unwrap();
            for peer in &initial_peers {
                known.insert(*peer);
            }
        }

        // Peer Manager Task - Keeps connections alive
        let manager_active_peers = active_peers.clone();
        let manager_metainfo = self.metainfo.clone();
        let manager_pieces = self.pieces.clone();
        let manager_peer_id = self.peer_id;
        let manager_tx = tx.clone();
        let manager_queue = peers_queue.clone();
        let manager_total_peers = Arc::new(std::sync::atomic::AtomicUsize::new(initial_peers.len()));
        
        // ----------------------------------------------------------------
        // 1. TRACKER RE-ANNOUNCE LOOP (Dynamic Discovery)
        // ----------------------------------------------------------------
        let tracker_url = self.metainfo.announce.clone();
        let tracker_info_hash = self.metainfo.info_hash;
        let tracker_peer_id = self.peer_id;
        let tracker_queue = peers_queue.clone();
        let tracker_known = known_peers.clone();
        let tracker_total_peers = manager_total_peers.clone();
        let tracker_pieces = self.pieces.clone();
        let tracker_active = active_peers.clone();
        let total_size = self.metainfo.info.total_length; // Assuming single file or sum
        
        tokio::spawn(async move {
            use crate::tracker::{announce, TrackerRequest};
            
            // Wait 10 seconds before first re-announce (we already have initial peers)
            tokio::time::sleep(std::time::Duration::from_secs(10)).await;
            
            loop {
                let current_active = tracker_active.load(std::sync::atomic::Ordering::Relaxed);
                
                // Adaptive Interval: Aggressive Peer Discovery
                // User Request: 45 seconds to be safe from bans but still fast.
                let interval = if current_active < 50 {
                    std::time::Duration::from_secs(45) // User requested 45s
                } else {
                    std::time::Duration::from_secs(300) // Maintenance every 5 mins
                };
                
                println!("Creating tracker re-announce request... (Active: {})", current_active);
                tokio::time::sleep(interval).await;
                
                // Calculate progress
                let (downloaded, left) = {
                     let pieces = tracker_pieces.lock().unwrap();
                     let completed = pieces.iter().filter(|p| p.is_complete()).count();
                     let d = (completed * 16384) as u64; // Approximation
                     let l = if (total_size as u64) > d { (total_size as u64) - d } else { 0 };
                     (d, l)
                };

                let req = TrackerRequest {
                    info_hash: tracker_info_hash,
                    peer_id: tracker_peer_id,
                    port: 6881,
                    uploaded: 0, // TODO: track upload
                    downloaded,
                    left,
                };
                
                match announce(&tracker_url, &req).await {
                    Ok(response) => {
                        let mut known = tracker_known.lock().unwrap();
                        let mut queue = tracker_queue.lock().unwrap();
                        let mut new_count = 0;
                        
                        for peer in response.peers {
                            if !known.contains(&peer) {
                                known.insert(peer);
                                queue.push_back(peer);
                                new_count += 1;
                            }
                        }
                        
                        // Update total count
                        let old_total = tracker_total_peers.fetch_add(new_count, std::sync::atomic::Ordering::Relaxed);
                        if new_count > 0 {
                            println!("Tracker found {} NEW peers! (Total known: {})", new_count, old_total + new_count);
                        }
                    },
                    Err(e) => {
                        println!("Tracker re-announce failed: {}", e);
                    }
                }
            }
        });

        // ----------------------------------------------------------------
        // 2. CONNECTION MANAGER LOOP (Dynamic Scaling)
        // ----------------------------------------------------------------
        let mgr_total_peers_limit = manager_total_peers.clone();
        
        tokio::spawn(async move {
            loop {
                let current_active = manager_active_peers.load(std::sync::atomic::Ordering::Relaxed);
                
                // Target 200 connections! Use EVERYTHING available.
                if current_active < 200 {
                    let next_peer = {
                        let mut queue = manager_queue.lock().unwrap();
                        queue.pop_front()
                    };
                    
                    if let Some(peer_addr) = next_peer {
                        let active_counter = manager_active_peers.clone();
                        let m_metainfo = manager_metainfo.clone();
                        let m_pieces = manager_pieces.clone();
                        let m_tx = manager_tx.clone();
                        let m_queue = manager_queue.clone();
                        let m_peer_id = manager_peer_id;
                        let m_total_peers_atom = manager_total_peers.clone();
                        
                        tokio::spawn(async move {
                            active_counter.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                            
                            // Try to download
                            let result = download_from_peer(peer_addr, m_metainfo, m_pieces, m_peer_id, m_tx).await;
                            
                            active_counter.fetch_sub(1, std::sync::atomic::Ordering::Relaxed);
                            
                            // If peer was valid but disconnected, add back to queue
                            // Adaptive retry uses DYNAMIC total peer count
                            let current_active = active_counter.load(std::sync::atomic::Ordering::Relaxed);
                            let current_total_known = m_total_peers_atom.load(std::sync::atomic::Ordering::Relaxed);
                            
                            let retry_delay = if current_active < 10 && current_total_known > 15 {
                                std::time::Duration::from_secs(1) // Desperate mode: 1s (only if large swarm)
                            } else {
                                std::time::Duration::from_secs(5) // Normal mode: 5s (polite)
                            };
                            
                            tokio::time::sleep(retry_delay).await;
                            {
                                let mut queue = m_queue.lock().unwrap();
                                queue.push_back(peer_addr);
                            }
                        });
                    } else {
                        // Queue empty, wait a bit
                        tokio::time::sleep(std::time::Duration::from_secs(1)).await;
                    }
                } else {
                    // Max connections reached, wait
                    tokio::time::sleep(std::time::Duration::from_secs(1)).await;
                }
            }
        });

        // Track download speed
        let start_time = std::time::Instant::now();
        let mut downloaded_bytes = 0u64;
        let mut last_report = std::time::Instant::now();
        
        println!("Connecting to peers... (Found {})", initial_peers.len());
        
        // Collect completed pieces
        while let Some((piece_index, data)) = rx.recv().await {
            let mut storage = self.storage.lock().unwrap();
            storage.write_piece(piece_index, &data)
                .context("Failed to write piece")?;
            
            downloaded_bytes += data.len() as u64;
            
            // Report progress every 1 second for faster feedback
            if last_report.elapsed().as_secs() >= 1 {
                let (complete, total) = self.progress();
                let elapsed = start_time.elapsed().as_secs_f64();
                let speed_mbps = (downloaded_bytes as f64 / elapsed) / 1_048_576.0;
                let progress_pct = (complete as f64 / total as f64) * 100.0;
                let active = active_peers.load(std::sync::atomic::Ordering::Relaxed);
                
                println!("✓ Progress: {}/{} pieces ({:.1}%) | Speed: {:.2} MB/s | Active Peers: {} | Downloaded: {:.2} MB",
                    complete, total, progress_pct,
                    speed_mbps, active, downloaded_bytes as f64 / 1_048_576.0);
                
                last_report = std::time::Instant::now();
            }
        }
        
        // CRITICAL: Verify all pieces are actually downloaded
        let (complete, total) = self.progress();
        if complete < total {
            println!("\n⚠ WARNING: Download incomplete! Only {}/{} pieces downloaded", complete, total);
            println!("Some peers may have disconnected. Try downloading again.");
            anyhow::bail!("Download incomplete: {}/{} pieces", complete, total);
        }
        
        // Final summary
        let elapsed = start_time.elapsed().as_secs_f64();
        let avg_speed = (downloaded_bytes as f64 / elapsed) / 1_048_576.0;
        println!("\n✓ Download complete!");
        println!("Total downloaded: {:.2} MB in {:.1}s", 
            downloaded_bytes as f64 / 1_048_576.0, elapsed);
        println!("Average speed: {:.2} MB/s", avg_speed);
        println!("All {} pieces verified and saved!", total);
        
        Ok(())
    }
    
    pub fn is_complete(&self) -> bool {
        let pieces = self.pieces.lock().unwrap();
        pieces.iter().all(|p| p.is_complete())
    }
    
    pub fn progress(&self) -> (usize, usize) {
        let pieces = self.pieces.lock().unwrap();
        let complete = pieces.iter().filter(|p| p.is_complete()).count();
        (complete, pieces.len())
    }
}

async fn download_from_peer(
    peer_addr: SocketAddr,
    metainfo: Arc<Metainfo>,
    pieces: Arc<Mutex<Vec<Piece>>>,
    peer_id: [u8; 20],
    tx: mpsc::Sender<(usize, Vec<u8>)>,
) -> Result<()> {
    // Add timeout for slow peers - increased to 30s to avoid dropping good peers
    let connect_result = tokio::time::timeout(
        std::time::Duration::from_secs(30),
        PeerConnection::connect(peer_addr, &metainfo.info_hash, &peer_id)
    ).await;
    
    let mut conn = match connect_result {
        Ok(Ok(c)) => c,
        _ => return Ok(()), // Skip slow/failed peers
    };
    
    // Wait for bitfield or first message
    let _ = conn.receive_message().await?;
    
    // Send interested
    conn.send_interested().await?;
    
    // Wait for unchoke with longer timeout - peers may be slow to respond
    let unchoke_result = tokio::time::timeout(
        std::time::Duration::from_secs(30),
        async {
            loop {
                if let Some(msg) = conn.receive_message().await? {
                    if matches!(msg, Message::Unchoke) {
                        break;
                    }
                } else {
                    return Err(anyhow::anyhow!("Connection closed"));
                }
            }
            Ok::<(), anyhow::Error>(())
        }
    ).await;
    
    if unchoke_result.is_err() {
        return Ok(()); // Skip peers that don't unchoke
    }
    
    // Download pieces
    // let mut pieces_downloaded = 0usize; // Unused
    loop {
        // SEQUENTIAL download with FIRST and LAST piece priority (great for video streaming!)
        let piece_to_download = {
            let mut pieces_guard = pieces.lock().unwrap();
            let total_pieces = pieces_guard.len();
            
            // Priority 1: First piece (for video preview)
            if !pieces_guard[0].is_complete() && !pieces_guard[0].in_progress && conn.has_piece(0) {
                pieces_guard[0].in_progress = true;
                let p = &pieces_guard[0];
                Some((p.index, p.length, p.hash))
            }
            // Priority 2: Last piece (for video duration info)
            else if total_pieces > 1 && !pieces_guard[total_pieces - 1].is_complete() && 
                    !pieces_guard[total_pieces - 1].in_progress && conn.has_piece(total_pieces - 1) {
                pieces_guard[total_pieces - 1].in_progress = true;
                let p = &pieces_guard[total_pieces - 1];
                Some((p.index, p.length, p.hash))
            }
            // Priority 3: Sequential from beginning
            else {
                pieces_guard.iter_mut()
                    .find(|p| !p.is_complete() && !p.in_progress && conn.has_piece(p.index))
                    .map(|p| {
                        p.in_progress = true;
                        (p.index, p.length, p.hash)
                    })
            }
        };
        
        if let Some((piece_index, piece_length, piece_hash)) = piece_to_download {
            // Download this piece with adaptive pipelining
            let mut piece = Piece::new(piece_index, piece_length, piece_hash);
            
            // Adaptive Pipeline: Start small, grow if peer is fast!
            // Range: 1 (safe) to 20 (stable max)
            let mut pipeline_size: usize = 3; 
            let mut pending_requests = 0;
            let mut fast_streak = 0;
            
            // Pipeline requests
            while !piece.is_complete() {
                // Send requests up to pipeline size - BUT ONLY IF NOT CHOKED
                while !conn.is_choking() && pending_requests < pipeline_size {
                    if let Some((begin, length)) = piece.next_block_to_request() {
                        match conn.request_piece(piece_index as u32, begin as u32, length as u32).await {
                            Ok(_) => pending_requests += 1,
                            Err(_) => break, // If request fails (e.g. choked mid-loop), stop requesting
                        }
                    } else {
                        break;
                    }
                }
                
                // Measure response time for adaptive scaling
                let request_start = std::time::Instant::now();
                
                // Wait for a response with timeout to detect stalled peers
                // 30s timeout: If no message, send Keep-Alive pulse to stay connected!
                let msg_result = tokio::time::timeout(
                    std::time::Duration::from_secs(30), 
                    conn.receive_message()
                ).await;

                match msg_result {
                    Ok(Ok(Some(msg))) => {
                        match msg {
                            Message::Piece { index, begin: msg_begin, data } => {
                                if index as usize == piece_index {
                                    if piece.add_block(msg_begin as usize, data) {
                                        pending_requests -= 1;
                                        
                                        // ADAPTIVE LOGIC:
                                        // Fast peer (<500ms)? Increase pipeline slowly (requiring streak).
                                        // Slow peer (>2s)? Decrease pipeline immediately.
                                        let duration = request_start.elapsed();
                                        if duration < std::time::Duration::from_millis(500) {
                                            fast_streak += 1;
                                            if fast_streak >= 5 {
                                                if pipeline_size < 20 {
                                                    pipeline_size += 1;
                                                }
                                                fast_streak = 0;
                                            }
                                        } else if duration > std::time::Duration::from_secs(2) {
                                            if pipeline_size > 1 {
                                                pipeline_size /= 2;
                                            }
                                            fast_streak = 0;
                                        }
                                    }
                                }
                            },
                            Message::Choke => {
                                // Peer choked us - we must wait for unchoke
                                pending_requests = 0; 
                                pipeline_size = 1; // Reset to safe mode on choke
                            },
                            Message::Unchoke => {
                                // We are unchoked! Loop will continue and send requests
                            },
                            Message::KeepAlive => {
                                // Just a heartbeat, ignore
                            },
                            _ => {} // Ignore other messages
                        }
                    },
                    Ok(Ok(None)) => return Ok(()), // Connection closed by peer
                    Ok(Err(_)) => return Ok(()),   // Protocol error
                    Err(_) => {
                        // TIMEOUT hit (30s)!
                        // Send Keep-Alive packet to tell peer we are still here.
                        // If we don't do this, they will disconnect us after 60-120s.
                        if let Err(_) = conn.send_message(&Message::KeepAlive).await {
                             return Ok(()); // Connection dead
                        }
                        // Continue loop (go back to request/receive)
                    }, 
                }
            }
            
            // Verify and save piece
            if piece.verify() {
                if let Some(data) = piece.data() {
                    // Send to storage FIRST (before we drop data)
                    if tx.send((piece_index, data)).await.is_err() {
                        return Ok(());
                    }

                    // Update the shared pieces
                    // CRITICAL MEMORY FIX: Don't clone data! Just mark as complete.
                    {
                        let mut pieces_guard = pieces.lock().unwrap();
                        pieces_guard[piece_index].mark_complete();
                    }
                    
                    // pieces_downloaded += 1;
                }
            } else {
                // Verification failed, mark as not in progress so another peer can try
                let mut pieces_guard = pieces.lock().unwrap();
                pieces_guard[piece_index].in_progress = false;
            }
        } else {
            // NO PIECE FOUND - Vital Fix for "Instant Drop"
            // If we have no pieces to download (all in progress or peer has none),
            // WE MUST NOT EXIT! We must wait.
            tokio::time::sleep(std::time::Duration::from_secs(2)).await;
            
            // Optional: send NotInterested if we were interested?
            // But we might become interested soon.
            // Just sleeping is fine.
        }
    }
    // Loop is now technically infinite unless cancelled or error, preventing unreachable code warning
}
