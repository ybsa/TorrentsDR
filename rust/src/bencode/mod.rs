use std::collections::HashMap;
use anyhow::{Result, bail, Context};

#[derive(Debug, Clone, PartialEq)]
pub enum BencodeValue {
    String(Vec<u8>),
    Integer(i64),
    List(Vec<BencodeValue>),
    Dict(HashMap<String, BencodeValue>),
}

impl BencodeValue {
    pub fn as_bytes(&self) -> Option<&[u8]> {
        match self {
            BencodeValue::String(s) => Some(s),
            _ => None,
        }
    }

    pub fn as_str(&self) -> Option<&str> {
        self.as_bytes().and_then(|b| std::str::from_utf8(b).ok())
    }

    pub fn as_int(&self) -> Option<i64> {
        match self {
            BencodeValue::Integer(i) => Some(*i),
            _ => None,
        }
    }

    pub fn as_list(&self) -> Option<&Vec<BencodeValue>> {
        match self {
            BencodeValue::List(l) => Some(l),
            _ => None,
        }
    }

    pub fn as_dict(&self) -> Option<&HashMap<String, BencodeValue>> {
        match self {
            BencodeValue::Dict(d) => Some(d),
            _ => None,
        }
    }
}

/// Decode bencode data into a BencodeValue
pub fn decode(data: &[u8]) -> Result<BencodeValue> {
    let (value, _) = decode_value(data)?;
    Ok(value)
}

fn decode_value(data: &[u8]) -> Result<(BencodeValue, &[u8])> {
    if data.is_empty() {
        bail!("Unexpected end of data");
    }

    match data[0] {
        b'i' => decode_integer(data),
        b'l' => decode_list(data),
        b'd' => decode_dict(data),
        b'0'..=b'9' => decode_string(data),
        _ => bail!("Invalid bencode data"),
    }
}

fn decode_integer(data: &[u8]) -> Result<(BencodeValue, &[u8])> {
    // Format: i<number>e
    let end = data.iter().position(|&b| b == b'e')
        .context("Integer not terminated")?;
    
    let num_str = std::str::from_utf8(&data[1..end])
        .context("Invalid integer encoding")?;
    let num = num_str.parse::<i64>()
        .context("Failed to parse integer")?;
    
    Ok((BencodeValue::Integer(num), &data[end + 1..]))
}

fn decode_string(data: &[u8]) -> Result<(BencodeValue, &[u8])> {
    // Format: <length>:<string>
    let colon_pos = data.iter().position(|&b| b == b':')
        .context("String length separator not found")?;
    
    let len_str = std::str::from_utf8(&data[..colon_pos])
        .context("Invalid string length encoding")?;
    let len = len_str.parse::<usize>()
        .context("Failed to parse string length")?;
    
    let start = colon_pos + 1;
    let end = start + len;
    
    if end > data.len() {
        bail!("String length exceeds data");
    }
    
    Ok((BencodeValue::String(data[start..end].to_vec()), &data[end..]))
}

fn decode_list(data: &[u8]) -> Result<(BencodeValue, &[u8])> {
    // Format: l<values>e
    let mut remaining = &data[1..];
    let mut list = Vec::new();
    
    while !remaining.is_empty() && remaining[0] != b'e' {
        let (value, rest) = decode_value(remaining)?;
        list.push(value);
        remaining = rest;
    }
    
    if remaining.is_empty() {
        bail!("List not terminated");
    }
    
    Ok((BencodeValue::List(list), &remaining[1..]))
}

fn decode_dict(data: &[u8]) -> Result<(BencodeValue, &[u8])> {
    // Format: d<key><value>...e
    let mut remaining = &data[1..];
    let mut dict = HashMap::new();
    
    while !remaining.is_empty() && remaining[0] != b'e' {
        // Decode key (must be a string)
        let (key_value, rest) = decode_value(remaining)?;
        let key = match key_value {
            BencodeValue::String(s) => String::from_utf8(s)
                .context("Dictionary key is not valid UTF-8")?,
            _ => bail!("Dictionary key must be a string"),
        };
        
        // Decode value
        let (value, rest) = decode_value(rest)?;
        dict.insert(key, value);
        remaining = rest;
    }
    
    if remaining.is_empty() {
        bail!("Dictionary not terminated");
    }
    
    Ok((BencodeValue::Dict(dict), &remaining[1..]))
}

/// Encode a BencodeValue into bencode format
pub fn encode(value: &BencodeValue) -> Vec<u8> {
    let mut result = Vec::new();
    encode_value(value, &mut result);
    result
}

fn encode_value(value: &BencodeValue, output: &mut Vec<u8>) {
    match value {
        BencodeValue::Integer(i) => {
            output.push(b'i');
            output.extend_from_slice(i.to_string().as_bytes());
            output.push(b'e');
        }
        BencodeValue::String(s) => {
            output.extend_from_slice(s.len().to_string().as_bytes());
            output.push(b':');
            output.extend_from_slice(s);
        }
        BencodeValue::List(list) => {
            output.push(b'l');
            for item in list {
                encode_value(item, output);
            }
            output.push(b'e');
        }
        BencodeValue::Dict(dict) => {
            output.push(b'd');
            let mut keys: Vec<_> = dict.keys().collect();
            keys.sort();
            for key in keys {
                encode_value(&BencodeValue::String(key.as_bytes().to_vec()), output);
                encode_value(&dict[key], output);
            }
            output.push(b'e');
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_decode_integer() {
        let data = b"i42e";
        let value = decode(data).unwrap();
        assert_eq!(value, BencodeValue::Integer(42));
    }

    #[test]
    fn test_decode_string() {
        let data = b"5:hello";
        let value = decode(data).unwrap();
        assert_eq!(value, BencodeValue::String(b"hello".to_vec()));
    }

    #[test]
    fn test_decode_list() {
        let data = b"li42e5:helloe";
        let value = decode(data).unwrap();
        let expected = BencodeValue::List(vec![
            BencodeValue::Integer(42),
            BencodeValue::String(b"hello".to_vec()),
        ]);
        assert_eq!(value, expected);
    }

    #[test]
    fn test_encode_decode_roundtrip() {
        let original = BencodeValue::Dict({
            let mut map = HashMap::new();
            map.insert("num".to_string(), BencodeValue::Integer(123));
            map.insert("str".to_string(), BencodeValue::String(b"test".to_vec()));
            map
        });
        
        let encoded = encode(&original);
        let decoded = decode(&encoded).unwrap();
        assert_eq!(original, decoded);
    }
}
