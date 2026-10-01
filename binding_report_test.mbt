///|
test "preflight reports missing, unused and duplicate bindings" {
  let template = match @moonuritemplate.parse("/{id}{?lang}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Array[(String, @moonuritemplate.Value)] = [
    ("id", Scalar("42")),
    ("id", Scalar("43")),
    ("trace", Scalar("yes")),
  ]
  let report = template.inspect_bindings(values)
  assert_eq(report.missing_count(), 1)
  assert_eq(report.issues().length(), 3)
  assert_eq(report.issues()[0].code(), "duplicate")
  assert_eq(report.issues()[1].code(), "unused")
  assert_eq(report.issues()[2].name(), "lang")
}

///|
test "preflight recognizes a composite prefix conflict" {
  let template = match @moonuritemplate.parse("{id:2}-{id}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Array[(String, @moonuritemplate.Value)] = [
    ("id", List(["one", "two"])),
  ]
  let report = template.inspect_bindings(values)
  assert_eq(report.issues().length(), 1)
  assert_eq(report.issues()[0].code(), "composite_prefix")
  assert_true(!report.is_clean())
}

///|
test "preflight is clean for complete scalar bindings" {
  let template = match @moonuritemplate.parse("{id}{?lang}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Array[(String, @moonuritemplate.Value)] = [
    ("id", Scalar("42")),
    ("lang", Scalar("zh-CN")),
  ]
  assert_true(template.inspect_bindings(values).is_clean())
}
