///|
test "JSON bridge sorts object keys and omits null members" {
  let input : Json = {
    "id": "42",
    "fields": ["name", null, "email"],
    "options": { "z": "last", "a": "first", "skip": null },
    "absent": null,
  }
  let bindings = match @moonuritemplate.bindings_from_json(input) {
    Ok(value) => value
    Err(_) => fail("JSON conversion")
  }
  assert_eq(bindings.length(), 3)
  let template = match @moonuritemplate.parse("/users/{id}{?fields*,options*}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let output = match template.expand(bindings) {
    Ok(value) => value
    Err(_) => fail("expand")
  }
  assert_eq(output, "/users/42?fields=name&fields=email&a=first&z=last")
}

///|
test "JSON bridge gives a pointer to unsupported nested values" {
  let input : Json = { "profile": { "a/b": 12 } }
  let error = match @moonuritemplate.bindings_from_json(input) {
    Err(error) => error
    Ok(_) => fail("number was accepted")
  }
  assert_eq(error.code(), "unsupported_value")
  assert_eq(error.path(), "/profile/a~1b")
}

///|
test "JSON bridge distinguishes absent null from empty string" {
  let input : Json = { "x": null, "y": "" }
  let bindings = match @moonuritemplate.bindings_from_json(input) {
    Ok(value) => value
    Err(_) => fail("convert")
  }
  let template = match @moonuritemplate.parse("{?x,y}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let output = match template.expand(bindings) {
    Ok(value) => value
    Err(_) => fail("expand")
  }
  assert_eq(output, "?y=")
}
