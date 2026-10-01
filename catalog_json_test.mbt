///|
test "JSON catalog sorts endpoint names and renders a URI" {
  let manifest : Json = { "user": "/users/{id}{?fields*}", "health": "/health" }
  let catalog = match @moonuritemplate.compile_catalog_json(manifest) {
    Ok(value) => value
    Err(_) => fail("manifest")
  }
  assert_eq(catalog.names(), ["health", "user"])
  let values : Json = { "id": "a/b", "fields": ["name", "email"] }
  let output = match catalog.expand_json("user", values) {
    Ok(value) => value
    Err(_) => fail("catalog JSON render")
  }
  assert_eq(output, "/users/a%2Fb?fields=name&fields=email")
}

///|
test "JSON catalog reports malformed manifest at escaped pointer" {
  let manifest : Json = { "a/b": 42 }
  let error = match @moonuritemplate.compile_catalog_json(manifest) {
    Err(value) => value
    Ok(_) => fail("numeric template")
  }
  assert_eq(error.code(), "template_must_be_string")
  assert_eq(error.path(), "/a~1b")
  assert_true(
    @moonuritemplate.compile_catalog_json(["not", "an", "object"])
    is Err(RootMustBeObject),
  )
}

///|
test "JSON catalog preserves template parser cause" {
  let manifest : Json = { "bad": "{" }
  let error = match @moonuritemplate.compile_catalog_json(manifest) {
    Err(value) => value
    Ok(_) => fail("invalid syntax")
  }
  assert_eq(error.code(), "compile_invalid_template")
  assert_true(
    error is Compilation(InvalidTemplate("bad", UnclosedExpression(0))),
  )
}

///|
test "JSON catalog distinguishes unknown endpoint and bad value" {
  let catalog = match
    @moonuritemplate.compile_catalog_json({ "user": "{id}" }) {
    Ok(value) => value
    Err(_) => fail("manifest")
  }
  let missing = match catalog.expand_json("missing", { "id": "42" }) {
    Err(value) => value
    Ok(_) => fail("unknown endpoint")
  }
  assert_eq(missing.code(), "catalog_unknown_template")
  let invalid = match catalog.expand_json("user", { "id": true }) {
    Err(value) => value
    Ok(_) => fail("boolean was accepted")
  }
  assert_eq(invalid.code(), "json_unsupported_value")
}
