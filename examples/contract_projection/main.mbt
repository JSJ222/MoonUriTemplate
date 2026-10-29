///|
fn main raise {
  let full = @contracts.compile_workspace({
    "documents": { "unused": { "type": "string" } },
    "operations": [
      {
        "operationId": "health",
        "method": "GET",
        "path": "/health",
        "responses": { "204": {} },
      },
      {
        "operationId": "internal",
        "method": "GET",
        "path": "/internal",
        "responses": { "200": {} },
      },
    ],
  })
  let sdk = full.project_operations(["health"])
  let suite : Array[@contracts.ConsumerCase] = [
    {
      name: "health",
      operation: "health",
      request: { parameters: [], body: None, media_type: None, },
      response: Some({ status: 204, headers: [], body: None, media_type: None, }),
      expect_valid: true,
    },
  ]
  let coverage = sdk.consumer_coverage(suite)
  assert_eq(sdk.operation_names(), ["health"])
  assert_eq(coverage[0].uncovered_responses().length(), 0)
  assert_eq(@contracts.compile_workspace(sdk.manifest()).operation_names(), [
    "health",
  ])
  println(
    "SDK subset exports a minimal transitive contract lock; coverage separates validated responses from request-only cases",
  )
}
