///|
fn hex_digit(value : Int) -> Char {
  if value < 10 { (48 + value).unsafe_to_char() } else { (55 + value).unsafe_to_char() }
}

///|
fn pct_byte(out : StringBuilder, value : Int) -> Unit {
  out.write_char('%')
  out.write_char(hex_digit(value >> 4))
  out.write_char(hex_digit(value & 15))
}

///|
/// Encode a value as RFC 3986 percent-encoded UTF-8. Reserved expansion keeps
/// reserved ASCII characters and already-valid percent triplets.
fn encode_value(input : String, allow_reserved : Bool) -> String {
  let bytes = @utf8.encode(input)
  let out = StringBuilder()
  let mut i = 0
  while i < bytes.length() {
    let code = bytes[i].to_int()
    if is_unreserved(code) || (allow_reserved && is_reserved(code)) {
      out.write_char(code.unsafe_to_char())
    } else if allow_reserved && code == 37 && i + 2 < bytes.length() &&
      is_hex(bytes[i + 1].to_int()) && is_hex(bytes[i + 2].to_int()) {
      out.write_char('%')
      out.write_char(bytes[i + 1].to_int().unsafe_to_char())
      out.write_char(bytes[i + 2].to_int().unsafe_to_char())
      i += 2
    } else {
      pct_byte(out, code)
    }
    i += 1
  }
  out.to_string()
}

///|
/// Literals preserve URI punctuation and existing percent triplets. The
/// parser has already rejected malformed triplets and unpaired surrogates.
fn encode_literal(input : String) -> String {
  let bytes = @utf8.encode(input)
  let out = StringBuilder()
  for byte in bytes {
    let code = byte.to_int()
    if is_unreserved(code) || is_reserved(code) || code == 37 {
      out.write_char(code.unsafe_to_char())
    } else {
      pct_byte(out, code)
    }
  }
  out.to_string()
}

///|
fn hex_value(code : Int) -> Int {
  if code >= 48 && code <= 57 {
    code - 48
  } else if code >= 65 && code <= 70 {
    code - 55
  } else {
    code - 87
  }
}

///|
fn triplet_byte(value : String, start : Int) -> Int? {
  if start + 2 < value.length() && value[start].to_int() == 37 &&
    is_hex(value[start + 1].to_int()) && is_hex(value[start + 2].to_int()) {
    Some(hex_value(value[start + 1].to_int()) * 16 + hex_value(value[start + 2].to_int()))
  } else {
    None
  }
}

///|
fn continuation(value : String, start : Int, lower : Int, upper : Int) -> Bool {
  match triplet_byte(value, start) {
    Some(byte) => byte >= lower && byte <= upper
    None => false
  }
}

///|
/// A valid encoded UTF-8 character is one prefix unit even though it may
/// contain two, three, or four percent triplets.
fn encoded_character_end(value : String, start : Int) -> Int? {
  let lead = match triplet_byte(value, start) {
    Some(byte) => byte
    None => return None
  }
  if lead <= 0x7F {
    return Some(start + 3)
  }
  if lead >= 0xC2 && lead <= 0xDF && continuation(value, start + 3, 0x80, 0xBF) {
    return Some(start + 6)
  }
  if lead >= 0xE0 && lead <= 0xEF {
    let second_lower = if lead == 0xE0 { 0xA0 } else { 0x80 }
    let second_upper = if lead == 0xED { 0x9F } else { 0xBF }
    if continuation(value, start + 3, second_lower, second_upper) &&
      continuation(value, start + 6, 0x80, 0xBF) {
      return Some(start + 9)
    }
  }
  if lead >= 0xF0 && lead <= 0xF4 {
    let second_lower = if lead == 0xF0 { 0x90 } else { 0x80 }
    let second_upper = if lead == 0xF4 { 0x8F } else { 0xBF }
    if continuation(value, start + 3, second_lower, second_upper) &&
      continuation(value, start + 6, 0x80, 0xBF) &&
      continuation(value, start + 9, 0x80, 0xBF) {
      return Some(start + 12)
    }
  }
  Some(start + 3)
}

///|
/// Prefix length counts Unicode scalar values, not UTF-16 units or bytes.
/// Well-formed percent-encoded UTF-8 sequences remain whole prefix units.
fn scalar_prefix(value : String, length : Int) -> String {
  let mut index = 0
  let mut count = 0
  while index < value.length() && count < length {
    let unit = value[index].to_int()
    if unit == 37 {
      match encoded_character_end(value, index) {
        Some(end) => { index = end; count += 1; continue }
        None => ()
      }
    }
    if unit >= 0xD800 && unit <= 0xDBFF {
      index += 2
    } else {
      index += 1
    }
    count += 1
  }
  value[:index].to_owned()
}
