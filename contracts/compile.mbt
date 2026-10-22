///|
fn location(value : String) -> ParameterLocation raise WorkspaceError {
  match value {
    "path" => Path
    "query" => Query
    "header" => Header
    "cookie" => Cookie
    _ => {
      invalid("parameter.in", "unknown parameter location")
      Path
    }
  }
}

///|
fn ParameterLocation::label(self : ParameterLocation) -> String {
  match self {
    Path => "path"
    Query => "query"
    Header => "header"
    Cookie => "cookie"
  }
}

///|
fn parameter_name(place : ParameterLocation, name : String) -> String {
  if place == Header {
    name.to_lower()
  } else {
    name
  }
}

///|
fn parameter_key(place : ParameterLocation, name : String) -> String {
  place.label() + ":" + parameter_name(place, name)
}

///|
fn Resolver::parameters(
  self : Resolver,
  values : Array[Json],
) -> (Array[Parameter], Json) raise WorkspaceError {
  let result = []
  let schemas : Array[Json] = []
  let seen : Map[String, Bool] = Map([])
  for value in values {
    let fields = object(value, "parameter")
    only(
      fields,
      ["name", "in", "required", "schema", "description", "deprecated"],
      "parameter",
    )
    let name = string(field(fields, "name", "parameter"), "parameter.name")
    need(name != "", "parameter.name", "empty name")
    let place = location(
      string(field(fields, "in", "parameter"), "parameter.in"),
    )
    let name = parameter_name(place, name)
    let key = parameter_key(place, name)
    need(!seen.contains(key), "parameter", "duplicate parameter identity")
    seen[key] = true
    let required = flag(fields, "required", false, "parameter")
    need(
      place != Path || required,
      "parameter",
      "path parameters must be required",
    )
    let (validator, resolved) = self.validator(
      field(fields, "schema", "parameter"),
    )
    result.push({ location: place, name, required, schema: validator, })
    schemas.push({
      "in": place.label(),
      "name": name,
      "required": required,
      "schema": resolved,
    })
  }
  (result, Json::array(schemas))
}

///|
fn Resolver::content(
  self : Resolver,
  input : Json?,
  request : Bool,
) -> (Content, Json) raise WorkspaceError {
  let media : Map[String, @schema.Schema] = Map([])
  let normalized : Map[String, Json] = Map([])
  let required = match input {
    None => false
    Some(value) => {
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
      if fields.get("content") is Some(content) {
        let entries = object(content, "content")
        for name in names(entries) {
          need(
            name == "application/json" || name.has_suffix("+json"),
            "content",
            "only exact JSON media types",
          )
          need(
            name == name.to_lower() && !name.contains(";"),
            "content",
            "media type must be normalized",
          )
          let entry = object(entries[name], "media")
          only(entry, ["schema"], "media")
          let (schema, resolved) = self.validator(
            field(entry, "schema", "media"),
          )
          media[name] = schema
          normalized[name] = { "schema": resolved }
        }
      }
      if request {
        flag(fields, "required", false, "requestBody")
      } else {
        false
      }
    }
  }
  (
    { media, required, },
    { "required": required, "content": Json::object(normalized) },
  )
}

