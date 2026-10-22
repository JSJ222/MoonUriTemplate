///|
// Original deterministic fixtures, not copied from a third-party test suite.
fn main raise {
  let schemas : Array[Json] = [
    { "type": "integer", "minimum": 0, "maximum": 10 },
    { "type": ["string", "null"], "minLength": 1, "maxLength": 3 },
    { "type": "string", "pattern": "^[a-z]+$" },
    { "enum": ["a", 1, Json::null()] },
    {
      "type": "object",
      "properties": { "id": { "type": "integer" } },
      "required": ["id"],
      "additionalProperties": false,
    },
    {
      "type": "array",
      "items": { "type": "integer" },
      "minItems": 1,
      "uniqueItems": true,
    },
    { "oneOf": [{ "type": "integer", "minimum": 0 }, { "type": "string" }] },
    { "not": { "type": "null" } },
    { "type": "object", "dependentRequired": { "a": ["b"] } },
    {
      "type": "array",
      "contains": { "type": "integer" },
      "minContains": 1,
      "maxContains": 2,
    },
    {
      "if": { "type": "integer" },
      "then": { "minimum": 0 },
      "else": { "type": "string" },
    },
    {
      "type": "object",
      "allOf": [{ "properties": { "id": { "type": "integer" } } }],
      "unevaluatedProperties": false,
    },
    {
      "allOf": [{ "type": "number" }, { "exclusiveMinimum": 0 }],
      "multipleOf": 2,
    },
  ]
  let instances : Array[Json] = [
    Json::null(),
    false,
    true,
    -1,
    0,
    1,
    2,
    10,
    11,
    1.5,
    "",
    "a",
    "abc",
    "abcd",
    "A",
    [],
    [1],
    [1, 1],
    [1, 2],
    [1, 2, 3],
    ["a"],
    {},
    { "id": 1 },
    { "id": "a" },
    { "id": 1, "extra": true },
    { "a": 1 },
    { "a": 1, "b": 2 },
  ]
  for schema_index, schema in schemas {
    let workspace = @contracts.compile_workspace({
      "documents": {},
      "operations": [
        {
          "operationId": "oracle",
          "method": "POST",
          "path": "/oracle",
          "requestBody": {
            "required": true,
            "content": { "application/json": { "schema": schema } },
          },
          "responses": { "204": {} },
        },
      ],
    })
    for instance_index, instance in instances {
      let request : @contracts.Request = {
        parameters: [],
        body: Some(instance),
        media_type: Some("application/json"),
      }
      let row : Json = {
        "schemaIndex": schema_index,
        "instanceIndex": instance_index,
        "schema": schema,
        "instance": instance,
        "valid": workspace.validate_request("oracle", request).is_empty(),
      }
      println(row.stringify())
    }
  }
}
