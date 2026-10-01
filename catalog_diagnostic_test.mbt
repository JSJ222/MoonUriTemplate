///|
test "catalog compilation diagnostics preserve name and source offset" {
  let error = match @moonuritemplate.compile_catalog([("bad", "prefix/{")]) {
    Err(value) => value
    Ok(_) => fail("invalid template")
  }
  assert_eq(error.code(), "invalid_template")
  assert_eq(error.name(), Some("bad"))
  let parse_error = match error.parse_error() {
    Some(value) => value
    None => fail("missing parse error")
  }
  assert_eq(parse_error.code(), "unclosed_expression")
  assert_eq(parse_error.offset(), Some(7))
}

///|
test "catalog expansion diagnostics retain named cause" {
  let catalog = match
    @moonuritemplate.compile_catalog([("user", "/users/{id}")]) {
    Ok(value) => value
    Err(_) => fail("catalog")
  }
  let bindings : Array[(String, @moonuritemplate.Value)] = [
    ("id", Scalar("a/b")),
  ]
  let error = match catalog.expand("user", bindings, max_output=5) {
    Err(value) => value
    Ok(_) => fail("output limit")
  }
  assert_eq(error.name(), "user")
  let cause = match error.expand_error() {
    Some(value) => value
    None => fail("missing expansion cause")
  }
  assert_eq(cause.code(), "output_too_long")
}

///|
test "mixed catalog batch diagnostics retain failing request index" {
  let catalog = match @moonuritemplate.compile_catalog([("user", "{id}")]) {
    Ok(value) => value
    Err(_) => fail("catalog")
  }
  let requests : Array[@moonuritemplate.CatalogRequest] = [
    { name: "user", bindings: [("id", Scalar("42"))], },
    { name: "missing", bindings: [], },
  ]
  let error = match catalog.expand_requests(requests) {
    Err(value) => value
    Ok(_) => fail("missing catalog key")
  }
  assert_eq(error.index(), Some(1))
}
