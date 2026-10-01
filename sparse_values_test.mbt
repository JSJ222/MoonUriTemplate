///|
test "undefined composite members do not emit separators" {
  let values : Array[(String, @moonuritemplate.Value)] = [
    ("a", SparseList([None, Some("red"), None, Some("blue")])),
    ("b", SparseAssoc([("missing", None), ("found", Some("yes"))])),
  ]
  let template = match @moonuritemplate.parse("{?a*,b*}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let actual = match template.expand(values) {
    Ok(value) => value
    Err(_) => fail("expand")
  }
  assert_eq(actual, "?a=red&a=blue&found=yes")
}

///|
test "all undefined composite entries make variable undefined" {
  let values : Array[(String, @moonuritemplate.Value)] = [
    ("a", SparseList([None])),
    ("b", SparseAssoc([("key", None)])),
  ]
  let template = match @moonuritemplate.parse("before{?a,b}after") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let actual = match template.expand(values) {
    Ok(value) => value
    Err(_) => fail("expand")
  }
  assert_eq(actual, "beforeafter")
}
