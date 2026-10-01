///|
test "JSON render expands a decoded SDK parameter object" {
  let template = match @moonuritemplate.parse("/users/{id}{?fields*,limit}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Json = {
    "id": "a/b",
    "fields": ["name", "email"],
    "limit": "20",
  }
  let output = match template.expand_json(values) {
    Ok(value) => value
    Err(_) => fail("render")
  }
  assert_eq(output, "/users/a%2Fb?fields=name&fields=email&limit=20")
}

///|
test "JSON render identifies conversion error at exact pointer" {
  let template = match @moonuritemplate.parse("{x}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Json = { "x": ["ok", 5] }
  let error = match template.expand_json(values) {
    Err(value) => value
    Ok(_) => fail("number was accepted")
  }
  assert_eq(error.code(), "json_unsupported_value")
  assert_true(error is Conversion(UnsupportedValue("/x/1")))
}

///|
test "JSON render distinguishes output and parse failures" {
  let values : Json = { "x": "é" }
  let template = match @moonuritemplate.parse("{x}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let error = match template.expand_json(values, max_output=5) {
    Err(value) => value
    Ok(_) => fail("output limit")
  }
  assert_eq(error.code(), "expand_output_too_long")
  let parse_error = match @moonuritemplate.expand_json("{", values) {
    Err(value) => value
    Ok(_) => fail("invalid syntax")
  }
  assert_eq(parse_error.code(), "parse_unclosed_expression")
}
