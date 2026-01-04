use std::fs::{File, OpenOptions, create_dir_all};
use std::io::{Write, Seek, SeekFrom};
use std::path::PathBuf;
use anyhow::{Result, Context};
use crate::torrent::Metainfo;

pub struct Storage {
    files: Vec<StorageFile>,
    piece_length: usize,
}

struct StorageFile {
    file: File,
    offset: usize,
    length: usize,
}

impl Storage {
    pub fn new(metainfo: &Metainfo, output_dir: &str) -> Result<Self> {
        let mut files = Vec::new();
        let mut current_offset = 0;
        
        for file_info in &metainfo.info.files {
            let mut path = PathBuf::from(output_dir);
            path.push(&metainfo.info.name);
            
            for component in &file_info.path {
                path.push(component);
            }
            
            // Create parent directory
            if let Some(parent) = path.parent() {
                create_dir_all(parent)
                    .context("Failed to create output directory")?;
            }
            
            // Open or create file
            let file = OpenOptions::new()
                .read(true)
                .write(true)
                .create(true)
                .open(&path)
                .context(format!("Failed to open file: {:?}", path))?;
            
            // Set file size
            file.set_len(file_info.length as u64)
                .context("Failed to set file size")?;
            
            files.push(StorageFile {
                file,
                offset: current_offset,
                length: file_info.length,
            });
            
            current_offset += file_info.length;
        }
        
        Ok(Storage {
            files,
            piece_length: metainfo.info.piece_length,
        })
    }
    
    pub fn write_piece(&mut self, piece_index: usize, data: &[u8]) -> Result<()> {
        let piece_offset = piece_index * self.piece_length;
        let mut data_offset = 0;
        let data_len = data.len();
        
        for storage_file in &mut self.files {
            // Check if this file overlaps with the piece
            let file_start = storage_file.offset;
            let file_end = storage_file.offset + storage_file.length;
            
            if piece_offset >= file_end || piece_offset + data_len <= file_start {
                continue; // No overlap
            }
            
            // Calculate overlap
            let write_start = if piece_offset > file_start {
                piece_offset - file_start
            } else {
                0
            };
            
            let write_end = std::cmp::min(
                write_start + data_len - data_offset,
                storage_file.length
            );
            
            let write_len = write_end - write_start;
            
            // Write to file
            storage_file.file.seek(SeekFrom::Start(write_start as u64))
                .context("Failed to seek in file")?;
            
            storage_file.file.write_all(&data[data_offset..data_offset + write_len])
                .context("Failed to write to file")?;
            
            // CRITICAL: Flush to disk immediately to ensure data isn't lost
            storage_file.file.flush()
                .context("Failed to flush file")?;
            
            data_offset += write_len;
            
            if data_offset >= data_len {
                break;
            }
        }
        
        Ok(())
    }
}
