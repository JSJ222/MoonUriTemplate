///|
fn fixture() -> Json {
  {
    "documents": {
      "id": { "type": "string", "minLength": 1 },
      "user": {
        "type": "object",
        "required": ["id"],
        "properties": { "id": { "$ref": "id" } },
        "additionalProperties": false,
      },
      "unused": { "type": "boolean" },
    },
    "operations": [
      {
        "operationId": "getUser",
        "method": "GET",
        "path": "/users/{id}",
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": { "$ref": "id" },
          },
          {
            "name": "X-Tenant",
            "in": "header",
            "required": true,
            "schema": { "type": "string", "enum": ["team"] },
          },
        ],
        "responses": {
          "200": {
            "content": { "application/json": { "schema": { "$ref": "user" } } },
            "headers": {
              "X-Version": {
                "required": true,
                "schema": { "type": "integer", "minimum": 1 },
              },
            },
          },
          "2XX": {
            "content": {
              "application/json": { "schema": { "type": "boolean" } },
            },
          },
          "default": {},
        },
      },
      {
        "operationId": "ping",
        "method": "GET",
        "path": "/ping",
        "responses": { "204": {} },
      },
    ],
  }
}

///|
fn request(id~ : String = "a") -> @contracts.Request {
  {
    parameters: [
      { location: Path, name: "id", value: Json::string(id), },
      { location: Header, name: "x-TENANT", value: "team", },
    ],
    body: None,
    media_type: None,
  }
}

///|
fn empty_request() -> @contracts.Request {
  { parameters: [], body: None, media_type: None, }
}

///|
fn response() -> @contracts.Response {
  {
    status: 200,
    headers: [("x-version", 1)],
    body: Some({ "id": "a" }),
    media_type: Some("Application/JSON; charset=utf-8"),
  }
}

///|
fn cases() -> Array[@contracts.ConsumerCase] {
  [
    {
      name: "sdk user",
      operation: "getUser",
      request: request(),
      response: Some(response()),
      expect_valid: true,
    },
    {
      name: "health probe",
      operation: "ping",
      request: empty_request(),
      response: None,
      expect_valid: true,
    },
    {
      name: "reject empty id",
      operation: "getUser",
      request: request(id=""),
      response: None,
      expect_valid: false,
    },
  ]
}

///|
fn refused(
  value : Json,
  limits~ : @contracts.WorkspaceLimits = @contracts.WorkspaceLimits::default(),
) -> Bool {
  try {
    let _ = @contracts.compile_workspace(value, limits~)
    false
  } catch {
    _ => true
  }
}

///|
test "workspace resolves transitive locked schemas and replays consumers" {
  let workspace = @contracts.compile_workspace(fixture())
  assert_eq(workspace.operation_names(), ["getUser", "ping"])
  assert_eq(workspace.operations_using("id"), ["getUser"])
  assert_eq(workspace.operations_using("user"), ["getUser"])
  assert_eq(workspace.operations_using("unused"), [])
  assert_true(workspace.replay(cases()).all(fn(result) { result.passed }))
  assert_eq(
    workspace.request_path("getUser", request(id="a/b")),
    "/users/a%2Fb",
  )
}

///|
test "request diagnostics distinguish required duplicate unknown and schema faults" {
  let workspace = @contracts.compile_workspace(fixture())
  let issues = workspace.validate_request("getUser", empty_request())
  assert_eq(issues.length(), 2)
  assert_true(issues.all(fn(issue) { issue.code == "required" }))
  let supplied = request()
  supplied.parameters.push({
    location: Header,
    name: "X-Tenant",
    value: "wrong",
  })
  supplied.parameters.push({ location: Query, name: "extra", value: 1, })
  let issues = workspace.validate_request("getUser", supplied)
  assert_true(issues.any(fn(issue) { issue.code == "duplicate_parameter" }))
  assert_true(issues.any(fn(issue) { issue.code == "unknown_parameter" }))
  assert_true(issues.any(fn(issue) { issue.code == "enum" }))
}

///|
test "response exact status class and default precedence" {
  let workspace = @contracts.compile_workspace(fixture())
  assert_eq(workspace.validate_response("getUser", response()).length(), 0)
  let bad = { ..response(), body: Some(false), }
  assert_true(!workspace.validate_response("getUser", bad).is_empty())
  assert_eq(
    workspace.validate_response("getUser", { ..bad, status: 201, }).length(),
    0,
  )
  assert_eq(
    workspace
    .validate_response("getUser", {
      status: 404,
      headers: [],
      body: None,
      media_type: None,
    })
    .length(),
    0,
  )
  let issues = workspace.validate_response("ping", {
    status: 204,
    headers: [],
    body: Some(Json::null()),
    media_type: Some("application/json"),
  })
  assert_eq(issues[0].code, "body_forbidden")
}

