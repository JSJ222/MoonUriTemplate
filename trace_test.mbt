///|
test "detailed expansion maps defined and omitted expressions" {
  let template = match @moonuritemplate.parse("A/{id}{?q}!") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Array[(String, @moonuritemplate.Value)] = [("id", Scalar("a/b"))]
  let rendered = match template.expand_detailed(values) {
    Ok(value) => value
    Err(_) => fail("expand")
  }
  assert_eq(rendered.text(), "A/a%2Fb!")
  let spans = rendered.spans()
  assert_eq(spans.length(), 4)
  assert_eq(spans[0].source_start, 0)
  assert_eq(spans[0].source_end, 2)
  assert_eq(spans[0].output_start, 0)
  assert_eq(spans[0].output_end, 2)
  assert_true(!spans[0].is_expression)
  assert_eq(spans[1].source_start, 2)
  assert_eq(spans[1].source_end, 6)
  assert_eq(spans[1].output_start, 2)
  assert_eq(spans[1].output_end, 7)
  assert_true(spans[1].is_expression)
  assert_eq(spans[2].source_start, 6)
  assert_eq(spans[2].source_end, 10)
  assert_eq(spans[2].output_start, 7)
  assert_eq(spans[2].output_end, 7)
  assert_eq(spans[3].source_start, 10)
  assert_eq(spans[3].source_end, 11)
  assert_eq(spans[3].output_start, 7)
  assert_eq(spans[3].output_end, 8)
}

///|
test "detailed offsets account for UTF-8 encoding growth" {
  let template = match @moonuritemplate.parse("é/{x}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Array[(String, @moonuritemplate.Value)] = [("x", Scalar("😀"))]
  let rendered = match template.expand_detailed(values) {
    Ok(value) => value
    Err(_) => fail("expand")
  }
  assert_eq(rendered.text(), "%C3%A9/%F0%9F%98%80")
  let spans = rendered.spans()
  assert_eq(spans[0].source_end, 2)
  assert_eq(spans[0].output_end, 7)
  assert_eq(spans[1].source_start, 2)
  assert_eq(spans[1].source_end, 5)
  assert_eq(spans[1].output_start, 7)
  assert_eq(spans[1].output_end, 19)
}

///|
test "detailed expansion enforces the same output budget" {
  let template = match @moonuritemplate.parse("{x}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let values : Array[(String, @moonuritemplate.Value)] = [("x", Scalar("a/b"))]
  assert_true(
    template.expand_detailed(values, max_output=4) is Err(OutputTooLong),
  )
  assert_true(template.expand_detailed(values, max_output=5) is Ok(_))
}
