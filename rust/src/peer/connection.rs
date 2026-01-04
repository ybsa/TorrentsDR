use tokio::net::TcpStream;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use bytes::BytesMut;
use anyhow::{Result, Context, bail};
use std::net::SocketAddr;
use super::message::{Message, create_handshake, parse_handshake};

pub struct PeerConnection {
    stream: TcpStream,
    buffer: BytesMut,
    addr: SocketAddr,
    peer_choking: bool,
    am_interested: bool,
    bitfield: Option<Vec<u8>>,
}

impl PeerConnection {
    pub async fn connect(
        addr: SocketAddr,
        info_hash: &[u8; 20],
        peer_id: &[u8; 20],
    ) -> Result<Self> {
        let mut stream = TcpStream::connect(addr).await
            .context("Failed to connect to peer")?;
        
        // Send handshake
        let handshake = create_handshake(info_hash, peer_id);
        stream.write_all(&handshake).await
            .context("Failed to send handshake")?;
        
        // Receive handshake
        let mut handshake_buf = vec![0u8; 68];
        stream.read_exact(&mut handshake_buf).await
            .context("Failed to read handshake")?;
        
        let (received_info_hash, _peer_id) = parse_handshake(&handshake_buf)
            .context("Failed to parse handshake")?;
        
        if &received_info_hash != info_hash {
            bail!("Info hash mismatch");
        }
        
        Ok(PeerConnection {
            stream,
            buffer: BytesMut::with_capacity(131072), // 128KB buffer for speed
            addr,
            peer_choking: true,
            am_interested: false,
            bitfield: None,
        })
    }
    
    pub async fn send_message(&mut self, msg: &Message) -> Result<()> {
        let encoded = msg.encode();
        self.stream.write_all(&encoded).await
            .context("Failed to send message")?;
        Ok(())
    }
    
    pub async fn receive_message(&mut self) -> Result<Option<Message>> {
        loop {
            // Try to decode a message from the buffer
            if let Some(msg) = Message::decode(&mut self.buffer)? {
                self.handle_message(&msg);
                return Ok(Some(msg));
            }
            
            // Read more data from the stream - 64KB chunks for speed
            let mut temp_buf = vec![0u8; 65536];
            let n = self.stream.read(&mut temp_buf).await
                .context("Failed to read from peer")?;
            
            if n == 0 {
                return Ok(None); // Connection closed
            }
            
            self.buffer.extend_from_slice(&temp_buf[..n]);
        }
    }
    
    fn handle_message(&mut self, msg: &Message) {
        match msg {
            Message::Choke => self.peer_choking = true,
            Message::Unchoke => self.peer_choking = false,
            Message::Bitfield { bitfield } => self.bitfield = Some(bitfield.clone()),
            _ => {}
        }
    }
    
    pub async fn send_interested(&mut self) -> Result<()> {
        self.send_message(&Message::Interested).await?;
        self.am_interested = true;
        Ok(())
    }
    
    pub async fn request_piece(
        &mut self,
        piece_index: u32,
        begin: u32,
        length: u32,
    ) -> Result<()> {
        if self.peer_choking {
            bail!("Peer is choking us");
        }
        
        self.send_message(&Message::Request {
            index: piece_index,
            begin,
            length,
        }).await
    }
    
    pub fn is_choking(&self) -> bool {
        self.peer_choking
    }
    
    pub fn has_piece(&self, piece_index: usize) -> bool {
        if let Some(bitfield) = &self.bitfield {
            let byte_index = piece_index / 8;
            let bit_index = 7 - (piece_index % 8);
            
            if byte_index < bitfield.len() {
                return (bitfield[byte_index] >> bit_index) & 1 == 1;
            }
        }
        false
    }
    
    pub fn addr(&self) -> &SocketAddr {
        &self.addr
    }
}