///|
test "required JSON body distinguishes missing null and media mismatch" {
  let workspace = @contracts.compile_workspace({
    "documents": {},
    "operations": [
      {
        "operationId": "save",
        "method": "POST",
        "path": "/save",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": ["object", "null"],
                "properties": {
                  "tags": {
                    "type": "array",
                    "items": { "type": "integer", "minimum": 0 },
                  },
                },
              },
            },
          },
        },
        "responses": { "204": {} },
      },
    ],
  })
  assert_eq(
    workspace.validate_request("save", empty_request())[0].code,
    "required",
  )
  let valid = {
    ..empty_request(),
    body: Some(Json::null()),
    media_type: Some("application/json"),
  }
  assert_true(workspace.validate_request("save", valid).is_empty())
  assert_eq(
    workspace.validate_request("save", {
      ..valid,
      media_type: Some("text/plain"),
    })[0].code,
    "undeclared_media_type",
  )
  assert_true(
    !workspace
    .validate_request("save", { ..valid, body: Some({ "tags": [0, -1] }), })
    .is_empty(),
  )
}

///|
test "atomic update rebuilds only transitive dependents and preserves old snapshot" {
  let old = @contracts.compile_workspace(fixture())
  let patch : Json = { "type": "string", "minLength": 2 }
  let update = old.update_documents([{ name: "id", document: Some(patch), }])
  assert_eq(update.changed_documents(), ["id"])
  assert_eq(update.rebuilt_operations(), ["getUser"])
  let next = update.workspace()
  assert_eq(old.revision(), 0)
  assert_eq(next.revision(), 1)
  assert_true(old.validate_request("getUser", request()).is_empty())
  assert_true(!next.validate_request("getUser", request()).is_empty())
  let noop = next.update_documents([{ name: "id", document: Some(patch), }])
  assert_eq(noop.workspace().revision(), 1)
  assert_eq(noop.rebuilt_operations(), [])
  let unused = next.update_documents([
    { name: "unused", document: Some({ "type": "integer" }), },
  ])
  assert_eq(unused.rebuilt_operations(), [])
}

