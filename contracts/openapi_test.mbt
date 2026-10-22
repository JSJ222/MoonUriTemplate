///|
fn api_document() -> Json {
  {
    "openapi": "3.1.1",
    "info": { "title": "Inventory", "version": "1" },
    "components": {
      "schemas": {
        "Id": { "type": "string", "minLength": 1 },
        "Item": {
          "type": "object",
          "properties": { "id": { "$ref": "#/components/schemas/Id" } },
          "required": ["id"],
        },
      },
    },
    "paths": {
      "/items/{id}": {
        "parameters": [
          {
            "in": "path",
            "name": "id",
            "required": true,
            "schema": { "$ref": "#/components/schemas/Id" },
          },
          {
            "in": "query",
            "name": "limit",
            "schema": { "type": "integer", "maximum": 10 },
          },
        ],
        "get": {
          "operationId": "item",
          "parameters": [
            {
              "in": "query",
              "name": "limit",
              "schema": { "type": "integer", "maximum": 20 },
            },
          ],
          "responses": {
            "200": {
              "description": "OK",
              "content": {
                "application/json": {
                  "schema": { "$ref": "#/components/schemas/Item" },
                },
              },
            },
          },
        },
      },
    },
  }
}

///|
test "OpenAPI importer rebases local schemas and operation parameter overrides" {
  let workspace = @contracts.import_openapi(api_document(), "inventory")
  let request : @contracts.Request = {
    parameters: [
      { location: Path, name: "id", value: "sku-1", },
      { location: Query, name: "limit", value: 15, },
    ],
    body: None,
    media_type: None,
  }
  assert_true(workspace.validate_request("item", request).is_empty())
  assert_eq(workspace.request_path("item", request), "/items/sku-1")
  assert_eq(workspace.operations_using("inventory"), ["item"])
  assert_true(
    workspace
    .validate_response("item", {
      status: 200,
      headers: [],
      body: Some({ "id": "sku-1" }),
      media_type: Some("application/json"),
    })
    .is_empty(),
  )
  let cold = @contracts.compile_workspace(workspace.manifest())
  assert_eq(
    cold.resolved_operation("item"),
    workspace.resolved_operation("item"),
  )
}

///|
test "OpenAPI lock projects schemas only and accepts explicit external references" {
  let api : Json = {
    "openapi": "3.1.0",
    "info": {},
    "paths": {
      "/x": {
        "get": {
          "operationId": "x",
          "responses": {
            "200": {
              "content": {
                "application/json": { "schema": { "$ref": "shared#/Data" } },
              },
            },
          },
        },
      },
    },
  }
  let documents : Map[String, Json] = Map([
    ("shared", { "Data": { "type": "integer", "minimum": 1 } }),
  ])
  let workspace = @contracts.import_openapi(api, "api", documents~)
  assert_eq(workspace.operations_using("shared"), ["x"])
  assert_true(
    workspace
    .validate_response("x", {
      status: 200,
      headers: [],
      body: Some(1),
      media_type: Some("application/json"),
    })
    .is_empty(),
  )
  if workspace.manifest() is Object(root) {
    if root["documents"] is Object(locked) {
      if locked["api"] is Object(projected) {
        assert_true(!projected.contains("paths"))
      }
    }
  }
}

///|
test "OpenAPI unsupported semantics are rejected rather than silently validated" {
  let fields : Array[(String, Json)] = [
    ("security", []),
    ("webhooks", {}),
    ("jsonSchemaDialect", "custom"),
  ]
  for entry in fields {
    let document = api_document()
    if document is Object(root) {
      root[entry.0] = entry.1
    }
    let failed = try {
      let _ = @contracts.import_openapi(document, "api")
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
  let wrong : Json = { "openapi": "3.0.3", "info": {}, "paths": {} }
  let failed = try {
    let _ = @contracts.import_openapi(wrong, "api")
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
test "array and escaped JSON Pointers in locked documents" {
  let workspace = @contracts.compile_workspace({
    "documents": { "parts": { "a/b": [{ "type": "boolean" }] } },
    "operations": [
      {
        "operationId": "x",
        "method": "POST",
        "path": "/x",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": { "schema": { "$ref": "parts#/a~1b/0" } },
          },
        },
        "responses": { "204": {} },
      },
    ],
  })
  assert_true(
    workspace
    .validate_request("x", {
      parameters: [],
      body: Some(false),
      media_type: Some("application/json"),
    })
    .is_empty(),
  )
}

///|
test "schema reference siblings compose rather than override referenced assertions" {
  let workspace = @contracts.compile_workspace({
    "documents": { "s": { "type": "string", "minLength": 2 } },
    "operations": [
      {
        "operationId": "x",
        "method": "POST",
        "path": "/x",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": { "schema": { "$ref": "s", "maxLength": 3 } },
          },
        },
        "responses": { "204": {} },
      },
    ],
  })
  for text in ["a", "abcd"] {
    assert_true(
      !workspace
      .validate_request("x", {
        parameters: [],
        body: Some(Json::string(text)),
        media_type: Some("application/json"),
      })
      .is_empty(),
    )
  }
  assert_true(
    workspace
    .validate_request("x", {
      parameters: [],
      body: Some("abc"),
      media_type: Some("application/json"),
    })
    .is_empty(),
  )
}

///|
test "gate rejects mismatched validation policies instead of reusing stale results" {
  let old = @contracts.compile_workspace(fixture())
  let other = @contracts.compile_workspace(fixture(), limits={
    ..@contracts.WorkspaceLimits::default(),
    findings: 1,
  })
  let failed = try {
    let _ = old.gate_upgrade(other, cases())
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
