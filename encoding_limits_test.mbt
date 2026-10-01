///|
test "encoded scalar is rejected at exact UTF-8 output boundary" {
  let template = match @moonuritemplate.parse("{x}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Array[(String, @moonuritemplate.Value)] = [("x", Scalar("é"))]
  assert_true(template.expand(values, max_output=5) is Err(OutputTooLong))
  let output = match template.expand(values, max_output=6) {
    Ok(value) => value
    Err(_) => fail("expand")
  }
  assert_eq(output, "%C3%A9")
}

///|
test "encoded literal and encoded composite obey output boundary" {
  let literal = match @moonuritemplate.parse("é") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  assert_true(literal.expand([], max_output=5) is Err(OutputTooLong))
  assert_true(literal.expand([], max_output=6) is Ok(_))
  let composite = match @moonuritemplate.parse("{?x*}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Array[(String, @moonuritemplate.Value)] = [
    ("x", List(["a", "é"])),
  ]
  assert_true(composite.expand(values, max_output=12) is Err(OutputTooLong))
  assert_true(composite.expand(values, max_output=13) is Ok(_))
}

///|
test "reserved encoding keeps complete triplets within budget" {
  let template = match @moonuritemplate.parse("{+x}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Array[(String, @moonuritemplate.Value)] = [("x", Scalar("%2F/"))]
  assert_true(template.expand(values, max_output=3) is Err(OutputTooLong))
  let output = match template.expand(values, max_output=4) {
    Ok(value) => value
    Err(_) => fail("expand")
  }
  assert_eq(output, "%2F/")
}
