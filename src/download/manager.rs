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
    
    pub async fn download_from_peers(&self, peers: Vec<SocketAddr>) -> Result<()> {
        let (tx, mut rx) = mpsc::channel(200);
        
        // Spawn tasks for each peer - increased from 5 to 20 for faster downloads
        for peer_addr in peers.iter().take(20) {
            let tx = tx.clone();
            let metainfo = Arc::clone(&self.metainfo);
            let pieces = Arc::clone(&self.pieces);
            let peer_id = self.peer_id;
            let peer_addr = *peer_addr;
            
            tokio::spawn(async move {
                let _ = download_from_peer(peer_addr, metainfo, pieces, peer_id, tx).await;
            });
        }
        
        drop(tx); // Drop the original sender
        
        // Track download speed
        let start_time = std::time::Instant::now();
        let mut downloaded_bytes = 0u64;
        let mut last_report = std::time::Instant::now();
        
        // Collect completed pieces
        while let Some((piece_index, data)) = rx.recv().await {
            let mut storage = self.storage.lock().unwrap();
            storage.write_piece(piece_index, &data)
                .context("Failed to write piece")?;
            
            downloaded_bytes += data.len() as u64;
            
            // Report progress every 2 seconds
            if last_report.elapsed().as_secs() >= 2 {
                let (complete, total) = self.progress();
                let elapsed = start_time.elapsed().as_secs_f64();
                let speed_mbps = (downloaded_bytes as f64 / elapsed) / 1_048_576.0;
                let progress_pct = (complete as f64 / total as f64) * 100.0;
                
                println!("✓ Progress: {}/{} pieces ({:.1}%) | Speed: {:.2} MB/s | Downloaded: {:.2} MB",
                    complete, total, progress_pct,
                    speed_mbps, downloaded_bytes as f64 / 1_048_576.0);
                
                last_report = std::time::Instant::now();
            }
        }
        
        // Final summary
        let elapsed = start_time.elapsed().as_secs_f64();
        let avg_speed = (downloaded_bytes as f64 / elapsed) / 1_048_576.0;
        println!("\n✓ Download complete!");
        println!("Total downloaded: {:.2} MB in {:.1}s", 
            downloaded_bytes as f64 / 1_048_576.0, elapsed);
        println!("Average speed: {:.2} MB/s", avg_speed);
        
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
    let mut conn = PeerConnection::connect(peer_addr, &metainfo.info_hash, &peer_id).await?;
    
    // Wait for bitfield or first message
    let _ = conn.receive_message().await?;
    
    // Send interested
    conn.send_interested().await?;
    
    // Wait for unchoke
    loop {
        if let Some(msg) = conn.receive_message().await? {
            if matches!(msg, Message::Unchoke) {
                break;
            }
        } else {
            return Ok(()); // Connection closed
        }
    }
    
    // Download pieces
    loop {
        // Find a piece to download
        let piece_to_download = {
            let mut pieces_guard = pieces.lock().unwrap();
            pieces_guard.iter_mut()
                .find(|p| !p.is_complete() && conn.has_piece(p.index))
                .map(|p| (p.index, p.length, p.hash))
        };
        
        if let Some((piece_index, piece_length, piece_hash)) = piece_to_download {
            // Download this piece with pipelining (request multiple blocks at once)
            let mut piece = Piece::new(piece_index, piece_length, piece_hash);
            
            const PIPELINE_SIZE: usize = 5; // Request 5 blocks at a time for speed
            let mut pending_requests = 0;
            
            // Pipeline requests
            while !piece.is_complete() {
                // Send requests up to pipeline size
                while pending_requests < PIPELINE_SIZE {
                    if let Some((begin, length)) = piece.next_block_to_request() {
                        conn.request_piece(piece_index as u32, begin as u32, length as u32).await?;
                        pending_requests += 1;
                    } else {
                        break;
                    }
                }
                
                // Wait for a response
                if let Some(msg) = conn.receive_message().await? {
                    if let Message::Piece { index, begin: msg_begin, data } = msg {
                        if index as usize == piece_index {
                            piece.add_block(msg_begin as usize, data);
                            pending_requests -= 1;
                        }
                    }
                } else {
                    return Ok(()); // Connection closed
                }
            }
            
            // Verify and save the piece
            if piece.verify() {
                if let Some(data) = piece.data() {
                    // Update the shared pieces
                    {
                        let mut pieces_guard = pieces.lock().unwrap();
                        pieces_guard[piece_index] = piece.clone();
                    }
                    
                    // Send to storage
                    let _ = tx.send((piece_index, data)).await;
                }
            }
        } else {
            // No more pieces to download from this peer
            break;
        }
    }
    
    Ok(())
}
