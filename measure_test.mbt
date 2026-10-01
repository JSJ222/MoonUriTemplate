///|
test "measurement matches sparse composite and Unicode expansion" {
  let template = match @moonuritemplate.parse("é{/parts*}{?map*}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Array[(String, @moonuritemplate.Value)] = [
    ("parts", SparseList([Some("a/b"), None, Some("😀")])),
    ("map", SparseAssoc([("a", Some("é")), ("skip", None), ("b", Some(""))])),
  ]
  let output = match template.expand(values) {
    Ok(value) => value
    Err(_) => fail("expand")
  }
  let measured = match template.measure(values) {
    Ok(value) => value
    Err(_) => fail("measure")
  }
  assert_eq(measured, output.length())
  assert_eq(output, "%C3%A9/a%2Fb/%F0%9F%98%80?a=%C3%A9&b=")
}

///|
test "measurement enforces exact output boundary" {
  let template = match @moonuritemplate.parse("{?x*}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Array[(String, @moonuritemplate.Value)] = [
    ("x", List(["a/b", "é"])),
  ]
  let output = match template.expand(values) {
    Ok(value) => value
    Err(_) => fail("expand")
  }
  let length = output.length()
  assert_true(
    template.measure(values, max_output=length - 1) is Err(OutputTooLong),
  )
  let measured = match template.measure(values, max_output=length) {
    Ok(value) => value
    Err(_) => fail("exact budget")
  }
  assert_eq(measured, length)
}

///|
test "measurement checks malformed bindings before output" {
  let template = match @moonuritemplate.parse("{x}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let duplicate : Array[(String, @moonuritemplate.Value)] = [
    ("x", Scalar("a")),
    ("x", Scalar("b")),
  ]
  assert_true(template.measure(duplicate) is Err(DuplicateVariable("x")))
  assert_true(template.measure([], max_output=-1) is Err(OutputTooLong))
  assert_true(
    template.measure([], max_items=-1) is Err(InvalidLimit("max_items")),
  )
}

///|
test "measurement and rendering agree on absent and empty composites" {
  let sources = ["{x}", "{?x}", "{?x*}", "{;x}", "{;x*}", "{#x}"]
  let values : Array[@moonuritemplate.Value] = [
    List([]),
    Assoc([]),
    SparseList([None, None]),
    SparseAssoc([("a", None), ("b", None)]),
  ]
  for source in sources {
    let template = match @moonuritemplate.parse(source) {
      Ok(value) => value
      Err(_) => fail("parse")
    }
    let absent_length = match template.measure([]) {
      Ok(value) => value
      Err(_) => fail("absent measure")
    }
    assert_eq(absent_length, 0)
    for value in values {
      let bindings : Array[(String, @moonuritemplate.Value)] = [("x", value)]
      let output = match template.expand(bindings, max_output=0) {
        Ok(value) => value
        Err(_) => fail("empty composite render")
      }
      let measured = match template.measure(bindings, max_output=0) {
        Ok(value) => value
        Err(_) => fail("empty composite measure")
      }
      assert_eq(output, "")
      assert_eq(measured, 0)
    }
  }
}
