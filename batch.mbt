///|
/// A bounded batch expansion failed before returning a partial result.
pub(all) enum BatchError {
  TooManyInputs
  TotalOutputTooLong
  InvalidItem(Int, ExpandError)
}

///|
pub fn BatchError::code(self : BatchError) -> String {
  match self {
    TooManyInputs => "too_many_inputs"
    TotalOutputTooLong => "total_output_too_long"
    InvalidItem(_, _) => "invalid_item"
  }
}

///|
/// Return the zero-based row number for a per-row expansion failure.
pub fn BatchError::index(self : BatchError) -> Int? {
  match self {
    InvalidItem(index, _) => Some(index)
    _ => None
  }
}

///|
/// Expand one compiled template for many independent value sets. The call is
/// fail-fast and atomic: no partial result escapes on error. An aggregate
/// output limit prevents an unbounded result even when each row is small.
pub fn Template::expand_many(
  self : Template,
  inputs : Array[Array[(String, Value)]],
  max_inputs? : Int = 4096,
  max_total_output? : Int = 16777216,
  max_each_output? : Int = 1048576,
) -> Result[Array[String], BatchError] {
  if max_inputs < 0 || inputs.length() > max_inputs {
    return Err(TooManyInputs)
  }
  if max_total_output < 0 || max_each_output < 0 {
    return Err(TotalOutputTooLong)
  }
  let outputs : Array[String] = []
  let mut used = 0
  for index, bindings in inputs {
    let output = match self.expand(bindings, max_output=max_each_output) {
      Ok(value) => value
      Err(error) => return Err(InvalidItem(index, error))
    }
    if output.length() > max_total_output - used {
      return Err(TotalOutputTooLong)
    }
    used += output.length()
    outputs.push(output)
  }
  Ok(outputs)
}
