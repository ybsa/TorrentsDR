//! Magnet Link Parser
//! 
//! Parses magnet:?xt=urn:btih:... links to extract info hash and metadata.

use anyhow::{Result, Context, bail};
use std::collections::HashMap;

/// Parsed magnet link information
#[derive(Debug, Clone)]
pub struct MagnetLink {
    /// Info hash (20 bytes)
    pub info_hash: [u8; 20],
    /// Display name (optional)
    pub display_name: Option<String>,
    /// Tracker URLs (optional)
    pub trackers: Vec<String>,
    /// Exact length in bytes (optional)
    pub size: Option<u64>,
}

impl MagnetLink {
    /// Parse a magnet link string.
    /// 
    /// Example: magnet:?xt=urn:btih:HASH&dn=Name&tr=http://tracker.com
    pub fn parse(uri: &str) -> Result<Self> {
        if !uri.starts_with("magnet:?") {
            bail!("Invalid magnet link: must start with 'magnet:?'");
        }
        
        let query = &uri[8..]; // Skip "magnet:?"
        let params = parse_query_string(query);
        
        // Get info hash from xt parameter
        let xt = params.get("xt")
            .context("Missing 'xt' (exact topic) parameter")?;
        
        let info_hash = parse_info_hash(xt)?;
        
        // Get optional display name
        let display_name = params.get("dn").cloned();
        
        // Get tracker URLs
        let trackers: Vec<String> = params.iter()
            .filter(|(k, _)| *k == "tr")
            .map(|(_, v)| v.clone())
            .collect();
        
        // Get optional size
        let size = params.get("xl")
            .and_then(|s| s.parse().ok());
        
        Ok(MagnetLink {
            info_hash,
            display_name,
            trackers,
            size,
        })
    }
    
    /// Get info hash as hex string
    pub fn info_hash_hex(&self) -> String {
        hex::encode(self.info_hash)
    }
}

/// Parse query string into key-value pairs
fn parse_query_string(query: &str) -> Vec<(String, String)> {
    query.split('&')
        .filter_map(|pair| {
            let mut parts = pair.splitn(2, '=');
            let key = parts.next()?;
            let value = parts.next().unwrap_or("");
            Some((
                url_decode(key),
                url_decode(value),
            ))
        })
        .collect()
}

/// URL decode a string
fn url_decode(s: &str) -> String {
    let mut result = String::new();
    let mut chars = s.chars().peekable();
    
    while let Some(c) = chars.next() {
        if c == '%' {
            if let (Some(h1), Some(h2)) = (chars.next(), chars.next()) {
                if let Ok(byte) = u8::from_str_radix(&format!("{}{}", h1, h2), 16) {
                    result.push(byte as char);
                    continue;
                }
            }
            result.push('%');
        } else if c == '+' {
            result.push(' ');
        } else {
            result.push(c);
        }
    }
    
    result
}

/// Parse info hash from xt parameter
fn parse_info_hash(xt: &str) -> Result<[u8; 20]> {
    // Format: urn:btih:HASH
    // HASH can be:
    // - 40 hex characters (most common)
    // - 32 base32 characters
    
    let hash_str = xt.strip_prefix("urn:btih:")
        .or_else(|| xt.strip_prefix("urn:btmh:"))
        .context("Invalid xt format: must be 'urn:btih:HASH'")?;
    
    let mut info_hash = [0u8; 20];
    
    if hash_str.len() == 40 {
        // Hex encoded
        let decoded = hex::decode(hash_str)
            .context("Invalid hex in info hash")?;
        info_hash.copy_from_slice(&decoded);
    } else if hash_str.len() == 32 {
        // Base32 encoded
        let decoded = base32_decode(hash_str)?;
        info_hash.copy_from_slice(&decoded);
    } else {
        bail!("Invalid info hash length: expected 40 hex or 32 base32 chars");
    }
    
    Ok(info_hash)
}

/// Simple base32 decoder
fn base32_decode(s: &str) -> Result<Vec<u8>> {
    const ALPHABET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    
    let s = s.to_uppercase();
    let mut bits = 0u64;
    let mut bit_count = 0;
    let mut result = Vec::new();
    
    for c in s.bytes() {
        let value = ALPHABET.iter().position(|&x| x == c)
            .context("Invalid base32 character")? as u64;
        
        bits = (bits << 5) | value;
        bit_count += 5;
        
        while bit_count >= 8 {
            bit_count -= 8;
            result.push((bits >> bit_count) as u8);
        }
    }
    
    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_parse_magnet() {
        let magnet = "magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=Big+Buck+Bunny&tr=http%3A%2F%2Ftracker.example.com%2Fannounce";
        
        let parsed = MagnetLink::parse(magnet).unwrap();
        
        assert_eq!(parsed.info_hash_hex(), "dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c");
        assert_eq!(parsed.display_name, Some("Big Buck Bunny".to_string()));
        assert_eq!(parsed.trackers.len(), 1);
    }
    
    #[test]
    fn test_base32_decode() {
        // Base32 encoded "Hello"
        let decoded = base32_decode("JBSWY3DP").unwrap();
        assert_eq!(decoded, b"Hello");
    }
}
