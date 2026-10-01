///|
priv struct LengthPieces {
  separator_length : Int
  limit : Int
  mut used : Int
  mut count : Int
}

///|
fn LengthPieces::new(separator_length : Int, limit : Int) -> LengthPieces {
  { separator_length, limit, used: 0, count: 0, }
}

///|
fn LengthPieces::push(
  self : LengthPieces,
  length : Int,
) -> Result[Unit, ExpandError] {
  let separator = if self.count == 0 { 0 } else { self.separator_length }
  if length < 0 ||
    self.used > self.limit - separator ||
    length > self.limit - separator - self.used {
    return Err(OutputTooLong)
  }
  self.used += separator + length
  self.count += 1
  Ok(())
}

///|
fn measured_named_length(
  op : Operator,
  name : String,
  value_length : Int,
  limit : Int,
) -> Result[Int, ExpandError] {
  if !operator_named(op) {
    return Ok(value_length)
  }
  let overhead = if value_length == 0 && !operator_form(op) {
    name.length()
  } else {
    name.length() + 1
  }
  if overhead > limit || value_length > limit - overhead {
    Err(OutputTooLong)
  } else {
    Ok(overhead + value_length)
  }
}

///|
fn measured_pair_length(
  op : Operator,
  key_length : Int,
  value_length : Int,
  limit : Int,
) -> Result[Int, ExpandError] {
  let equal_sign = if value_length == 0 && !operator_form(op) { 0 } else { 1 }
  if key_length > limit - equal_sign ||
    value_length > limit - equal_sign - key_length {
    Err(OutputTooLong)
  } else {
    Ok(key_length + equal_sign + value_length)
  }
}

///|
fn measure_variable(
  op : Operator,
  spec : VarSpec,
  value : Value,
  pieces : LengthPieces,
) -> Result[Unit, ExpandError] {
  let reserved = operator_allows_reserved(op)
  let limit = pieces.limit
  match value {
    Scalar(raw) => {
      let selected = match spec.prefix {
        None => raw
        Some(length) => scalar_prefix(raw, length)
      }
      let encoded = match measure_value_encoding(selected, reserved, limit) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let length = match measured_named_length(op, spec.name, encoded, limit) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      pieces.push(length)
    }
    List(items) => {
      if spec.prefix is Some(_) {
        return Err(InvalidValue(spec.name))
      }
      if spec.explode {
        for item in items {
          let encoded = match measure_value_encoding(item, reserved, limit) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          let length = match
            measured_named_length(op, spec.name, encoded, limit) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          match pieces.push(length) {
            Ok(_) => ()
            Err(error) => return Err(error)
          }
        }
        Ok(())
      } else if !items.is_empty() {
        let values = LengthPieces::new(1, limit)
        for item in items {
          let encoded = match measure_value_encoding(item, reserved, limit) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          match values.push(encoded) {
            Ok(_) => ()
            Err(error) => return Err(error)
          }
        }
        let length = match
          measured_named_length(op, spec.name, values.used, limit) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        pieces.push(length)
      } else {
        Ok(())
      }
    }
    Assoc(entries) => {
      if spec.prefix is Some(_) {
        return Err(InvalidValue(spec.name))
      }
      if spec.explode {
        for entry in entries {
          let (name, item) = entry
          let key = match measure_value_encoding(name, reserved, limit) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          let encoded = match measure_value_encoding(item, reserved, limit) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          let length = match measured_pair_length(op, key, encoded, limit) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          match pieces.push(length) {
            Ok(_) => ()
            Err(error) => return Err(error)
          }
        }
        Ok(())
      } else if !entries.is_empty() {
        let values = LengthPieces::new(1, limit)
        for entry in entries {
          let (name, item) = entry
          let key = match measure_value_encoding(name, reserved, limit) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          let encoded = match measure_value_encoding(item, reserved, limit) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          match values.push(key) {
            Ok(_) => ()
            Err(error) => return Err(error)
          }
          match values.push(encoded) {
            Ok(_) => ()
            Err(error) => return Err(error)
          }
        }
        let length = match
          measured_named_length(op, spec.name, values.used, limit) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        pieces.push(length)
      } else {
        Ok(())
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
      measure_variable(op, spec, List(defined), pieces)
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
      measure_variable(op, spec, Assoc(defined), pieces)
    }
  }
}

///|
fn measure_expression(
  op : Operator,
  specs : Array[VarSpec],
  values : Map[String, Value],
  limit : Int,
) -> Result[Int, ExpandError] {
  let prefix_length = operator_prefix(op).length()
  let pieces = LengthPieces::new(
    operator_separator(op).length(),
    limit - prefix_length,
  )
  for spec in specs {
    match values.get(spec.name) {
      None => ()
      Some(value) =>
        match measure_variable(op, spec, value, pieces) {
          Ok(_) => ()
          Err(error) => return Err(error)
        }
    }
  }
  if pieces.count == 0 {
    Ok(0)
  } else {
    Ok(prefix_length + pieces.used)
  }
}

///|
/// Return the exact UTF-16 length of the expanded URI without constructing
/// its output string. This performs the same binding checks as `expand`.
pub fn Template::measure(
  self : Template,
  bindings : Array[(String, Value)],
  max_output? : Int = 1048576,
  max_bindings? : Int = 4096,
  max_value_length? : Int = 1048576,
  max_items? : Int = 4096,
) -> Result[Int, ExpandError] {
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
  let mut used = 0
  for segment in self.segments {
    let length = match segment {
      Literal(raw) =>
        match measure_literal_encoding(raw, max_output - used) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
      Expression(op, specs, _, _) =>
        match measure_expression(op, specs, values, max_output - used) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
    }
    if length > max_output - used {
      return Err(OutputTooLong)
    }
    used += length
  }
  Ok(used)
}
