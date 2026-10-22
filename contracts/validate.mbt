///|
fn Workspace::operation(
  self : Workspace,
  name : String,
) -> Operation raise WorkspaceError {
  self.operations
  .get(name)
  .unwrap_or_else(() => {
    invalid("operationId", "unknown operation \{name}")
    abort("unreachable")
  })
}

///|
fn finding(operation : String, place : String, code : String) -> Violation {
  { operation, location: place, instance_path: "", schema_path: "", code, }
}

///|
fn add_finding(
  output : Array[Violation],
  value : Violation,
  limit : Int32,
) -> Unit raise WorkspaceError {
  if output.length() >= limit {
    raise Budget("findings")
  }
  output.push(value)
}

///|
fn check_schema(
  schema : @schema.Schema,
  value : Json,
  operation : String,
  place : String,
  output : Array[Violation],
  limits : WorkspaceLimits,
) -> Unit raise WorkspaceError {
  let value = detached(value, limits)
  if schema.valid(value) {
    return
  }
  let before = output.length()
  // The vendor produces its diagnostics eagerly. This caps returned diagnostics,
  // not vendor interpreter memory/time: the host still needs process quotas.
  for fault in schema.faults(value) {
    add_finding(
      output,
      {
        operation,
        location: place,
        instance_path: fault.at,
        schema_path: fault.schema_at,
        code: fault.keyword,
      },
      limits.findings,
    )
  }
  // A failed flag must never become a valid result merely because an upstream
  // interpreter returned no diagnostics for that failure.
  if output.length() == before {
    add_finding(
      output,
      finding(operation, place, "validation_failed"),
      limits.findings,
    )
  }
}

///|
fn check_parameters(
  rules : Array[Parameter],
  supplied : Array[ParameterValue],
  operation : String,
  output : Array[Violation],
  limits : WorkspaceLimits,
  reject_unknown : Bool,
) -> Unit raise WorkspaceError {
  if supplied.length() > limits.nodes {
    raise Budget("parameters")
  }
  let values : Map[String, Json] = Map([])
  let declarations : Map[String, Bool] = Map([])
  for rule in rules {
    declarations[parameter_key(rule.location, rule.name)] = true
  }
  let budget = { nodes: 0, text: 0, limits, }
  for item in supplied {
    budget.text(item.name)
    let key = parameter_key(item.location, item.name)
    if values.contains(key) {
      add_finding(
        output,
        finding(operation, key, "duplicate_parameter"),
        limits.findings,
      )
    }
    values[key] = budget.copy(item.value, 0)
    if reject_unknown && !declarations.contains(key) {
      add_finding(
        output,
        finding(operation, key, "unknown_parameter"),
        limits.findings,
      )
    }
  }
  for rule in rules {
    let key = parameter_key(rule.location, rule.name)
    match values.get(key) {
      Some(value) =>
        check_schema(rule.schema, value, operation, key, output, limits)
      None =>
        if rule.required {
          add_finding(
            output,
            finding(operation, key, "required"),
            limits.findings,
          )
        }
    }
  }
}

///|
fn check_body(
  content : Content,
  body : Json?,
  media_type : String?,
  operation : String,
  place : String,
  output : Array[Violation],
  limits : WorkspaceLimits,
) -> Unit raise WorkspaceError {
  match body {
    None =>
      if content.required {
        add_finding(
          output,
          finding(operation, place, "required"),
          limits.findings,
        )
      }
    Some(value) => {
      let media_type = media_type
        .unwrap_or("")
        .to_lower()
        .split(";")
        .next()
        .unwrap_or("")
        .trim()
        .to_owned()
      match content.media.get(media_type) {
        None =>
          add_finding(
            output,
            finding(operation, place, "undeclared_media_type"),
            limits.findings,
          )
        Some(schema) =>
          check_schema(schema, value, operation, place, output, limits)
      }
    }
  }
}

///|
/// Validate already-decoded parameter values, not raw HTTP wire encodings.
/// Unknown query/path/cookie/header inputs are rejected by this explicit SDK
/// contract policy. Body absence and JSON null are distinct. No defaults/coercion.
pub fn Workspace::validate_request(
  self : Workspace,
  name : String,
  request : Request,
) -> Array[Violation] raise WorkspaceError {
  let operation = self.operation(name)
  let output = []
  check_parameters(
    operation.parameters,
    request.parameters,
    name,
    output,
    self.limits,
    true,
  )
  check_body(
    operation.request,
    request.body,
    request.media_type,
    name,
    "request.body",
    output,
    self.limits,
  )
  output
}

