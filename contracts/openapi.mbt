///|
// Rebase only actual schema locations, never enum/const/default example data.
fn import_schema(
  value : Json,
  base : String,
  depth : Int32,
  limits : WorkspaceLimits,
) -> Json raise WorkspaceError {
  if depth > limits.depth {
    raise Budget("depth")
  }
  if value is True || value is False {
    return value
  }
  let fields = object(value, "schema")
  let output = fields.copy()
  for key in names(fields) {
    let value = fields[key]
    if key == "$ref" {
      let reference = string(value, "$ref")
      if reference.has_prefix("#") {
        need(
          reference.has_prefix("#/components/schemas/"),
          "$ref",
          "local OpenAPI references must select components/schemas",
        )
        output[key] = Json::string(base + reference)
      }
    } else if ["properties", "patternProperties", "$defs", "dependentSchemas"].contains(
        key,
      ) {
      let nested = object(value, key)
      let mapped = Map([])
      for name in names(nested) {
        mapped[name] = import_schema(nested[name], base, depth + 1, limits)
      }
      output[key] = Json::object(mapped)
    } else if [
        "items", "additionalProperties", "contains", "not", "if", "then", "else",
        "propertyNames", "unevaluatedProperties", "unevaluatedItems",
      ].contains(key) {
      output[key] = import_schema(value, base, depth + 1, limits)
    } else if ["allOf", "anyOf", "oneOf", "prefixItems"].contains(key) {
      let mapped = []
      for item in array(value, key) {
        mapped.push(import_schema(item, base, depth + 1, limits))
      }
      output[key] = Json::array(mapped)
    }
  }
  Json::object(output)
}

///|
fn import_parameters(
  value : Json?,
  base : String,
  limits : WorkspaceLimits,
) -> Array[Json] raise WorkspaceError {
  let result = []
  let seen : Map[String, Bool] = Map([])
  if value is Some(value) {
    for item in array(value, "parameters") {
      let fields = object(item, "parameter")
      only(
        fields,
        ["name", "in", "required", "schema", "description", "deprecated"],
        "parameter",
      )
      let name = string(field(fields, "name", "parameter"), "name")
      let place = location(string(field(fields, "in", "parameter"), "in"))
      let key = parameter_key(place, name)
      need(
        !seen.contains(key),
        "parameters",
        "duplicate parameter identity within one level",
      )
      seen[key] = true
      let output = fields.copy()
      output["schema"] = import_schema(
        field(fields, "schema", "parameter"),
        base,
        0,
        limits,
      )
      result.push(Json::object(output))
    }
  }
  result
}

///|
fn import_content(
  value : Json,
  base : String,
  limits : WorkspaceLimits,
  request : Bool,
) -> Json raise WorkspaceError {
  let fields = object(value, "content")
  only(
    fields,
    if request {
      ["required", "content", "description"]
    } else {
      ["content", "description", "headers"]
    },
    "content",
  )
  let output = fields.copy()
  if fields.get("content") is Some(value) {
    let media = object(value, "content")
    let result : Map[String, Json] = Map([])
    for name in names(media) {
      let entry = object(media[name], "media")
      only(entry, ["schema", "example", "examples"], "media")
      result[name] = {
        "schema": import_schema(
          field(entry, "schema", "media"),
          base,
          0,
          limits,
        ),
      }
    }
    output["content"] = Json::object(result)
  }
  if fields.get("headers") is Some(value) {
    let headers = object(value, "headers")
    let result = Map([])
    for name in names(headers) {
      let entry = object(headers[name], "header")
      only(entry, ["schema", "required", "description"], "header")
      let mapped = entry.copy()
      mapped["schema"] = import_schema(
        field(entry, "schema", "header"),
        base,
        0,
        limits,
      )
      result[name] = Json::object(mapped)
    }
    output["headers"] = Json::object(result)
  }
  Json::object(output)
}

