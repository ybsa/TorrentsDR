use sha1::{Sha1, Digest};

const BLOCK_SIZE: usize = 16384; // 16 KB

#[derive(Debug, Clone)]
pub struct Piece {
    pub index: usize,
    pub length: usize,
    pub hash: [u8; 20],
    blocks: Vec<Option<Vec<u8>>>,
    requested: Vec<bool>, // Track which blocks we've asked for
    num_blocks: usize,
    pub in_progress: bool,
}

impl Piece {
    pub fn new(index: usize, length: usize, hash: [u8; 20]) -> Self {
        let num_blocks = (length + BLOCK_SIZE - 1) / BLOCK_SIZE;
        let blocks = vec![None; num_blocks];
        let requested = vec![false; num_blocks];
        
        Piece {
            index,
            length,
            hash,
            blocks,
            requested,
            num_blocks,
            in_progress: false,
        }
    }
    
    pub fn add_block(&mut self, begin: usize, data: Vec<u8>) -> bool {
        let block_index = begin / BLOCK_SIZE;
        
        if block_index >= self.num_blocks {
            return false;
        }
        
        self.blocks[block_index] = Some(data);
        true
    }
    
    pub fn is_complete(&self) -> bool {
        self.blocks.iter().all(|block| block.is_some())
    }
    
    pub fn verify(&self) -> bool {
        if !self.is_complete() {
            return false;
        }
        
        let mut hasher = Sha1::new();
        for block in &self.blocks {
            if let Some(data) = block {
                hasher.update(data);
            }
        }
        
        let hash: [u8; 20] = hasher.finalize().into();
        hash == self.hash
    }
    
    pub fn data(&self) -> Option<Vec<u8>> {
        if !self.is_complete() {
            return None;
        }
        
        let mut result = Vec::with_capacity(self.length);
        for block in &self.blocks {
            if let Some(data) = block {
                result.extend_from_slice(data);
            }
        }
        
        Some(result)
    }
    
    pub fn next_block_to_request(&mut self) -> Option<(usize, usize)> {
        for (i, block) in self.blocks.iter().enumerate() {
            // Find a block that is missing AND hasn't been requested yet
            if block.is_none() && !self.requested[i] {
                self.requested[i] = true; // Mark as requested so we don't ask again
                
                let begin = i * BLOCK_SIZE;
                let length = if i == self.num_blocks - 1 {
                    // Last block might be smaller
                    self.length - begin
                } else {
                    BLOCK_SIZE
                };
                return Some((begin, length));
            }
        }
        None
    }

    pub fn mark_complete(&mut self) {
        // Mark as complete but drop the data to save RAM
        for block in &mut self.blocks {
            *block = Some(Vec::new());
        }
        self.in_progress = false;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_piece_blocks() {
        let hash = [0u8; 20];
        let mut piece = Piece::new(0, 32768, hash); // 2 blocks
        
        assert!(!piece.is_complete());
        assert_eq!(piece.next_block_to_request(), Some((0, 16384)));
        
        piece.add_block(0, vec![1u8; 16384]);
        assert_eq!(piece.next_block_to_request(), Some((16384, 16384)));
        
        piece.add_block(16384, vec![2u8; 16384]);
        assert!(piece.is_complete());
        assert_eq!(piece.next_block_to_request(), None);
    }
}
