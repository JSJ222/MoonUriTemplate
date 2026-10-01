///|
fn check_expansion(
  source : String,
  bindings : Array[(String, @moonuritemplate.Value)],
  expected : String,
) -> Unit raise {
  let template = match @moonuritemplate.parse(source) {
    Ok(value) => value
    Err(_) => fail("template parse failed")
  }
  let actual = match template.expand(bindings) {
    Ok(value) => value
    Err(_) => fail("template expansion failed")
  }
  assert_eq(actual, expected)
}

///|
fn standard_values() -> Array[(String, @moonuritemplate.Value)] {
  [
    ("var", Scalar("value")),
    ("hello", Scalar("Hello World!")),
    ("half", Scalar("50%")),
    ("path", Scalar("/foo/bar")),
    ("empty", Scalar("")),
    ("list", List(["red", "green", "blue"])),
    ("keys", Assoc([("semi", ";"), ("dot", "."), ("comma", ",")])),
  ]
}

///|
test "RFC 6570 simple and reserved expansion" {
  let values = standard_values()
  check_expansion("{var}", values, "value")
  check_expansion("{hello}", values, "Hello%20World%21")
  check_expansion("{+hello}", values, "Hello%20World!")
  check_expansion("{+path}/here", values, "/foo/bar/here")
  check_expansion("{#path}", values, "#/foo/bar")
  check_expansion("{half}", values, "50%25")
  check_expansion("{var,undef}", values, "value")
  check_expansion("{undef}", values, "")
}

///|
test "RFC 6570 label and path expansion" {
  let values = standard_values()
  check_expansion("X{.var}", values, "X.value")
  check_expansion("X{.empty}", values, "X.")
  check_expansion("{/var,empty}", values, "/value/")
  check_expansion("{/list}", values, "/red,green,blue")
  check_expansion("{/list*}", values, "/red/green/blue")
  check_expansion("{.list*}", values, ".red.green.blue")
  check_expansion("{.keys*}", values, ".semi=%3B.dot=..comma=%2C")
}

///|
test "RFC 6570 path and form parameters" {
  let values = standard_values()
  check_expansion("{;var,empty}", values, ";var=value;empty")
  check_expansion("{;list}", values, ";list=red,green,blue")
  check_expansion("{;list*}", values, ";list=red;list=green;list=blue")
  check_expansion("{?var,empty}", values, "?var=value&empty=")
  check_expansion("{?list}", values, "?list=red,green,blue")
  check_expansion("{?list*}", values, "?list=red&list=green&list=blue")
  check_expansion("{?keys*}", values, "?semi=%3B&dot=.&comma=%2C")
  check_expansion("?fixed=yes{&var}", values, "?fixed=yes&var=value")
}

///|
test "RFC 6570 prefix and composite values" {
  let values = standard_values()
  check_expansion("{var:3}", values, "val")
  check_expansion("{+path:6}", values, "/foo/b")
  check_expansion("{list}", values, "red,green,blue")
  check_expansion("{list*}", values, "red,green,blue")
  check_expansion("{keys}", values, "semi,%3B,dot,.,comma,%2C")
  check_expansion("{keys*}", values, "semi=%3B,dot=.,comma=%2C")
  check_expansion("{?keys}", values, "?keys=semi,%3B,dot,.,comma,%2C")
}

///|
test "Unicode scalar prefix and UTF-8 percent encoding" {
  check_expansion("{word:2}", [("word", Scalar("😀中A"))], "%F0%9F%98%80%E4%B8%AD")
  check_expansion("/城市/{name}", [("name", Scalar("北京"))], "/%E5%9F%8E%E5%B8%82/%E5%8C%97%E4%BA%AC")
}
