///|
test "parser and expander handle the configured expression boundary" {
  let source = StringBuilder()
  for _ in 0..<1024 {
    source.write_string("{x}")
  }
  let template = match @moonuritemplate.parse(source.to_string()) {
    Ok(value) => value
    Err(_) => fail("parse at expression limit")
  }
  assert_eq(template.reference_count("x"), 1024)
  let values : Array[(String, @moonuritemplate.Value)] = [("x", Scalar("a"))]
  let output = match template.expand(values, max_output=1024) {
    Ok(value) => value
    Err(_) => fail("expand at output limit")
  }
  assert_eq(output.length(), 1024)
  assert_true(template.expand(values, max_output=1023) is Err(OutputTooLong))
  source.write_string("{x}")
  assert_true(
    @moonuritemplate.parse(source.to_string()) is Err(TooManyExpressions),
  )
}

///|
test "many distinct bindings remain addressable through indexed lookup" {
  let source = StringBuilder()
  let bindings : Array[(String, @moonuritemplate.Value)] = []
  for i in 0..<512 {
    if i > 0 {
      source.write_string("/")
    }
    let name = "v" + i.to_string()
    source.write_string("{")
    source.write_string(name)
    source.write_string("}")
    bindings.push((name, Scalar(i.to_string())))
  }
  let template = match @moonuritemplate.parse(source.to_string()) {
    Ok(value) => value
    Err(_) => fail("parse many variables")
  }
  assert_eq(template.variables().length(), 512)
  let output = match template.expand(bindings) {
    Ok(value) => value
    Err(_) => fail("expand many variables")
  }
  assert_true(output.has_prefix("0/1/2/3"))
  assert_true(output.has_suffix("/509/510/511"))
}

///|
test "single-call, compiled, and batch paths agree across operators" {
  let sources = [
    "{x}", "{+x}", "{#x}", "{.x}", "{/x}", "{;x}", "{?x}", "{&x}", "{?x*}",
  ]
  let values : Array[(String, @moonuritemplate.Value)] = [
    ("x", Scalar("a/b c")),
  ]
  for source in sources {
    let template = match @moonuritemplate.parse(source) {
      Ok(value) => value
      Err(_) => fail("parse operator")
    }
    let single = match @moonuritemplate.expand(source, values) {
      Ok(value) => value
      Err(_) => fail("single-call expansion")
    }
    let compiled = match template.expand(values) {
      Ok(value) => value
      Err(_) => fail("compiled expansion")
    }
    let batch = match template.expand_many([values]) {
      Ok(value) => value
      Err(_) => fail("batch expansion")
    }
    assert_eq(compiled, single)
    assert_eq(batch[0], single)
  }
}
