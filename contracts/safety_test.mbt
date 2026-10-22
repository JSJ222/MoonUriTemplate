///|
test "ref siblings preserve unevaluated annotations at the outer schema scope" {
  let workspace = @contracts.compile_workspace({
    "documents": {
      "s": { "type": "object", "properties": { "id": { "type": "integer" } } },
    },
    "operations": [
      {
        "operationId": "x",
        "method": "POST",
        "path": "/x",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": { "$ref": "s", "unevaluatedProperties": false },
            },
          },
        },
        "responses": { "204": {} },
      },
    ],
  })
  let request : @contracts.Request = {
    parameters: [],
    body: Some({ "id": 1 }),
    media_type: Some("application/json"),
  }
  assert_true(workspace.validate_request("x", request).is_empty())
  assert_true(
    !workspace
    .validate_request("x", { ..request, body: Some({ "id": 1, "other": 0 }), })
    .is_empty(),
  )
}

///|
test "limits reject nonfinite oversized cyclic inputs and too many findings" {
  let old = @contracts.compile_workspace(fixture())
  let nonfinite = try {
    let _ = old.validate_request("getUser", {
      ..request(),
      body: Some(Json::number(1.0 / 0.0)),
      media_type: Some("application/json"),
    })
    false
  } catch {
    _ => true
  }
  // Undeclared media rejects without interpreting the value; numeric checks
  // are guaranteed when accepting a tree into a manifest/declared schema.
  assert_true(!nonfinite)
  assert_true(
    refused({ "documents": { "s": Json::number(1.0 / 0.0) }, "operations": [] }),
  )
  assert_true(
    refused({
      "documents": { "s": Json::number(9007199254740992.0) },
      "operations": [],
    }),
  )
  let fields : Map[String, Json] = Map([])
  let cycle = Json::object(fields)
  fields["cycle"] = cycle
  assert_true(refused({ "documents": { "s": cycle }, "operations": [] }))
  let limited = @contracts.compile_workspace(fixture(), limits={
    ..@contracts.WorkspaceLimits::default(),
    findings: 0,
  })
  let failed = try {
    let _ = limited.validate_request("getUser", empty_request())
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
test "duplicate patches cannot partially modify an existing snapshot" {
  let old = @contracts.compile_workspace(fixture())
  let before = old.manifest()
  let failed = try {
    let _ = old.update_documents([
      { name: "unused", document: Some(false), },
      { name: "unused", document: Some(true), },
    ])
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(old.manifest(), before)
}

///|
test "known structural breaks remain blocked under review approval" {
  let old = @contracts.compile_workspace({
    "documents": {},
    "operations": [
      {
        "operationId": "x",
        "method": "GET",
        "path": "/x",
        "responses": { "204": {} },
      },
    ],
  })
  let next = @contracts.compile_workspace({
    "documents": {},
    "operations": [
      {
        "operationId": "x",
        "method": "POST",
        "path": "/x",
        "responses": { "204": {} },
      },
    ],
  })
  let suite : Array[@contracts.ConsumerCase] = [
    {
      name: "x",
      operation: "x",
      request: empty_request(),
      response: None,
      expect_valid: true,
    },
  ]
  assert_true(!old.gate_upgrade(next, suite, approve_review=true).accepted())
  assert_true(old.compare(next).any(fn(change) { change.severity == Breaking }))
}

///|
test "boolean schemas and null are not confused with absent body" {
  for accepted in [true, false] {
    let workspace = @contracts.compile_workspace({
      "documents": {},
      "operations": [
        {
          "operationId": "x",
          "method": "POST",
          "path": "/x",
          "requestBody": {
            "required": true,
            "content": { "application/json": { "schema": accepted } },
          },
          "responses": { "204": {} },
        },
      ],
    })
    assert_eq(
      workspace
      .validate_request("x", {
        parameters: [],
        body: Some(Json::null()),
        media_type: Some("application/json"),
      })
      .is_empty(),
      accepted,
    )
  }
}

///|
test "malformed supported schema assertions do not silently become annotations" {
  let invalid : Array[Json] = [
    { "type": "banana" },
    { "type": [] },
    { "type": ["string", "string"] },
    { "minimum": "1" },
    { "multipleOf": 0 },
    { "maxLength": -1 },
    { "maxItems": 1.5 },
    { "minLength": 2147483648.0 },
    { "required": "name" },
    { "required": ["x", "x"] },
    { "enum": [] },
    { "enum": [1, 1] },
    { "dependentRequired": { "x": "y" } },
    { "uniqueItems": 1 },
    { "pattern": "[" },
    { "allOf": [] },
  ]
  for schema in invalid {
    assert_true(
      refused({
        "documents": {},
        "operations": [
          {
            "operationId": "x",
            "method": "POST",
            "path": "/x",
            "requestBody": {
              "content": { "application/json": { "schema": schema } },
            },
            "responses": { "204": {} },
          },
        ],
      }),
    )
  }
}
