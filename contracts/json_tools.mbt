///|
fn invalid(path : String, reason : String) -> Unit raise WorkspaceError {
  raise Invalid(path~, reason~)
}

///|
fn need(
  condition : Bool,
  path : String,
  reason : String,
) -> Unit raise WorkspaceError {
  if !condition {
    invalid(path, reason)
  }
}

///|
fn object(
  value : Json,
  path : String,
) -> Map[String, Json] raise WorkspaceError {
  match value {
    Object(fields) => fields
    _ => {
      invalid(path, "expected object")
      Map([])
    }
  }
}

///|
fn string(value : Json, path : String) -> String raise WorkspaceError {
  match value {
    String(text) => text
    _ => {
      invalid(path, "expected string")
      ""
    }
  }
}

///|
fn array(value : Json, path : String) -> Array[Json] raise WorkspaceError {
  match value {
    Array(items) => items
    _ => {
      invalid(path, "expected array")
      []
    }
  }
}

///|
fn field(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> Json raise WorkspaceError {
  fields
  .get(key)
  .unwrap_or_else(() => {
    invalid(path, "missing \{key}")
    Json::null()
  })
}

///|
fn flag(
  fields : Map[String, Json],
  key : String,
  fallback : Bool,
  path : String,
) -> Bool raise WorkspaceError {
  match fields.get(key) {
    None => fallback
    Some(True) => true
    Some(False) => false
    _ => {
      invalid(path, "\{key} must be boolean")
      false
    }
  }
}

///|
fn escape_pointer(text : String) -> String {
  text.replace_all(old="~", new="~0").replace_all(old="/", new="~1")
}

///|
fn child(path : String, key : String) -> String {
  path + "/" + escape_pointer(key)
}

///|
fn names(fields : Map[String, Json]) -> Array[String] {
  let result = []
  for key, _ in fields {
    result.push(key)
  }
  result.sort_by(fn(a, b) { a.lexical_compare(b) })
  result
}

///|
fn check_limits(limits : WorkspaceLimits) -> Unit raise WorkspaceError {
  need(
    limits.depth > 0 && limits.depth <= 128,
    "limits",
    "depth must be in 1..128",
  )
  for
    count in [
      limits.documents,
      limits.operations,
      limits.nodes,
      limits.text_units,
      limits.resolved_nodes,
      limits.cases,
      limits.findings,
    ] {
    need(count >= 0, "limits", "negative budget")
  }
}

///|
priv struct TreeBudget {
  mut nodes : Int32
  mut text : Int32
  limits : WorkspaceLimits
}

///|
fn TreeBudget::text(
  self : TreeBudget,
  text : String,
) -> Unit raise WorkspaceError {
  if text.length() > self.limits.text_units - self.text {
    raise Budget("text_units")
  }
  self.text += text.length()
  let mut i = 0
  while i < text.length() {
    let u = text.code_unit_at(i).to_int()
    if u >= 0xD800 && u <= 0xDBFF {
      need(i + 1 < text.length(), "unicode", "unpaired surrogate")
      let v = text.code_unit_at(i + 1).to_int()
      need(v >= 0xDC00 && v <= 0xDFFF, "unicode", "unpaired surrogate")
      i += 1
    } else {
      need(u < 0xDC00 || u > 0xDFFF, "unicode", "unpaired surrogate")
    }
    i += 1
  }
}

///|
// Bounded detachment also rejects cycles before recursively walking forever.
fn TreeBudget::copy(
  self : TreeBudget,
  value : Json,
  depth : Int32,
) -> Json raise WorkspaceError {
  if depth > self.limits.depth {
    raise Budget("depth")
  }
  if self.nodes >= self.limits.nodes {
    raise Budget("nodes")
  }
  self.nodes += 1
  match value {
    Object(fields) => {
      if fields.length() > self.limits.nodes - self.nodes {
        raise Budget("nodes")
      }
      let result = Map([])
      for key in names(fields) {
        self.text(key)
        result[key] = self.copy(fields[key], depth + 1)
      }
      Json::object(result)
    }
    Array(items) => {
      if items.length() > self.limits.nodes - self.nodes {
        raise Budget("nodes")
      }
      let result = []
      for item in items {
        result.push(self.copy(item, depth + 1))
      }
      Json::array(result)
    }
    String(text) => {
      self.text(text)
      value
    }
    Number(n, ..) => {
      need(!n.is_nan() && !n.is_inf(), "number", "nonfinite JSON number")
      // JSON Schema's upstream numeric domain is IEEE-754; do not imply exact
      // arbitrary-precision integer validation after JSON decoding.
      need(
        n.abs() <= 9007199254740991.0,
        "number",
        "outside safe numeric domain",
      )
      Json::number(n)
    }
    _ => value
  }
}

///|
fn detached(
  value : Json,
  limits : WorkspaceLimits,
) -> Json raise WorkspaceError {
  let budget = { nodes: 0, text: 0, limits, }
  budget.copy(value, 0)
}

///|
fn only(
  fields : Map[String, Json],
  allowed : Array[String],
  path : String,
) -> Unit raise WorkspaceError {
  for key, _ in fields {
    if !allowed.contains(key) && !key.has_prefix("x-") {
      raise Unsupported(path=child(path, key), feature="unsupported field")
    }
  }
}
