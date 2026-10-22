///|
fn main raise {
  let api : Json = {
    "openapi": "3.1.1",
    "info": { "title": "Inventory", "version": "1" },
    "components": {
      "schemas": {
        "Item": {
          "type": "object",
          "required": ["sku", "stock"],
          "properties": {
            "sku": { "type": "string" },
            "stock": { "type": "integer", "minimum": 0 },
          },
        },
      },
    },
    "paths": {
      "/items/{sku}": {
        "get": {
          "operationId": "getItem",
          "parameters": [
            {
              "in": "path",
              "name": "sku",
              "required": true,
              "schema": { "type": "string", "minLength": 1 },
            },
          ],
          "responses": {
            "200": {
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
  let workspace = @contracts.import_openapi(api, "inventory")
  let request : @contracts.Request = {
    parameters: [{ location: Path, name: "sku", value: "team/a", }],
    body: None,
    media_type: None,
  }
  assert_eq(workspace.request_path("getItem", request), "/items/team%2Fa")
  let response : @contracts.Response = {
    status: 200,
    headers: [],
    media_type: Some("application/json"),
    body: Some({ "sku": "team/a", "stock": 12 }),
  }
  assert_true(workspace.validate_response("getItem", response).is_empty())
  assert_true(
    !workspace
    .validate_response("getItem", {
      ..response,
      body: Some({ "sku": "team/a", "stock": -1 }),
    })
    .is_empty(),
  )
  assert_true(
    !workspace
    .validate_request("getItem", { ..request, parameters: [], })
    .is_empty(),
  )
  println("SDK preflight + response boundary: positive/negative checks passed")
}
