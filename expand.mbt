///|
/// Expand a precompiled template. The binding array rejects duplicate names
/// so one name cannot silently change value during an expansion.
pub fn Template::expand(
  self : Template,
  bindings : Array[(String, Value)],
  max_output? : Int = 1048576,
  max_bindings? : Int = 4096,
  max_value_length? : Int = 1048576,
  max_items? : Int = 4096,
) -> Result[String, ExpandError] {
  match
    self.expand_internal(
      bindings, max_output, max_bindings, max_value_length, max_items, false,
    ) {
    Ok(result) => Ok(result.text)
    Err(error) => Err(error)
  }
}

///|
fn Template::expand_internal(
  self : Template,
  bindings : Array[(String, Value)],
  max_output : Int,
  max_bindings : Int,
  max_value_length : Int,
  max_items : Int,
  collect_spans : Bool,
) -> Result[RenderedUri, ExpandError] {
  if max_output < 0 {
    return Err(OutputTooLong)
  }
  if max_value_length < 0 {
    return Err(InvalidLimit("max_value_length"))
  }
  if max_items < 0 {
    return Err(InvalidLimit("max_items"))
  }
  let values = match
    prepare_bindings(bindings, max_bindings, max_value_length, max_items) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let out = StringBuilder()
  let spans : Array[OutputSpan] = []
  let mut used = 0
  let mut source_cursor = 0
  for segment in self.segments {
    let (source_start, source_end, expression) = match segment {
      Literal(raw) => (source_cursor, source_cursor + raw.length(), false)
      Expression(_, _, start, end) => (start, end, true)
    }
    let text = match segment {
      Literal(raw) =>
        match encode_literal_limited(raw, max_output - used) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
      Expression(op, specs, _, _) =>
        match expand_expression(op, specs, values, max_output - used) {
          Ok(text) => text
          Err(error) => return Err(error)
        }
    }
    if text.length() > max_output - used {
      return Err(OutputTooLong)
    }
    out.write_string(text)
    if collect_spans {
      spans.push({
        source_start,
        source_end,
        output_start: used,
        output_end: used + text.length(),
        is_expression: expression,
      })
    }
    used += text.length()
    source_cursor = source_end
  }
  Ok({ text: out.to_string(), spans, })
}

///|
fn prepare_bindings(
  bindings : Array[(String, Value)],
  max_bindings : Int,
  max_value_length : Int,
  max_items : Int,
) -> Result[Map[String, Value], ExpandError] {
  if max_bindings < 0 || bindings.length() > max_bindings {
    return Err(TooManyBindings)
  }
  let values : Map[String, Value] = Map([])
  for binding in bindings {
    let (name, value) = binding
    if values.contains(name) {
      return Err(DuplicateVariable(name))
    }
    match check_value(value, name, max_value_length, max_items) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    values[name] = value
  }
  Ok(values)
}

///|
fn check_text(
  text : String,
  name : String,
  max_value_length : Int,
) -> Result[Unit, ExpandError] {
  if max_value_length < 0 || text.length() > max_value_length {
    Err(ValueTooLong(name))
  } else if first_invalid_utf16(text) is Some(_) {
    Err(InvalidValue(name))
  } else {
    Ok(())
  }
}

