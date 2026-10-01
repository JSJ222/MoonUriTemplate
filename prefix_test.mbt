///|
test "prefix never splits a percent-encoded UTF-8 character" {
  let values : Array[(String, @moonuritemplate.Value)] = [
    ("ascii", Scalar("ab%2Fcd")),
    ("utf8", Scalar("%C3%A9tail")),
    ("emoji", Scalar("%F0%9F%98%80rest")),
  ]
  let cases = [
    ("{+ascii:3}", "ab%2F"),
    ("{ascii:3}", "ab%252F"),
    ("{+utf8:1}", "%C3%A9"),
    ("{utf8:1}", "%25C3%25A9"),
    ("{+emoji:1}", "%F0%9F%98%80"),
  ]
  for case in cases {
    let (source, expected) = case
    let template = match @moonuritemplate.parse(source) {
      Ok(value) => value
      Err(_) => fail("parse")
    }
    let actual = match template.expand(values) {
      Ok(value) => value
      Err(_) => fail("expand")
    }
    assert_eq(actual, expected)
  }
}

///|
test "invalid percent text still advances without splitting raw Unicode" {
  let template = match @moonuritemplate.parse("{+x:1}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let actual = match template.expand([("x", Scalar("%GGtail"))]) {
    Ok(value) => value
    Err(_) => fail("expand")
  }
  assert_eq(actual, "%25")
}
