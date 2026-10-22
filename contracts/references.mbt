///|
priv struct Resolver {
  documents : Map[String, Json]
  dependencies : Map[String, Bool]
  active : Map[String, Bool]
  mut expanded : Int32
  limits : WorkspaceLimits
}

///|
fn pointer(root : Json, fragment : String) -> Json raise WorkspaceError {
  if fragment == "" {
    return root
  }
  need(
    fragment.has_prefix("/"),
    "$ref",
    "only JSON Pointer fragments are supported",
  )
  let mut value = root
  for raw in fragment[1:].to_owned().split("/") {
    let token = raw.to_owned()
    let mut i = 0
    while i < token.length() {
      if token.code_unit_at(i).to_int() == 126 {
        need(
          i + 1 < token.length() &&
          (
            token.code_unit_at(i + 1).to_int() == 48 ||
            token.code_unit_at(i + 1).to_int() == 49
          ),
          "$ref",
          "invalid pointer escape",
        )
        i += 1
      }
      i += 1
    }
    let key = token
      .replace_all(old="~1", new="/")
      .replace_all(old="~0", new="~")
    value = match value {
      Object(fields) => field(fields, key, "$ref")
      Array(items) => {
        need(
          key != "" && (key == "0" || !key.has_prefix("0")),
          "$ref",
          "invalid array pointer index",
        )
        let mut index = 0
        for unit in key {
          let digit = unit.to_int() - 48
          need(
            digit >= 0 && digit <= 9 && index <= (2147483647 - digit) / 10,
            "$ref",
            "invalid array pointer index",
          )
          index = index * 10 + digit
        }
        need(index < items.length(), "$ref", "array pointer out of range")
        items[index]
      }
      _ => {
        invalid("$ref", "schema pointer must select object members")
        Json::null()
      }
    }
  }
  value
}

///|
fn Resolver::schema(
  self : Resolver,
  input : Json,
  base : String?,
  depth : Int32,
) -> Json raise WorkspaceError {
  if depth > self.limits.depth {
    raise Budget("reference_depth")
  }
  if self.expanded >= self.limits.resolved_nodes {
    raise Budget("resolved_nodes")
  }
  self.expanded += 1
  if input is True || input is False {
    return input
  }
  let fields = object(input, "schema")
  let result : Map[String, Json] = Map([])
  let maps = ["properties", "patternProperties", "$defs", "dependentSchemas"]
  let singles = [
    "items", "additionalProperties", "contains", "not", "if", "then", "else", "propertyNames",
    "unevaluatedProperties", "unevaluatedItems",
  ]
  let lists = ["allOf", "anyOf", "oneOf", "prefixItems"]
  for key in names(fields) {
    let value = fields[key]
    if [
        "$id", "$anchor", "$dynamicRef", "$dynamicAnchor", "$recursiveRef", "$vocabulary",
      ].contains(key) {
      raise Unsupported(
        path=key,
        feature="schema scope rebasing or dynamic reference",
      )
    }
    if key == "$ref" {
      continue
    }
    if key == "$schema" {
      need(
        string(value, key) == "https://json-schema.org/draft/2020-12/schema",
        key,
        "only Draft2020-12 dialect",
      )
      result[key] = value
    } else if maps.contains(key) {
      let nested = object(value, key)
      let output = Map([])
      for name in names(nested) {
        if key == "patternProperties" {
          pattern_valid(name)
        }
        output[name] = self.schema(nested[name], base, depth + 1)
      }
      result[key] = Json::object(output)
    } else if singles.contains(key) {
      result[key] = self.schema(value, base, depth + 1)
    } else if lists.contains(key) {
      let output = []
      let items = array(value, key)
      need(!items.is_empty(), key, "empty schema applicator array")
      for item in items {
        output.push(self.schema(item, base, depth + 1))
      }
      result[key] = Json::array(output)
    } else {
      // Unknown assertion keywords cannot silently acquire pass semantics.
      let known = [
        "type", "enum", "const", "minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum",
        "multipleOf", "minLength", "maxLength", "pattern", "minItems", "maxItems",
        "uniqueItems", "minContains", "maxContains", "minProperties", "maxProperties",
        "required", "dependentRequired", "title", "description", "$comment", "default",
        "examples", "deprecated", "format", "readOnly", "writeOnly",
      ]
      if !known.contains(key) && !key.has_prefix("x-") {
        raise Unsupported(path=key, feature="unknown JSON Schema keyword")
      }
      if key == "readOnly" || key == "writeOnly" {
        need(
          value is False,
          key,
          "directional property annotations require an explicit request/response schema",
        )
      }
      check_assertion(key, value)
      result[key] = value
    }
  }
  match fields.get("$ref") {
    None => Json::object(result)
    Some(reference) => {
      let reference = string(reference, "$ref")
      let (document, fragment) = match reference.split_once("#") {
        Some((doc, frag)) => (doc.to_owned(), frag.to_owned())
        None => (reference, "")
      }
      let document = if document == "" {
        base.unwrap_or_else(() => {
          invalid("$ref", "local reference needs a named document")
          ""
        })
      } else {
        document
      }
      let source = self.documents
        .get(document)
        .unwrap_or_else(() => {
          invalid(
            "$ref", "reference is not present in the offline document lock",
          )
          Json::null()
        })
      let identity = document + "#" + fragment
      need(
        !self.active.contains(identity),
        "$ref",
        "cyclic schema references are not supported",
      )
      self.active[identity] = true
      self.dependencies[document] = true
      let resolved = self.schema(
        pointer(source, fragment),
        Some(document),
        depth + 1,
      )
      self.active.remove(identity) |> ignore
      if result.is_empty() {
        resolved
      } else {
        // Keep siblings at the OUTER location so unevaluatedProperties can see
        // annotations from the referenced schema. Two sibling allOf branches
        // would incorrectly isolate that annotation scope.
        let conjuncts = match result.get("allOf") {
          Some(value) => array(value, "allOf").copy()
          None => []
        }
        conjuncts.push(resolved)
        result["allOf"] = Json::array(conjuncts)
        Json::object(result)
      }
    }
  }
}

///|
fn Resolver::validator(
  self : Resolver,
  value : Json,
) -> (@schema.Schema, Json) raise WorkspaceError {
  let resolved = self.schema(value, None, 0)
  let validator = @schema.Schema::new(resolved) catch {
    _ => {
      invalid("schema", "JSON Schema definition was refused")
      abort("unreachable")
    }
  }
  (validator, resolved)
}
