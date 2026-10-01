///|
/// Compile an RFC 6570 Level 4 URI Template.
/// Limits and error offsets are measured in UTF-16 code units.
pub fn parse(
  input : String,
  max_length? : Int = 65536,
  max_expressions? : Int = 1024,
  max_variables? : Int = 4096,
  strict_literals? : Bool = true,
) -> Result[Template, ParseError] {
  if max_length < 0 || input.length() > max_length {
    return Err(InputTooLong)
  }
  match first_invalid_utf16(input) {
    Some(at) => return Err(InvalidUnicode(at))
    None => ()
  }
  let segments : Array[Segment] = []
  let variables : Array[String] = []
  let seen_variables : Map[String, Bool] = Map([])
  let mut i = 0
  let mut literal_start = 0
  let mut expressions = 0
  let mut variable_count = 0
  while i < input.length() {
    let unit = input[i].to_int()
    if unit == 123 {
      if i > literal_start {
        segments.push(Literal(input[literal_start:i].to_owned()))
      }
      expressions += 1
      if expressions > max_expressions || max_expressions < 0 {
        return Err(TooManyExpressions)
      }
      let start = i
      i += 1
      let expression_start = i
      while i < input.length() && input[i].to_int() != 125 {
        if input[i].to_int() == 123 {
          return Err(NestedExpression(i))
        }
        i += 1
      }
      if i == input.length() {
        return Err(UnclosedExpression(start))
      }
      if i == expression_start {
        return Err(EmptyExpression(start))
      }
      let expression = match parse_expression(input, expression_start, i) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      variable_count += expression.1.length()
      if variable_count > max_variables || max_variables < 0 {
        return Err(TooManyVariables)
      }
      for spec in expression.1 {
        if !seen_variables.contains(spec.name) {
          seen_variables[spec.name] = true
          variables.push(spec.name)
        }
      }
      segments.push(Expression(expression.0, expression.1))
      i += 1
      literal_start = i
    } else if unit == 125 {
      return Err(InvalidLiteral(i))
    } else {
      match validate_literal_unit(input, i, strict_literals) {
        Ok(next) => i = next
        Err(error) => return Err(error)
      }
    }
  }
  if literal_start < input.length() {
    segments.push(Literal(input[literal_start:].to_owned()))
  }
  Ok({ source: input, segments, variables })
}

///|
fn first_invalid_utf16(input : String) -> Int? {
  let mut i = 0
  while i < input.length() {
    let code = input[i].to_int()
    if code >= 0xD800 && code <= 0xDBFF {
      if i + 1 >= input.length() {
        return Some(i)
      }
      let next = input[i + 1].to_int()
      if next < 0xDC00 || next > 0xDFFF {
        return Some(i)
      }
      i += 2
    } else if code >= 0xDC00 && code <= 0xDFFF {
      return Some(i)
    } else {
      i += 1
    }
  }
  None
}

///|
fn is_hex(code : Int) -> Bool {
  (code >= 48 && code <= 57) ||
  (code >= 65 && code <= 70) ||
  (code >= 97 && code <= 102)
}