///|
/// Import the explicitly supported OpenAPI 3.1 JSON subset into an offline
/// schema lock. Operations are extracted once; edit operation declarations by
/// reimporting, not by updating schema documents. The named main lock contains
/// ONLY components/schemas, so schema revision cannot silently edit operations.
/// No HTTP I/O, YAML, authentication, raw wire decoding, or automatic fetching.
pub fn import_openapi(
  document : Json,
  document_id : String,
  documents~ : Map[String, Json] = Map([]),
  limits~ : WorkspaceLimits = WorkspaceLimits::default(),
) -> Workspace raise WorkspaceError {
  check_limits(limits)
  need(
    document_id != "" && !document_id.contains("#"),
    "document_id",
    "expected fragment-free document ID",
  )
  let input = object(detached(document, limits), "openapi")
  only(
    input,
    [
      "openapi", "info", "paths", "components", "servers", "tags", "externalDocs",
      "jsonSchemaDialect",
    ],
    "openapi",
  )
  let version = string(field(input, "openapi", "openapi"), "openapi")
  need(
    ["3.1.0", "3.1.1", "3.1.2"].contains(version),
    "openapi",
    "only OpenAPI 3.1 JSON is supported",
  )
  if input.get("jsonSchemaDialect") is Some(dialect) {
    need(
      string(dialect, "jsonSchemaDialect") ==
      "https://json-schema.org/draft/2020-12/schema",
      "jsonSchemaDialect",
      "unsupported explicit dialect",
    )
  }
  let _ = object(field(input, "info", "openapi"), "info")
  let locks = documents.copy()
  need(
    !locks.contains(document_id),
    "documents",
    "main document ID already exists",
  )
  let schemas = Map([])
  if input.get("components") is Some(value) {
    let components = object(value, "components")
    only(components, ["schemas"], "components")
    if components.get("schemas") is Some(value) {
      let source = object(value, "components.schemas")
      for name in names(source) {
        schemas[name] = import_schema(source[name], document_id, 0, limits)
      }
    }
  }
  locks[document_id] = { "components": { "schemas": Json::object(schemas) } }
  let operations : Array[Json] = []
  let paths = object(field(input, "paths", "openapi"), "paths")
  for path in names(paths) {
    if path.has_prefix("x-") {
      continue
    }
    let item = object(paths[path], "pathItem")
    only(
      item,
      [
        "summary", "description", "parameters", "get", "put", "post", "delete", "options",
        "head", "patch", "trace",
      ],
      "pathItem",
    )
    let inherited = import_parameters(
      item.get("parameters"),
      document_id,
      limits,
    )
    for
      verb in [
        "get", "put", "post", "delete", "options", "head", "patch", "trace",
      ] {
      if item.get(verb) is Some(value) {
        let fields = object(value, "operation")
        only(
          fields,
          [
            "operationId", "parameters", "requestBody", "responses", "summary", "description",
            "deprecated", "tags", "externalDocs",
          ],
          "operation",
        )
        let overrides = import_parameters(
          fields.get("parameters"),
          document_id,
          limits,
        )
        let override_keys : Map[String, Bool] = Map([])
        for param in overrides {
          let fields = object(param, "parameter")
          override_keys[parameter_key(
            location(string(fields["in"], "in")),
            string(fields["name"], "name"),
          )] = true
        }
        let parameters = []
        for param in inherited {
          let fields = object(param, "parameter")
          let key = parameter_key(
            location(string(fields["in"], "in")),
            string(fields["name"], "name"),
          )
          if !override_keys.contains(key) {
            parameters.push(param)
          }
        }
        parameters.append(overrides)
        let output : Map[String, Json] = Map([
          ("operationId", field(fields, "operationId", "operation")),
          ("method", Json::string(verb)),
          ("path", Json::string(path)),
          ("parameters", Json::array(parameters)),
        ])
        if fields.get("requestBody") is Some(value) {
          output["requestBody"] = import_content(
            value, document_id, limits, true,
          )
        }
        let responses = object(
          field(fields, "responses", "operation"),
          "responses",
        )
        let mapped = Map([])
        for status in names(responses) {
          if !status.has_prefix("x-") {
            mapped[status] = import_content(
              responses[status],
              document_id,
              limits,
              false,
            )
          }
        }
        output["responses"] = Json::object(mapped)
        operations.push(Json::object(output))
        if operations.length() > limits.operations {
          raise Budget("operations")
        }
      }
    }
  }
  compile_workspace(
    { "documents": Json::object(locks), "operations": Json::array(operations) },
    limits~,
  )
}