///|
test "failed reference replacement or removal rolls back atomically" {
  let old = @contracts.compile_workspace(fixture())
  let before = old.manifest()
  let failed = try {
    let _ = old.update_documents([
      { name: "id", document: Some({ "$ref": "missing" }), },
    ])
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  let removed = try {
    let _ = old.update_documents([{ name: "id", document: None, }])
    false
  } catch {
    _ => true
  }
  assert_true(removed)
  assert_eq(old.manifest(), before)
  assert_true(old.replay(cases()).all(fn(result) { result.passed }))
}

///|
test "reference graph is replaced after dependency redirection" {
  let old = @contracts.compile_workspace(fixture())
  let moved = old
    .update_documents([
      { name: "newId", document: Some({ "type": "string", "minLength": 1 }), },
      {
        name: "user",
        document: Some({
          "type": "object",
          "properties": { "id": { "$ref": "newId" } },
        }),
      },
    ])
    .workspace()
  assert_eq(moved.operations_using("newId"), ["getUser"])
  let affected = moved.update_documents([
    { name: "newId", document: Some({ "type": "string", "minLength": 2 }), },
  ])
  assert_eq(affected.rebuilt_operations(), ["getUser"])
  let no_longer_used = moved.update_documents([
    { name: "unused", document: None, },
  ])
  assert_eq(no_longer_used.rebuilt_operations(), [])
}

///|
test "bounded deterministic revision sequence equals cold rebuild" {
  let mut current = @contracts.compile_workspace(fixture())
  for step in 0..<24 {
    let minimum = if step % 2 == 0 { 0 } else { 1 }
    let update = current.update_documents([
      {
        name: "id",
        document: Some({ "type": "string", "minLength": minimum }),
      },
    ])
    let next = update.workspace()
    let cold = @contracts.compile_workspace(next.manifest())
    for name in next.operation_names() {
      assert_eq(next.resolved_operation(name), cold.resolved_operation(name))
    }
    assert_eq(next.operations_using("id"), cold.operations_using("id"))
    let incremental = next.replay(cases())
    let rebuilt = cold.replay(cases())
    for i in 0..<incremental.length() {
      assert_eq(incremental[i].passed, rebuilt[i].passed)
      assert_true(incremental[i].violations == rebuilt[i].violations)
    }
    current = next
  }
}

///|
test "upgrade gate requires explicit review and targeted positive coverage" {
  let old = @contracts.compile_workspace(fixture())
  let next = old
    .update_documents([
      {
        name: "id",
        document: Some({ "type": "string", "minLength": 1, "maxLength": 100 }),
      },
    ])
    .workspace()
  let denied = old.gate_upgrade(next, cases())
  assert_true(!denied.accepted())
  assert_true(
    denied.blockers().any(fn(item) { item.code == "review_required" }),
  )
  assert_true(denied.approved_workspace() is None)
  let allowed = old.gate_upgrade(next, cases(), approve_review=true)
  assert_true(allowed.accepted())
  assert_eq(allowed.replayed_cases(), 2)
  assert_true(allowed.approved_workspace() is Some(_))
  assert_true(
    !old.gate_upgrade(next, [cases()[2]], approve_review=true).accepted(),
  )
  let results = allowed.results()
  results[0].violations.push({
    operation: "x",
    location: "x",
    instance_path: "",
    schema_path: "",
    code: "x",
  })
  assert_true(allowed.results()[0].violations.is_empty())
}

///|
test "upgrade gate blocks actual regressions even after explicit review" {
  let old = @contracts.compile_workspace(fixture())
  let next = old
    .update_documents([
      { name: "id", document: Some({ "type": "string", "minLength": 2 }), },
    ])
    .workspace()
  assert_true(!old.gate_upgrade(next, cases(), approve_review=true).accepted())
  let broken = [{ ..cases()[0], expect_valid: false, }]
  assert_true(!old.gate_upgrade(old, broken).accepted())
}

///|
test "upgrade gate supports newly added operation but blocks removal" {
  let old = @contracts.compile_workspace({ "documents": {}, "operations": [] })
  let next = @contracts.compile_workspace({
    "documents": {},
    "operations": [
      {
        "operationId": "ping",
        "method": "GET",
        "path": "/ping",
        "responses": { "204": {} },
      },
    ],
  })
  let suite : Array[@contracts.ConsumerCase] = [
    {
      name: "ping",
      operation: "ping",
      request: empty_request(),
      response: None,
      expect_valid: true,
    },
  ]
  assert_true(old.gate_upgrade(next, suite).accepted())
  assert_true(!next.gate_upgrade(old, suite, approve_review=true).accepted())
}

///|
test "snapshot input and exported mutable containers are detached" {
  let input = fixture()
  let workspace = @contracts.compile_workspace(input)
  if input is Object(fields) {
    fields.clear()
  }
  let exported = workspace.manifest()
  if exported is Object(fields) {
    fields.clear()
  }
  let names = workspace.operation_names()
  names.clear()
  assert_eq(workspace.operation_names(), ["getUser", "ping"])
  assert_true(workspace.replay(cases()).all(fn(result) { result.passed }))
}

///|
test "invalid lock definitions and resource limits fail explicitly" {
  assert_true(
    refused({
      "documents": {},
      "operations": [
        {
          "operationId": "x",
          "method": "GET",
          "path": "/{id}",
          "responses": { "200": {} },
        },
      ],
    }),
  )
  assert_true(
    refused({
      "documents": { "x": { "$ref": "x" } },
      "operations": [
        {
          "operationId": "x",
          "method": "POST",
          "path": "/x",
          "requestBody": {
            "content": { "application/json": { "schema": { "$ref": "x" } } },
          },
          "responses": { "204": {} },
        },
      ],
    }),
  )
  assert_true(
    refused(fixture(), limits={
      ..@contracts.WorkspaceLimits::default(),
      operations: 1,
    }),
  )
  assert_true(
    refused(fixture(), limits={
      ..@contracts.WorkspaceLimits::default(),
      resolved_nodes: 0,
    }),
  )
  let duplicate = try {
    let _ = @contracts.compile_workspace_text(
      "{\"documents\":{},\"documents\":{},\"operations\":[]}",
    )
    false
  } catch {
    _ => true
  }
  assert_true(duplicate)
}

///|
test "unsupported schema dialect scoping and silent unknown keywords are rejected" {
  let unsupported : Array[Json] = [
    { "$id": "relative", "type": "string" },
    { "$dynamicRef": "x" },
    { "type": "string", "madeUpAssertion": true },
    { "type": "string", "readOnly": true },
    { "$schema": "https://json-schema.org/draft-07/schema" },
  ]
  for schema in unsupported {
    let manifest : Json = {
      "documents": { "s": schema },
      "operations": [
        {
          "operationId": "x",
          "method": "POST",
          "path": "/x",
          "requestBody": {
            "content": { "application/json": { "schema": { "$ref": "s" } } },
          },
          "responses": { "204": {} },
        },
      ],
    }
    assert_true(refused(manifest))
  }
}