///|
fn check_value(
  value : Value,
  name : String,
  max_value_length : Int,
  max_items : Int,
) -> Result[Unit, ExpandError] {
  match value {
    Scalar(text) => check_text(text, name, max_value_length)
    List(items) => {
      if max_items < 0 || items.length() > max_items {
        return Err(TooManyItems(name))
      }
      for item in items {
        match check_text(item, name, max_value_length) {
          Ok(_) => ()
          Err(error) => return Err(error)
        }
      }
      Ok(())
    }
    Assoc(entries) => {
      if max_items < 0 || entries.length() > max_items {
        return Err(TooManyItems(name))
      }
      for entry in entries {
        let (key, item) = entry
        match check_text(key, name, max_value_length) {
          Ok(_) => ()
          Err(error) => return Err(error)
        }
        match check_text(item, name, max_value_length) {
          Ok(_) => ()
          Err(error) => return Err(error)
        }
      }
      Ok(())
    }
    SparseList(items) => {
      if max_items < 0 || items.length() > max_items {
        return Err(TooManyItems(name))
      }
      for item in items {
        match item {
          Some(text) =>
            match check_text(text, name, max_value_length) {
              Ok(_) => ()
              Err(error) => return Err(error)
            }
          None => ()
        }
      }
      Ok(())
    }
    SparseAssoc(entries) => {
      if max_items < 0 || entries.length() > max_items {
        return Err(TooManyItems(name))
      }
      for entry in entries {
        let (key, item) = entry
        match check_text(key, name, max_value_length) {
          Ok(_) => ()
          Err(error) => return Err(error)
        }
        match item {
          Some(text) =>
            match check_text(text, name, max_value_length) {
              Ok(_) => ()
              Err(error) => return Err(error)
            }
          None => ()
        }
      }
      Ok(())
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
priv struct PieceBuffer {
  pieces : Array[String]
  separator : String
  limit : Int
  mut used : Int
}

///|
fn PieceBuffer::new(separator : String, limit : Int) -> PieceBuffer {
  { pieces: [], separator, limit, used: 0, }
}

///|
fn PieceBuffer::push(
  self : PieceBuffer,
  piece : String,
) -> Result[Unit, ExpandError] {
  let extra = if self.pieces.is_empty() { 0 } else { self.separator.length() }
  if self.used > self.limit - extra ||
    piece.length() > self.limit - extra - self.used {
    return Err(OutputTooLong)
  }
  self.pieces.push(piece)
  self.used += extra + piece.length()
  Ok(())
}

///|
fn PieceBuffer::join(self : PieceBuffer) -> String {
  join_text(self.pieces, self.separator)
}

///|
fn expand_expression(
  op : Operator,
  specs : Array[VarSpec],
  values : Map[String, Value],
  limit : Int,
) -> Result[String, ExpandError] {
  let prefix = operator_prefix(op)
  let pieces = PieceBuffer::new(operator_separator(op), limit - prefix.length())
  for spec in specs {
    match values.get(spec.name) {
      None => ()
      Some(value) =>
        match expand_variable(op, spec, value, limit) {
          Ok(items) =>
            for item in items {
              match pieces.push(item) {
                Ok(_) => ()
                Err(error) => return Err(error)
              }
            }
          Err(error) => return Err(error)
        }
    }
  }
  if pieces.pieces.is_empty() {
    Ok("")
  } else {
    Ok(prefix + pieces.join())
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
  limit : Int,
) -> Result[Array[String], ExpandError] {
  let reserved = operator_allows_reserved(op)
  match value {
    Scalar(raw) => {
      let selected = match spec.prefix {
        None => raw
        Some(length) => scalar_prefix(raw, length)
      }
      let encoded = match encode_value_limited(selected, reserved, limit) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let piece = named_piece(op, spec.name, encoded)
      if piece.length() > limit {
        Err(OutputTooLong)
      } else {
        Ok([piece])
      }
    }
    List(items) => {
      if spec.prefix is Some(_) {
        return Err(InvalidValue(spec.name))
      }
      if items.is_empty() {
        return Ok([])
      }
      if spec.explode {
        let pieces = PieceBuffer::new(operator_separator(op), limit)
        for item in items {
          let encoded = match encode_value_limited(item, reserved, limit) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          match pieces.push(named_piece(op, spec.name, encoded)) {
            Ok(_) => ()
            Err(error) => return Err(error)
          }
        }
        Ok(pieces.pieces)
      } else {
        let encoded = PieceBuffer::new(",", limit)
        for item in items {
          let value = match encode_value_limited(item, reserved, limit) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          match encoded.push(value) {
            Ok(_) => ()
            Err(error) => return Err(error)
          }
        }
        let piece = named_piece(op, spec.name, encoded.join())
        if piece.length() > limit {
          Err(OutputTooLong)
        } else {
          Ok([piece])
        }
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
        let pieces = PieceBuffer::new(operator_separator(op), limit)
        for entry in entries {
          let (name, item) = entry
          let key = match encode_value_limited(name, reserved, limit) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          let encoded = match encode_value_limited(item, reserved, limit) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          let piece = if encoded == "" && !operator_form(op) {
            key
          } else {
            key + "=" + encoded
          }
          match pieces.push(piece) {
            Ok(_) => ()
            Err(error) => return Err(error)
          }
        }
        Ok(pieces.pieces)
      } else {
        let encoded = PieceBuffer::new(",", limit)
        for entry in entries {
          let (name, item) = entry
          let key = match encode_value_limited(name, reserved, limit) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          match encoded.push(key) {
            Ok(_) => ()
            Err(error) => return Err(error)
          }
          let value = match encode_value_limited(item, reserved, limit) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          match encoded.push(value) {
            Ok(_) => ()
            Err(error) => return Err(error)
          }
        }
        let piece = named_piece(op, spec.name, encoded.join())
        if piece.length() > limit {
          Err(OutputTooLong)
        } else {
          Ok([piece])
        }
      }
    }
    SparseList(items) => {
      let defined : Array[String] = []
      for item in items {
        match item {
          Some(text) => defined.push(text)
          None => ()
        }
      }
      expand_variable(op, spec, List(defined), limit)
    }
    SparseAssoc(entries) => {
      let defined : Array[(String, String)] = []
      for entry in entries {
        let (name, item) = entry
        match item {
          Some(text) => defined.push((name, text))
          None => ()
        }
      }
      expand_variable(op, spec, Assoc(defined), limit)
    }
  }
}
