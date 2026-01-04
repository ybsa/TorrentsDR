use anyhow::{Result, Context, bail};
use std::net::{SocketAddr, IpAddr, Ipv4Addr};
use crate::bencode::decode;

#[derive(Debug, Clone)]
pub struct TrackerResponse {
    pub interval: u64,
    pub peers: Vec<SocketAddr>,
}

#[derive(Debug)]
pub struct TrackerRequest {
    pub info_hash: [u8; 20],
    pub peer_id: [u8; 20],
    pub port: u16,
    pub uploaded: u64,
    pub downloaded: u64,
    pub left: u64,
}

pub async fn announce(tracker_url: &str, request: &TrackerRequest) -> Result<TrackerResponse> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(30))
        .build()
        .context("Failed to create HTTP client")?;
    
    // Build query parameters
    let url = format!(
        "{}?info_hash={}&peer_id={}&port={}&uploaded={}&downloaded={}&left={}&compact=1",
        tracker_url,
        url_encode(&request.info_hash),
        url_encode(&request.peer_id),
        request.port,
        request.uploaded,
        request.downloaded,
        request.left,
    );
    
    let response = client.get(&url)
        .send()
        .await
        .context("Failed to send tracker request")?;
    
    if !response.status().is_success() {
        bail!("Tracker returned error: {}", response.status());
    }
    
    let body = response.bytes()
        .await
        .context("Failed to read tracker response")?;
    
    parse_tracker_response(&body)
}

fn url_encode(data: &[u8]) -> String {
    data.iter()
        .map(|&b| format!("%{:02x}", b))
        .collect()
}

fn parse_tracker_response(data: &[u8]) -> Result<TrackerResponse> {
    let root = decode(data)
        .context("Failed to decode tracker response")?;
    
    let dict = root.as_dict()
        .context("Tracker response must be a dictionary")?;
    
    // Check for failure reason
    if let Some(failure) = dict.get("failure reason") {
        if let Some(reason) = failure.as_str() {
            bail!("Tracker error: {}", reason);
        }
    }
    
    let interval = dict.get("interval")
        .and_then(|v| v.as_int())
        .context("Missing or invalid interval")? as u64;
    
    // Parse peers (compact format)
    let peers_data = dict.get("peers")
        .and_then(|v| v.as_bytes())
        .context("Missing or invalid peers")?;
    
    let peers = parse_compact_peers(peers_data)?;
    
    Ok(TrackerResponse {
        interval,
        peers,
    })
}

fn parse_compact_peers(data: &[u8]) -> Result<Vec<SocketAddr>> {
    if data.len() % 6 != 0 {
        bail!("Compact peers data must be a multiple of 6 bytes");
    }
    
    let peers = data.chunks_exact(6)
        .map(|chunk| {
            let ip = IpAddr::V4(Ipv4Addr::new(chunk[0], chunk[1], chunk[2], chunk[3]));
            let port = u16::from_be_bytes([chunk[4], chunk[5]]);
            SocketAddr::new(ip, port)
        })
        .collect();
    
    Ok(peers)
}

pub fn generate_peer_id() -> [u8; 20] {
    let mut peer_id = [0u8; 20];
    peer_id[..8].copy_from_slice(b"-RT0100-");
    
    // Fill rest with random bytes
    use std::time::{SystemTime, UNIX_EPOCH};
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();
    
    for (i, byte) in peer_id[8..].iter_mut().enumerate() {
        *byte = ((timestamp + i as u64) % 256) as u8;
    }
    
    peer_id
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_compact_peers() {
        let data = vec![
            127, 0, 0, 1, 0x1A, 0xE1,  // 127.0.0.1:6881
            192, 168, 1, 100, 0x1A, 0xE2,  // 192.168.1.100:6882
        ];
        
        let peers = parse_compact_peers(&data).unwrap();
        assert_eq!(peers.len(), 2);
        assert_eq!(peers[0].to_string(), "127.0.0.1:6881");
        assert_eq!(peers[1].to_string(), "192.168.1.100:6882");
    }

    #[test]
    fn test_generate_peer_id() {
        let peer_id = generate_peer_id();
        assert_eq!(&peer_id[..8], b"-RT0100-");
    }
}
