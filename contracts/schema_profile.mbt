///|
// Schema::new indexes a document but does not meta-validate every keyword.
// Reject malformed supported assertions here rather than silently ignoring a
// wrong type in the interpreter. This is the profile's definition gate, not a
// claim to implement the complete JSON Schema metaschema/vocabulary system.
fn unique_strings(
  value : Json,
  path : String,
  nonempty : Bool,
) -> Array[String] raise WorkspaceError {
  let values = array(value, path)
  need(!nonempty || !values.is_empty(), path, "empty assertion array")
  let seen : Map[String, Bool] = Map([])
  let result = []
  for item in values {
    let name = string(item, path)
    need(!seen.contains(name), path, "duplicate assertion member")
    seen[name] = true
    result.push(name)
  }
  result
}

///|
fn pattern_valid(pattern : String) -> Unit raise WorkspaceError {
  let _ = @string.Regex::Regex(pattern[:]) catch {
    _ => {
      invalid("pattern", "invalid or unsupported regular expression")
      abort("unreachable")
    }
  }
}

///|
fn check_assertion(key : String, value : Json) -> Unit raise WorkspaceError {
  if key == "type" {
    let types = if value is String(text) {
      [text]
    } else {
      unique_strings(value, key, true)
    }
    for item in types {
      need(
        ["null", "boolean", "object", "array", "number", "integer", "string"].contains(
          item,
        ),
        key,
        "unknown JSON type",
      )
    }
  } else if key == "required" {
    unique_strings(value, key, false) |> ignore
  } else if key == "dependentRequired" {
    for _, names in object(value, key) {
      unique_strings(names, key, false) |> ignore
    }
  } else if key == "enum" {
    let values = array(value, key)
    need(!values.is_empty(), key, "empty enum")
    if values.length() > 1024 {
      raise Budget("enum_members")
    }
    for i in 0..<values.length() {
      for j in 0..<i {
        need(values[i] != values[j], key, "duplicate enum value")
      }
    }
  } else if [
      "minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum", "multipleOf",
    ].contains(key) {
    guard value is Number(n, ..) else {
      invalid(key, "expected numeric bound")
      return
    }
    if key == "multipleOf" {
      need(n > 0, key, "multipleOf must be positive")
    }
  } else if [
      "minLength", "maxLength", "minItems", "maxItems", "minContains", "maxContains",
      "minProperties", "maxProperties",
    ].contains(key) {
    guard value is Number(n, ..) else {
      invalid(key, "expected nonnegative integer bound")
      return
    }
    need(
      n >= 0 && n <= 2147483647.0 && n.to_int().to_double() == n,
      key,
      "bound outside nonnegative Int32 profile",
    )
  } else if ["uniqueItems", "deprecated"].contains(key) {
    need(value is True || value is False, key, "expected boolean")
  } else if ["title", "description", "$comment", "format", "pattern"].contains(
      key,
    ) {
    let text = string(value, key)
    if key == "pattern" {
      pattern_valid(text)
    }
  } else if key == "examples" {
    array(value, key) |> ignore
  }
}
