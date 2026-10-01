///|
/// Expand a precompiled template. The binding array rejects duplicate names
/// so one name cannot silently change value during an expansion.
pub fn Template::expand(
  self : Template,
  bindings : Array[(String, Value)],
  max_output? : Int = 1048576,
) -> Result[String, ExpandError] {
  if max_output < 0 {
    return Err(OutputTooLong)
  }
  let values : Map[String, Value] = Map([])
  for binding in bindings {
    let (name, value) = binding
    if values.contains(name) {
      return Err(DuplicateVariable(name))
    }
    if !valid_value(value) {
      return Err(InvalidValue(name))
    }
    values[name] = value
  }
  let out = StringBuilder()
  let mut used = 0
  for segment in self.segments {
    let text = match segment {
      Literal(raw) => encode_literal(raw)
      Expression(op, specs) => match expand_expression(op, specs, values) {
        Ok(text) => text
        Err(error) => return Err(error)
      }
    }
    if text.length() > max_output - used {
      return Err(OutputTooLong)
    }
    out.write_string(text)
    used += text.length()
  }
  Ok(out.to_string())
}

///|
/// Parse and expand in one call for single-use templates.
pub fn expand(
  source : String,
  bindings : Array[(String, Value)],
  max_output? : Int = 1048576,
) -> Result[String, String] {
  let template = match parse(source) {
    Ok(template) => template
    Err(_) => return Err("invalid template")
  }
  match template.expand(bindings, max_output~) {
    Ok(text) => Ok(text)
    Err(_) => Err("expansion failed")
  }
}

///|
fn valid_value(value : Value) -> Bool {
  match value {
    Scalar(text) => first_invalid_utf16(text) is None
    List(items) => {
      for item in items {
        if first_invalid_utf16(item) is Some(_) {
          return false
        }
      }
      true
    }
    Assoc(entries) => {
      for entry in entries {
        let (name, item) = entry
        if first_invalid_utf16(name) is Some(_) || first_invalid_utf16(item) is Some(_) {
          return false
        }
      }
      true
    }
  }
}

///|
fn operator_prefix(op : Operator) -> String {
  match op {
    Simple | Reserved => ""
    Fragment => "#"
    Label => "."
    Path => "/"
    PathParameter => ";"
    Query => "?"
    QueryContinuation => "&"
  }
}

///|
fn operator_separator(op : Operator) -> String {
  match op {
    Simple | Reserved | Fragment => ","
    Label => "."
    Path => "/"
    PathParameter => ";"
    Query | QueryContinuation => "&"
  }
}

///|
fn operator_named(op : Operator) -> Bool {
  match op {
    PathParameter | Query | QueryContinuation => true
    _ => false
  }
}

///|
fn operator_form(op : Operator) -> Bool {
  op is Query || op is QueryContinuation
}

///|
fn operator_allows_reserved(op : Operator) -> Bool {
  op is Reserved || op is Fragment
}

///|
fn join_text(parts : Array[String], separator : String) -> String {
  let out = StringBuilder()
  for i, part in parts {
    if i > 0 {
      out.write_string(separator)
    }
    out.write_string(part)
  }
  out.to_string()
}

///|
fn expand_expression(
  op : Operator,
  specs : Array[VarSpec],
  values : Map[String, Value],
) -> Result[String, ExpandError] {
  let pieces : Array[String] = []
  for spec in specs {
    match values.get(spec.name) {
      None => ()
      Some(value) => match expand_variable(op, spec, value) {
        Ok(items) => for item in items { pieces.push(item) }
        Err(error) => return Err(error)
      }
    }
  }
  if pieces.is_empty() {
    Ok("")
  } else {
    Ok(operator_prefix(op) + join_text(pieces, operator_separator(op)))
  }
}

///|
fn named_piece(op : Operator, name : String, value : String) -> String {
  if !operator_named(op) {
    return value
  }
  if value == "" && !operator_form(op) {
    name
  } else {
    name + "=" + value
  }
}

///|
fn expand_variable(
  op : Operator,
  spec : VarSpec,
  value : Value,
) -> Result[Array[String], ExpandError] {
  let reserved = operator_allows_reserved(op)
  match value {
    Scalar(raw) => {
      let selected = match spec.prefix {
        None => raw
        Some(length) => scalar_prefix(raw, length)
      }
      Ok([named_piece(op, spec.name, encode_value(selected, reserved))])
    }
    List(items) => {
      if spec.prefix is Some(_) {
        return Err(InvalidValue(spec.name))
      }
      if items.is_empty() {
        return Ok([])
      }
      if spec.explode {
        let pieces : Array[String] = []
        for item in items {
          pieces.push(named_piece(op, spec.name, encode_value(item, reserved)))
        }
        Ok(pieces)
      } else {
        let encoded : Array[String] = []
        for item in items {
          encoded.push(encode_value(item, reserved))
        }
        Ok([named_piece(op, spec.name, join_text(encoded, ","))])
      }
    }
    Assoc(entries) => {
      if spec.prefix is Some(_) {
        return Err(InvalidValue(spec.name))
      }
      if entries.is_empty() {
        return Ok([])
      }
      if spec.explode {
        let pieces : Array[String] = []
        for entry in entries {
          let (name, item) = entry
          let key = encode_value(name, reserved)
          let encoded = encode_value(item, reserved)
          if encoded == "" && !operator_form(op) {
            pieces.push(key)
          } else {
            pieces.push(key + "=" + encoded)
          }
        }
        Ok(pieces)
      } else {
        let encoded : Array[String] = []
        for entry in entries {
          let (name, item) = entry
          encoded.push(encode_value(name, reserved))
          encoded.push(encode_value(item, reserved))
        }
        Ok([named_piece(op, spec.name, join_text(encoded, ","))])
      }
    }
  }
}
