use bytes::{Buf, BufMut, BytesMut};
use anyhow::{Result, bail};

#[derive(Debug, Clone, PartialEq)]
pub enum Message {
    KeepAlive,
    Choke,
    Unchoke,
    Interested,
    NotInterested,
    Have { piece_index: u32 },
    Bitfield { bitfield: Vec<u8> },
    Request { index: u32, begin: u32, length: u32 },
    Piece { index: u32, begin: u32, data: Vec<u8> },
    Cancel { index: u32, begin: u32, length: u32 },
}

impl Message {
    pub fn encode(&self) -> Vec<u8> {
        let mut buf = Vec::new();
        
        match self {
            Message::KeepAlive => {
                buf.put_u32(0); // length
            }
            Message::Choke => {
                buf.put_u32(1); // length
                buf.put_u8(0); // id
            }
            Message::Unchoke => {
                buf.put_u32(1);
                buf.put_u8(1);
            }
            Message::Interested => {
                buf.put_u32(1);
                buf.put_u8(2);
            }
            Message::NotInterested => {
                buf.put_u32(1);
                buf.put_u8(3);
            }
            Message::Have { piece_index } => {
                buf.put_u32(5);
                buf.put_u8(4);
                buf.put_u32(*piece_index);
            }
            Message::Bitfield { bitfield } => {
                buf.put_u32(1 + bitfield.len() as u32);
                buf.put_u8(5);
                buf.extend_from_slice(bitfield);
            }
            Message::Request { index, begin, length } => {
                buf.put_u32(13);
                buf.put_u8(6);
                buf.put_u32(*index);
                buf.put_u32(*begin);
                buf.put_u32(*length);
            }
            Message::Piece { index, begin, data } => {
                buf.put_u32(9 + data.len() as u32);
                buf.put_u8(7);
                buf.put_u32(*index);
                buf.put_u32(*begin);
                buf.extend_from_slice(data);
            }
            Message::Cancel { index, begin, length } => {
                buf.put_u32(13);
                buf.put_u8(8);
                buf.put_u32(*index);
                buf.put_u32(*begin);
                buf.put_u32(*length);
            }
        }
        
        buf
    }
    
    pub fn decode(data: &mut BytesMut) -> Result<Option<Message>> {
        if data.len() < 4 {
            return Ok(None); // Need more data for length
        }
        
        let length = u32::from_be_bytes([data[0], data[1], data[2], data[3]]) as usize;
        
        if length == 0 {
            data.advance(4);
            return Ok(Some(Message::KeepAlive));
        }
        
        if data.len() < 4 + length {
            return Ok(None); // Need more data for payload
        }
        
        data.advance(4); // Skip length prefix
        let id = data.get_u8();
        
        let message = match id {
            0 => Message::Choke,
            1 => Message::Unchoke,
            2 => Message::Interested,
            3 => Message::NotInterested,
            4 => {
                let piece_index = data.get_u32();
                Message::Have { piece_index }
            }
            5 => {
                let bitfield = data.split_to(length - 1).to_vec();
                Message::Bitfield { bitfield }
            }
            6 => {
                let index = data.get_u32();
                let begin = data.get_u32();
                let length = data.get_u32();
                Message::Request { index, begin, length }
            }
            7 => {
                let index = data.get_u32();
                let begin = data.get_u32();
                let piece_data = data.split_to(length - 9).to_vec();
                Message::Piece { index, begin, data: piece_data }
            }
            8 => {
                let index = data.get_u32();
                let begin = data.get_u32();
                let length = data.get_u32();
                Message::Cancel { index, begin, length }
            }
            _ => bail!("Unknown message ID: {}", id),
        };
        
        Ok(Some(message))
    }
}

pub fn create_handshake(info_hash: &[u8; 20], peer_id: &[u8; 20]) -> Vec<u8> {
    let mut handshake = Vec::new();
    handshake.push(19); // Protocol name length
    handshake.extend_from_slice(b"BitTorrent protocol");
    handshake.extend_from_slice(&[0u8; 8]); // Reserved bytes
    handshake.extend_from_slice(info_hash);
    handshake.extend_from_slice(peer_id);
    handshake
}

pub fn parse_handshake(data: &[u8]) -> Result<([u8; 20], [u8; 20])> {
    if data.len() < 68 {
        bail!("Handshake too short");
    }
    
    if data[0] != 19 {
        bail!("Invalid protocol name length");
    }
    
    if &data[1..20] != b"BitTorrent protocol" {
        bail!("Invalid protocol name");
    }
    
    let mut info_hash = [0u8; 20];
    let mut peer_id = [0u8; 20];
    
    info_hash.copy_from_slice(&data[28..48]);
    peer_id.copy_from_slice(&data[48..68]);
    
    Ok((info_hash, peer_id))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_message_encode_decode() {
        let msg = Message::Request {
            index: 5,
            begin: 0,
            length: 16384,
        };
        
        let encoded = msg.encode();
        let mut buf = BytesMut::from(&encoded[..]);
        let decoded = Message::decode(&mut buf).unwrap().unwrap();
        
        assert_eq!(msg, decoded);
    }

    #[test]
    fn test_handshake() {
        let info_hash = [1u8; 20];
        let peer_id = [2u8; 20];
        
        let handshake = create_handshake(&info_hash, &peer_id);
        let (parsed_info_hash, parsed_peer_id) = parse_handshake(&handshake).unwrap();
        
        assert_eq!(info_hash, parsed_info_hash);
        assert_eq!(peer_id, parsed_peer_id);
    }
}
