///|
fn main raise {
  // Orders and users share a DTO, while health is independent.
  let workspace = @contracts.compile_workspace({
    "documents": {
      "identity": { "type": "string", "minLength": 1 },
      "shared": {
        "type": "object",
        "properties": { "owner": { "$ref": "identity" } },
        "required": ["owner"],
      },
    },
    "operations": [
      {
        "operationId": "orders",
        "method": "POST",
        "path": "/orders",
        "requestBody": {
          "content": { "application/json": { "schema": { "$ref": "shared" } } },
        },
        "responses": { "204": {} },
      },
      {
        "operationId": "users",
        "method": "POST",
        "path": "/users",
        "requestBody": {
          "content": { "application/json": { "schema": { "$ref": "shared" } } },
        },
        "responses": { "204": {} },
      },
      {
        "operationId": "health",
        "method": "GET",
        "path": "/health",
        "responses": { "204": {} },
      },
    ],
  })
  assert_eq(workspace.operations_using("identity"), ["orders", "users"])
  let update = workspace.update_documents([
    { name: "identity", document: Some({ "type": "string", "minLength": 2 }), },
  ])
  assert_eq(update.rebuilt_operations(), ["orders", "users"])
  let request : @contracts.Request = {
    parameters: [],
    body: Some({ "owner": "a" }),
    media_type: Some("application/json"),
  }
  assert_true(workspace.validate_request("orders", request).is_empty())
  assert_true(
    !update.workspace().validate_request("orders", request).is_empty(),
  )
  let failed = try {
    let _ = update
      .workspace()
      .update_documents([
        { name: "identity", document: Some({ "$ref": "missing" }), },
      ])
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  let cold = @contracts.compile_workspace(update.workspace().manifest())
  for name in cold.operation_names() {
    assert_eq(
      cold.resolved_operation(name),
      update.workspace().resolved_operation(name),
    )
  }
  println(
    "Shared DTO workspace: 2/3 operations rebuilt; failed update rolled back; cold equivalence passed",
  )
}