///|
fn is_alpha(code : Int) -> Bool {
  (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
}

///|
fn is_digit(code : Int) -> Bool {
  code >= 48 && code <= 57
}

///|
fn is_unreserved(code : Int) -> Bool {
  is_alpha(code) || is_digit(code) || code == 45 || code == 46 || code == 95 || code == 126
}

///|
fn is_reserved(code : Int) -> Bool {
  match code {
    33 | 35 | 36 | 38 | 39 | 40 | 41 | 42 | 43 | 44 | 47 | 58 | 59 | 61 | 63 | 64 | 91 | 93 => true
    _ => false
  }
}

///|
fn allowed_unicode_literal(code : Int) -> Bool {
  (code >= 0xA0 && code <= 0xD7FF) ||
  (code >= 0xE000 && code <= 0xFDCF) ||
  (code >= 0xFDF0 && code <= 0xFFEF) ||
  (code >= 0x10000 && code <= 0xDFFFD && (code & 0xFFFF) <= 0xFFFD) ||
  (code >= 0xE1000 && code <= 0xEFFFD && (code & 0xFFFF) <= 0xFFFD) ||
  (code >= 0xF0000 && code <= 0xFFFFD) ||
  (code >= 0x100000 && code <= 0x10FFFD)
}

///|
fn validate_literal_unit(
  input : String,
  at : Int,
  strict_literals : Bool,
) -> Result[Int, ParseError] {
  let code = input[at].to_int()
  if code == 37 {
    if at + 2 < input.length() && is_hex(input[at + 1].to_int()) && is_hex(input[at + 2].to_int()) {
      Ok(at + 3)
    } else {
      Err(InvalidLiteral(at))
    }
  } else if is_unreserved(code) ||
    (is_reserved(code) && (!strict_literals || code != 39)) {
    Ok(at + 1)
  } else if code >= 0xD800 && code <= 0xDBFF {
    let low = input[at + 1].to_int()
    let scalar = 0x10000 + ((code - 0xD800) << 10) + low - 0xDC00
    if allowed_unicode_literal(scalar) { Ok(at + 2) } else { Err(InvalidLiteral(at)) }
  } else if allowed_unicode_literal(code) {
    Ok(at + 1)
  } else {
    Err(InvalidLiteral(at))
  }
}

///|
fn parse_expression(
  input : String,
  start : Int,
  end : Int,
) -> Result[(Operator, Array[VarSpec]), ParseError] {
  let mut i = start
  let op = match input[i].to_int() {
    43 => { i += 1; Reserved }
    35 => { i += 1; Fragment }
    46 => { i += 1; Label }
    47 => { i += 1; Path }
    59 => { i += 1; PathParameter }
    63 => { i += 1; Query }
    38 => { i += 1; QueryContinuation }
    61 | 44 | 33 | 64 | 124 => return Err(InvalidOperator(i))
    _ => Simple
  }
  if i == end {
    return Err(EmptyExpression(start))
  }
  let specs : Array[VarSpec] = []
  while i < end {
    let parsed = match parse_varspec(input, i, end) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    specs.push(parsed.0)
    i = parsed.1
    if i < end {
      if input[i].to_int() != 44 {
        return Err(InvalidVariable(i))
      }
      i += 1
      if i == end {
        return Err(InvalidVariable(i))
      }
    }
  }
  Ok((op, specs))
}

///|
fn parse_varspec(
  input : String,
  start : Int,
  end : Int,
) -> Result[(VarSpec, Int), ParseError] {
  let mut i = start
  let mut need_char = true
  while i < end {
    let code = input[i].to_int()
    if is_alpha(code) || is_digit(code) || code == 95 {
      need_char = false
      i += 1
    } else if code == 37 && i + 2 < end && is_hex(input[i + 1].to_int()) && is_hex(input[i + 2].to_int()) {
      need_char = false
      i += 3
    } else if code == 46 && !need_char {
      need_char = true
      i += 1
    } else {
      break
    }
  }
  if i == start || need_char {
    return Err(InvalidVariable(i))
  }
  let name = input[start:i].to_owned()
  let mut prefix : Int? = None
  let mut explode = false
  if i < end && input[i].to_int() == 58 {
    i += 1
    let digit_start = i
    let mut length = 0
    while i < end && is_digit(input[i].to_int()) {
      length = length * 10 + input[i].to_int() - 48
      i += 1
      if i - digit_start > 4 {
        return Err(InvalidModifier(i))
      }
    }
    if i == digit_start || input[digit_start].to_int() == 48 || length > 9999 {
      return Err(InvalidModifier(digit_start))
    }
    prefix = Some(length)
  } else if i < end && input[i].to_int() == 42 {
    explode = true
    i += 1
  }
  if i < end && input[i].to_int() != 44 {
    return Err(InvalidModifier(i))
  }
  Ok(({ name, prefix, explode }, i))
}
