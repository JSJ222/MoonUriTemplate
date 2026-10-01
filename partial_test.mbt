///|
test "partially bound template combines tenant and request values" {
  let template = match
    @moonuritemplate.parse("/tenants/{tenant}/users/{id}{?fields*}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let fixed : Array[(String, @moonuritemplate.Value)] = [
    ("tenant", Scalar("alpha/beta")),
  ]
  let bound = match template.bind(fixed) {
    Ok(value) => value
    Err(_) => fail("bind")
  }
  assert_eq(bound.fixed_names(), ["tenant"])
  let dynamic : Array[(String, @moonuritemplate.Value)] = [
    ("id", Scalar("42")),
    ("fields", List(["name", "email"])),
  ]
  let output = match bound.expand(dynamic) {
    Ok(value) => value
    Err(_) => fail("expand")
  }
  assert_eq(output, "/tenants/alpha%2Fbeta/users/42?fields=name&fields=email")
}

///|
test "binding captures composite values before caller mutates them" {
  let template = match @moonuritemplate.parse("{?fields*}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let items = ["name"]
  let fixed : Array[(String, @moonuritemplate.Value)] = [
    ("fields", List(items)),
  ]
  let bound = match template.bind(fixed) {
    Ok(value) => value
    Err(_) => fail("bind")
  }
  items.push("email")
  let output = match bound.expand([]) {
    Ok(value) => value
    Err(_) => fail("expand")
  }
  assert_eq(output, "?fields=name")
}

///|
test "bound values cannot be overridden or duplicated" {
  let template = match @moonuritemplate.parse("/{id}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let fixed : Array[(String, @moonuritemplate.Value)] = [
    ("id", Scalar("first")),
  ]
  let bound = match template.bind(fixed) {
    Ok(value) => value
    Err(_) => fail("bind")
  }
  let override_value : Array[(String, @moonuritemplate.Value)] = [
    ("id", Scalar("second")),
  ]
  assert_true(bound.expand(override_value) is Err(DuplicateVariable("id")))
  assert_true(
    template.bind([("id", Scalar("a")), ("id", Scalar("b"))])
    is Err(DuplicateVariable("id")),
  )
}

///|
test "partially bound template applies combined binding and output budgets" {
  let template = match @moonuritemplate.parse("{a}{b}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let fixed : Array[(String, @moonuritemplate.Value)] = [("a", Scalar("a"))]
  let bound = match template.bind(fixed) {
    Ok(value) => value
    Err(_) => fail("bind")
  }
  let dynamic : Array[(String, @moonuritemplate.Value)] = [("b", Scalar("b"))]
  assert_true(bound.expand(dynamic, max_bindings=1) is Err(TooManyBindings))
  assert_true(bound.expand(dynamic, max_output=1) is Err(OutputTooLong))
  assert_true(template.bind(fixed, max_bindings=0) is Err(TooManyBindings))
}