///|
/// Exact status takes precedence over class (2XX), then default. Unknown response
/// headers are allowed, but duplicate normalized names and declared schemas are
/// checked. A declared JSON content requires a body for non-204/304 statuses.
pub fn Workspace::validate_response(
  self : Workspace,
  name : String,
  response : Response,
) -> Array[Violation] raise WorkspaceError {
  let operation = self.operation(name)
  need(
    response.status >= 100 && response.status <= 599,
    "response.status",
    "invalid status code",
  )
  let status = response.status.to_string()
  let rule = match operation.responses.get(status) {
    Some(rule) => Some(rule)
    None =>
      match operation.responses.get("\{response.status / 100}XX") {
        Some(rule) => Some(rule)
        None => operation.responses.get("default")
      }
  }
  let output = []
  match rule {
    None =>
      add_finding(
        output,
        finding(name, "response.status", "undeclared_status"),
        self.limits.findings,
      )
    Some(rule) => {
      let headers = response.headers.map(fn(item) {
        { location: Header, name: item.0, value: item.1, }
      })
      check_parameters(rule.headers, headers, name, output, self.limits, false)
      if response.status < 200 ||
        response.status == 204 ||
        response.status == 304 ||
        operation.verb == "HEAD" {
        if response.body is Some(_) {
          add_finding(
            output,
            finding(name, "response.body", "body_forbidden"),
            self.limits.findings,
          )
        }
      } else {
        let content = {
          ..rule.content,
          required: !rule.content.media.is_empty(),
        }
        check_body(
          content,
          response.body,
          response.media_type,
          name,
          "response.body",
          output,
          self.limits,
        )
      }
    }
  }
  output
}

///|
/// Replay consumer expectations, including negative cases. Results contain paths
/// and codes, never request/response values. A suite is evidence, not a proof
/// that every possible client remains compatible.
pub fn Workspace::replay(
  self : Workspace,
  cases : Array[ConsumerCase],
) -> Array[CaseResult] raise WorkspaceError {
  if cases.length() > self.limits.cases {
    raise Budget("cases")
  }
  let result = []
  let seen : Map[String, Bool] = Map([])
  for sample in cases {
    need(
      sample.name != "" && !seen.contains(sample.name),
      "cases",
      "empty or duplicate case name",
    )
    seen[sample.name] = true
    let violations = if !self.operations.contains(sample.operation) {
      [finding(sample.operation, "operationId", "unknown_operation")]
    } else {
      let findings = self.validate_request(sample.operation, sample.request)
      if sample.response is Some(response) {
        for issue in self.validate_response(sample.operation, response) {
          add_finding(findings, issue, self.limits.findings)
        }
      }
      findings
    }
    let actual_valid = violations.is_empty()
    result.push({
      name: sample.name,
      operation: sample.operation,
      expected_valid: sample.expect_valid,
      actual_valid,
      passed: actual_valid == sample.expect_valid,
      violations,
    })
  }
  result
}

///|
/// Render only the path after successful contract checking. Query/header/cookie
/// serialization belongs to the host HTTP adapter, not RFC6570 path expansion.
pub fn Workspace::request_path(
  self : Workspace,
  name : String,
  request : Request,
) -> String raise WorkspaceError {
  need(
    self.validate_request(name, request).is_empty(),
    "request",
    "request violates the operation contract",
  )
  let operation = self.operation(name)
  let bindings = []
  for item in request.parameters {
    if item.location == Path {
      let text = match item.value {
        String(text) => text
        Number(value, ..) => value.to_string()
        True => "true"
        False => "false"
        _ => {
          invalid("path", "path rendering requires a non-null scalar")
          ""
        }
      }
      bindings.push((item.name, @uri.Scalar(text)))
    }
  }
  match @uri.expand(operation.path, bindings) {
    Ok(path) => path
    Err(_) => {
      invalid("path", "path expansion failed")
      ""
    }
  }
}
