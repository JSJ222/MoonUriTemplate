///|
test "required expansion rejects a missing binding" {
  let template = match @moonuritemplate.parse("/users/{id}{?lang}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Array[(String, @moonuritemplate.Value)] = [("id", Scalar("42"))]
  assert_true(template.expand_required(values) is Err(MissingVariable("lang")))
  let output = match template.expand(values) {
    Ok(value) => value
    Err(_) => fail("ordinary expansion")
  }
  assert_eq(output, "/users/42")
}

///|
test "required expansion permits or rejects unused bindings by policy" {
  let template = match @moonuritemplate.parse("/{id}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Array[(String, @moonuritemplate.Value)] = [
    ("id", Scalar("42")),
    ("debug", Scalar("yes")),
  ]
  assert_true(template.expand_required(values) is Ok(_))
  assert_true(
    template.expand_required(values, reject_unused=true)
    is Err(UnusedVariable("debug")),
  )
}

///|
test "required expansion validates resource and duplicate limits" {
  let template = match @moonuritemplate.parse("{x}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let duplicate : Array[(String, @moonuritemplate.Value)] = [
    ("x", Scalar("a")),
    ("x", Scalar("b")),
  ]
  assert_true(
    template.expand_required(duplicate) is Err(DuplicateVariable("x")),
  )
  assert_true(
    template.expand_required(duplicate, max_bindings=1) is Err(TooManyBindings),
  )
  let one : Array[(String, @moonuritemplate.Value)] = [("x", Scalar("abc"))]
  assert_true(
    template.expand_required(one, max_value_length=2) is Err(ValueTooLong("x")),
  )
  assert_true(template.expand_required(one, max_output=2) is Err(OutputTooLong))
}
