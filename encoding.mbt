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
/// Prefix length counts Unicode scalar values, not UTF-16 units or bytes.
fn scalar_prefix(value : String, length : Int) -> String {
  let out = StringBuilder()
  let mut count = 0
  for ch in value {
    if count == length {
      break
    }
    out.write_char(ch)
    count += 1
  }
  out.to_string()
}
