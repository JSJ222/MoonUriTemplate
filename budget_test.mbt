///|
test "bounded expansion stops before assembling an oversized list" {
  let values : Array[(String, @moonuritemplate.Value)] = [
    ("parts", List(["aa", "bb", "cc", "dd"])),
  ]
  let template = match @moonuritemplate.parse("{?parts*}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  assert_true(template.expand(values, max_output=19) is Err(OutputTooLong))
  assert_true(template.expand(values, max_output=36) is Ok(_))
}

///|
test "bounded expansion checks binding count and individual value length" {
  let template = match @moonuritemplate.parse("{x}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Array[(String, @moonuritemplate.Value)] = [
    ("x", Scalar("abc")),
    ("unused", Scalar("z")),
  ]
  assert_true(template.expand(values, max_bindings=1) is Err(TooManyBindings))
  assert_true(
    template.expand(values, max_value_length=2) is Err(ValueTooLong(_)),
  )
}

///|
test "bounded expansion checks composite item counts" {
  let template = match @moonuritemplate.parse("{?x*}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Array[(String, @moonuritemplate.Value)] = [
    ("x", Assoc([("a", "1"), ("b", "2")])),
  ]
  assert_true(template.expand(values, max_items=1) is Err(TooManyItems(_)))
  assert_true(template.expand(values, max_items=2) is Ok(_))
}

///|
test "empty expansion fits a zero-sized output budget" {
  let template = match @moonuritemplate.parse("{?x}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let result = template.expand([], max_output=0)
  assert_true(result is Ok(""))
}
