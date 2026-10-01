///|
/// Count ASCII output code units for a value without constructing the encoded
/// string. The temporary UTF-8 byte array is at most the input's byte length.
fn measure_value_encoding(
  input : String,
  allow_reserved : Bool,
  limit : Int,
) -> Result[Int, ExpandError] {
  if limit < 0 {
    return Err(OutputTooLong)
  }
  let bytes = @utf8.encode(input)
  let mut i = 0
  let mut used = 0
  while i < bytes.length() {
    let code = bytes[i].to_int()
    if is_unreserved(code) || (allow_reserved && is_reserved(code)) {
      if used >= limit {
        return Err(OutputTooLong)
      }
      used += 1
    } else if allow_reserved &&
      code == 37 &&
      i + 2 < bytes.length() &&
      is_hex(bytes[i + 1].to_int()) &&
      is_hex(bytes[i + 2].to_int()) {
      if used > limit - 3 {
        return Err(OutputTooLong)
      }
      used += 3
      i += 2
    } else {
      if used > limit - 3 {
        return Err(OutputTooLong)
      }
      used += 3
    }
    i += 1
  }
  Ok(used)
}

///|
fn measure_literal_encoding(
  input : String,
  limit : Int,
) -> Result[Int, ExpandError] {
  if limit < 0 {
    return Err(OutputTooLong)
  }
  let bytes = @utf8.encode(input)
  let mut used = 0
  for byte in bytes {
    let code = byte.to_int()
    let extra = if is_unreserved(code) || is_reserved(code) || code == 37 {
      1
    } else {
      3
    }
    if used > limit - extra {
      return Err(OutputTooLong)
    }
    used += extra
  }
  Ok(used)
}
