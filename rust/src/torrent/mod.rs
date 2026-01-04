use std::path::Path;
use anyhow::{Result, Context, bail};
use sha1::{Sha1, Digest};
use crate::bencode::{decode, encode};

#[derive(Debug, Clone)]
pub struct Metainfo {
    pub announce: String,
    pub info_hash: [u8; 20],
    pub info: TorrentInfo,
}

#[derive(Debug, Clone)]
pub struct TorrentInfo {
    pub name: String,
    pub piece_length: usize,
    pub pieces: Vec<[u8; 20]>,
    pub files: Vec<FileInfo>,
    pub total_length: usize,
}

#[derive(Debug, Clone)]
pub struct FileInfo {
    pub path: Vec<String>,
    pub length: usize,
}

impl Metainfo {
    pub fn from_file<P: AsRef<Path>>(path: P) -> Result<Self> {
        let data = std::fs::read(path)
            .context("Failed to read torrent file")?;
        Self::from_bytes(&data)
    }

    pub fn from_bytes(data: &[u8]) -> Result<Self> {
        let root = decode(data)
            .context("Failed to decode torrent file")?;
        
        let dict = root.as_dict()
            .context("Torrent file root must be a dictionary")?;
        
        // Get announce URL
        let announce = dict.get("announce")
            .and_then(|v| v.as_str())
            .context("Missing or invalid announce URL")?
            .to_string();
        
        // Get info dictionary
        let info_value = dict.get("info")
            .context("Missing info dictionary")?;
        
        // Calculate info hash
        let info_encoded = encode(info_value);
        let mut hasher = Sha1::new();
        hasher.update(&info_encoded);
        let info_hash: [u8; 20] = hasher.finalize().into();
        
        // Parse info dictionary
        let info_dict = info_value.as_dict()
            .context("Info must be a dictionary")?;
        
        let name = info_dict.get("name")
            .and_then(|v| v.as_str())
            .context("Missing or invalid name")?
            .to_string();
        
        let piece_length = info_dict.get("piece length")
            .and_then(|v| v.as_int())
            .context("Missing or invalid piece length")? as usize;
        
        // Parse pieces (concatenated SHA1 hashes)
        let pieces_bytes = info_dict.get("pieces")
            .and_then(|v| v.as_bytes())
            .context("Missing or invalid pieces")?;
        
        if pieces_bytes.len() % 20 != 0 {
            bail!("Pieces length must be a multiple of 20");
        }
        
        let pieces: Vec<[u8; 20]> = pieces_bytes
            .chunks_exact(20)
            .map(|chunk| {
                let mut hash = [0u8; 20];
                hash.copy_from_slice(chunk);
                hash
            })
            .collect();
        
        // Parse files (single file or multiple files)
        let (files, total_length) = if let Some(length) = info_dict.get("length") {
            // Single file mode
            let length = length.as_int()
                .context("Invalid file length")? as usize;
            
            let file = FileInfo {
                path: vec![name.clone()],
                length,
            };
            
            (vec![file], length)
        } else if let Some(files_value) = info_dict.get("files") {
            // Multiple files mode
            let files_list = files_value.as_list()
                .context("Files must be a list")?;
            
            let mut files = Vec::new();
            let mut total = 0;
            
            for file_value in files_list {
                let file_dict = file_value.as_dict()
                    .context("File entry must be a dictionary")?;
                
                let length = file_dict.get("length")
                    .and_then(|v| v.as_int())
                    .context("Missing or invalid file length")? as usize;
                
                let path_list = file_dict.get("path")
                    .and_then(|v| v.as_list())
                    .context("Missing or invalid file path")?;
                
                let path: Result<Vec<String>> = path_list
                    .iter()
                    .map(|v| v.as_str()
                        .map(|s| s.to_string())
                        .context("Path component must be a string"))
                    .collect();
                
                files.push(FileInfo {
                    path: path?,
                    length,
                });
                
                total += length;
            }
            
            (files, total)
        } else {
            bail!("Torrent must have either 'length' or 'files'");
        };
        
        let info = TorrentInfo {
            name,
            piece_length,
            pieces,
            files,
            total_length,
        };
        
        Ok(Metainfo {
            announce,
            info_hash,
            info,
        })
    }

    pub fn info_hash_hex(&self) -> String {
        hex::encode(self.info_hash)
    }

    pub fn num_pieces(&self) -> usize {
        self.info.pieces.len()
    }

    pub fn piece_hash(&self, index: usize) -> Option<&[u8; 20]> {
        self.info.pieces.get(index)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    #[test]
    fn test_parse_single_file_torrent() {
        // Create a minimal single-file torrent structure
        let mut info_dict = HashMap::new();
        info_dict.insert("name".to_string(), BencodeValue::String(b"test.txt".to_vec()));
        info_dict.insert("piece length".to_string(), BencodeValue::Integer(16384));
        info_dict.insert("length".to_string(), BencodeValue::Integer(1024));
        info_dict.insert("pieces".to_string(), BencodeValue::String(vec![0u8; 20]));

        let mut root = HashMap::new();
        root.insert("announce".to_string(), BencodeValue::String(b"http://tracker.example.com/announce".to_vec()));
        root.insert("info".to_string(), BencodeValue::Dict(info_dict));

        let encoded = encode(&BencodeValue::Dict(root));
        let metainfo = Metainfo::from_bytes(&encoded).unwrap();

        assert_eq!(metainfo.announce, "http://tracker.example.com/announce");
        assert_eq!(metainfo.info.name, "test.txt");
        assert_eq!(metainfo.info.piece_length, 16384);
        assert_eq!(metainfo.info.total_length, 1024);
        assert_eq!(metainfo.info.files.len(), 1);
    }
}