///|
fn compile_operation(
  value : Json,
  documents : Map[String, Json],
  limits : WorkspaceLimits,
) -> Operation raise WorkspaceError {
  let fields = object(value, "operation")
  only(
    fields,
    [
      "operationId", "method", "path", "parameters", "requestBody", "responses",
      "description", "summary", "deprecated",
    ],
    "operation",
  )
  let name = string(field(fields, "operationId", "operation"), "operationId")
  need(name != "", "operationId", "empty identifier")
  let verb = string(field(fields, "method", "operation"), "method").to_upper()
  need(
    ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS", "TRACE"].contains(
      verb,
    ),
    "method",
    "unsupported HTTP method",
  )
  let path = string(field(fields, "path", "operation"), "path")
  need(
    path.has_prefix("/") &&
    !path.has_prefix("//") &&
    !path.contains("?") &&
    !path.contains("#"),
    "path",
    "expected origin-relative path template",
  )
  let template = match @uri.parse(path) {
    Ok(template) => template
    Err(_) => {
      invalid("path", "invalid path template")
      abort("unreachable")
    }
  }
  for expression in template.analyze().expressions() {
    need(
      expression.operator == "",
      "path",
      "only simple OpenAPI path placeholders are supported",
    )
  }
  let resolver = {
    documents,
    dependencies: Map([]),
    active: Map([]),
    expanded: 0,
    limits,
  }
  let parameter_values = match fields.get("parameters") {
    Some(value) => array(value, "parameters")
    None => []
  }
  let (parameters, parameter_schemas) = resolver.parameters(parameter_values)
  let path_names = parameters
    .filter(fn(item) { item.location == Path })
    .map(fn(item) { item.name })
  let variables = template.variables()
  need(
    path_names.length() == variables.length() &&
    variables.all(fn(name) { path_names.contains(name) }),
    "path",
    "path declarations and template variables must match",
  )
  for profile in template.variable_profiles() {
    need(
      !profile.uses_explode && profile.maximum_prefix is None,
      "path",
      "path modifiers are unsupported",
    )
  }
  let (request, request_schema) = resolver.content(
    fields.get("requestBody"),
    true,
  )
  let response_values = object(
    field(fields, "responses", "operation"),
    "responses",
  )
  need(
    !response_values.is_empty(),
    "responses",
    "at least one response declaration required",
  )
  let responses : Map[String, ResponseRule] = Map([])
  let response_schemas : Map[String, Json] = Map([])
  for status in names(response_values) {
    need(
      status == "default" ||
      ["1XX", "2XX", "3XX", "4XX", "5XX"].contains(status) ||
      (
        status.length() == 3 &&
        status.code_unit_at(0).to_int() >= 49 &&
        status.code_unit_at(0).to_int() <= 53 &&
        status.code_unit_at(1).to_int() >= 48 &&
        status.code_unit_at(1).to_int() <= 57 &&
        status.code_unit_at(2).to_int() >= 48 &&
        status.code_unit_at(2).to_int() <= 57
      ),
      "responses",
      "invalid response status",
    )
    let value = response_values[status]
    let (content, content_schema) = resolver.content(Some(value), false)
    let response_fields = object(value, "response")
    let header_values : Array[Json] = []
    if response_fields.get("headers") is Some(headers) {
      let header_fields = object(headers, "headers")
      for name in names(header_fields) {
        let entry = object(header_fields[name], "header")
        only(entry, ["schema", "required", "description"], "header")
        header_values.push({
          "in": "header",
          "name": name,
          "required": flag(entry, "required", false, "header"),
          "schema": field(entry, "schema", "header"),
        })
      }
    }
    let (headers, header_schemas) = resolver.parameters(header_values)
    responses[status] = { content, headers, }
    response_schemas[status] = {
      "body": content_schema,
      "headers": header_schemas,
    }
  }
  let dependencies = []
  for key, _ in resolver.dependencies {
    dependencies.push(key)
  }
  dependencies.sort_by(fn(a, b) { a.lexical_compare(b) })
  {
    name,
    verb,
    path,
    parameters,
    request,
    responses,
    dependencies,
    resolved: {
      "method": verb,
      "path": path,
      "parameters": parameter_schemas,
      "request": request_schema,
      "responses": Json::object(response_schemas),
    },
  }
}

///|
fn reverse_index(
  order : Array[String],
  operations : Map[String, Operation],
) -> Map[String, Array[String]] {
  let result : Map[String, Array[String]] = Map([])
  for name in order {
    for dependency in operations[name].dependencies {
      match result.get(dependency) {
        Some(users) => users.push(name)
        None => result[dependency] = [name]
      }
    }
  }
  result
}

///|
/// Compile an explicit offline lock: {documents:{name:Json},operations:[...] }.
/// The document names are exact reference IDs, never fetched URLs or files.
pub fn compile_workspace(
  manifest : Json,
  limits~ : WorkspaceLimits = WorkspaceLimits::default(),
) -> Workspace raise WorkspaceError {
  check_limits(limits)
  let fields = object(detached(manifest, limits), "workspace")
  only(fields, ["documents", "operations"], "workspace")
  let documents = object(field(fields, "documents", "workspace"), "documents")
  if documents.length() > limits.documents {
    raise Budget("documents")
  }
  for name in names(documents) {
    need(
      name != "" && !name.contains("#"),
      "documents",
      "document names must be nonempty fragment-free IDs",
    )
  }
  let definitions = array(
    field(fields, "operations", "workspace"),
    "operations",
  )
  if definitions.length() > limits.operations {
    raise Budget("operations")
  }
  let operations : Map[String, Operation] = Map([])
  let order = []
  let routes : Map[String, Bool] = Map([])
  for definition in definitions {
    let operation = compile_operation(definition, documents, limits)
    need(
      !operations.contains(operation.name),
      "operations",
      "duplicate operationId",
    )
    let route = operation.verb + " " + operation.path
    need(!routes.contains(route), "operations", "duplicate method/path")
    routes[route] = true
    order.push(operation.name)
    operations[operation.name] = operation
  }
  {
    documents,
    definitions,
    operations,
    order,
    reverse: reverse_index(order, operations),
    limits,
    revision: 0,
  }
}

///|
pub fn compile_workspace_text(
  text : String,
  limits~ : WorkspaceLimits = WorkspaceLimits::default(),
) -> Workspace raise WorkspaceError {
  check_limits(limits)
  if text.length() > limits.text_units {
    raise Budget("text_units")
  }
  let parsed = @json.parse(
    text,
    max_nesting_depth=limits.depth,
    reject_duplicate_keys=true,
  ) catch {
    _ => {
      invalid("workspace", "invalid JSON or duplicate object key")
      abort("unreachable")
    }
  }
  compile_workspace(parsed, limits~)
}
