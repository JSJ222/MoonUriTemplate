///|
/// A JSON tree cannot be converted to URI Template values under this adapter.
/// Only strings, null, arrays of strings/null, and objects of strings/null
/// are accepted. Numeric and boolean coercion is deliberately left to callers.
pub(all) enum JsonBridgeError {
  RootMustBeObject
  UnsupportedValue(String)
}

///|
pub fn JsonBridgeError::code(self : JsonBridgeError) -> String {
  match self {
    RootMustBeObject => "root_must_be_object"
    UnsupportedValue(_) => "unsupported_value"
  }
}

///|
pub fn JsonBridgeError::path(self : JsonBridgeError) -> String {
  match self {
    RootMustBeObject => ""
    UnsupportedValue(path) => path
  }
}

///|
fn pointer_escape(input : String) -> String {
  let out = StringBuilder()
  for ch in input {
    if ch == '~' {
      out.write_string("~0")
    } else if ch == '/' {
      out.write_string("~1")
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn pointer_child(parent : String, name : String) -> String {
  parent + "/" + pointer_escape(name)
}

///|
/// Convert one JSON value. JSON null is an undefined variable or member.
pub fn value_from_json(
  input : Json,
  path? : String = "",
) -> Result[Value?, JsonBridgeError] {
  match input {
    Null => Ok(None)
    String(text) => Ok(Some(Scalar(text)))
    Array(items) => {
      let converted : Array[String?] = []
      for i, item in items {
        match item {
          Null => converted.push(None)
          String(text) => converted.push(Some(text))
          _ => return Err(UnsupportedValue(pointer_child(path, i.to_string())))
        }
      }
      Ok(Some(SparseList(converted)))
    }
    Object(fields) => {
      let names : Array[String] = []
      for name, _ in fields {
        names.push(name)
      }
      names.sort()
      let converted : Array[(String, String?)] = []
      for name in names {
        match fields.get(name) {
          Some(Null) => converted.push((name, None))
          Some(String(text)) => converted.push((name, Some(text)))
          Some(_) => return Err(UnsupportedValue(pointer_child(path, name)))
          None => ()
        }
      }
      Ok(Some(SparseAssoc(converted)))
    }
    _ => Err(UnsupportedValue(path))
  }
}

///|
/// Convert a JSON object to ordered bindings. Object keys are sorted so
/// associative expansion is deterministic across MoonBit backends.
pub fn bindings_from_json(
  input : Json,
) -> Result[Array[(String, Value)], JsonBridgeError] {
  let fields = match input {
    Object(fields) => fields
    _ => return Err(RootMustBeObject)
  }
  let names : Array[String] = []
  for name, _ in fields {
    names.push(name)
  }
  names.sort()
  let bindings : Array[(String, Value)] = []
  for name in names {
    match fields.get(name) {
      None => ()
      Some(value) =>
        match value_from_json(value, path=pointer_child("", name)) {
          Ok(Some(converted)) => bindings.push((name, converted))
          Ok(None) => ()
          Err(error) => return Err(error)
        }
    }
  }
  Ok(bindings)
}
