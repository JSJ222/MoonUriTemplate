///|
fn main raise {
  let workspace = @contracts.compile_workspace({
    "documents": { "code": { "type": "string", "minLength": 1 } },
    "operations": [
      {
        "operationId": "save",
        "method": "POST",
        "path": "/save",
        "requestBody": {
          "required": true,
          "content": { "application/json": { "schema": { "$ref": "code" } } },
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
  let request : @contracts.Request = {
    parameters: [],
    body: Some("a"),
    media_type: Some("application/json"),
  }
  let cases : Array[@contracts.ConsumerCase] = [
    {
      name: "existing SDK",
      operation: "save",
      request,
      response: None,
      expect_valid: true,
    },
    {
      name: "health",
      operation: "health",
      request: { parameters: [], body: None, media_type: None, },
      response: None,
      expect_valid: true,
    },
  ]
  let incompatible = workspace
    .update_documents([
      { name: "code", document: Some({ "type": "string", "minLength": 2 }), },
    ])
    .workspace()
  assert_true(
    !workspace.gate_upgrade(incompatible, cases, approve_review=true).accepted(),
  )
  let candidate = workspace
    .update_documents([
      {
        name: "code",
        document: Some({ "type": "string", "minLength": 1, "maxLength": 32 }),
      },
    ])
    .workspace()
  assert_true(!workspace.gate_upgrade(candidate, cases).accepted())
  // Human approval is explicit; examples do not establish schema inclusion.
  let decision = workspace.gate_upgrade(candidate, cases, approve_review=true)
  assert_true(decision.accepted())
  assert_eq(decision.replayed_cases(), 1)
  println(decision.to_json().stringify())
}
