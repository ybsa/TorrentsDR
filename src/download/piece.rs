use sha1::{Sha1, Digest};

const BLOCK_SIZE: usize = 16384; // 16 KB

#[derive(Debug, Clone)]
pub struct Piece {
    pub index: usize,
    pub length: usize,
    pub hash: [u8; 20],
    blocks: Vec<Option<Vec<u8>>>,
    num_blocks: usize,
    pub in_progress: bool, // Track if this piece is being downloaded
}

impl Piece {
    pub fn new(index: usize, length: usize, hash: [u8; 20]) -> Self {
        let num_blocks = (length + BLOCK_SIZE - 1) / BLOCK_SIZE;
        let blocks = vec![None; num_blocks];
        
        Piece {
            index,
            length,
            hash,
            blocks,
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
    
    pub fn next_block_to_request(&self) -> Option<(usize, usize)> {
        for (i, block) in self.blocks.iter().enumerate() {
            if block.is_none() {
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
