///|
test "parse errors preserve code and UTF-16 location" {
  let error = match @moonuritemplate.parse("ok/{x:0}") {
    Err(error) => error
    Ok(_) => fail("invalid prefix was accepted")
  }
  assert_eq(error.code(), "invalid_modifier")
  assert_eq(error.offset(), Some(6))
  assert_true(error.message().length() > 0)
}

///|
test "single-use API keeps the parse or expansion error kind" {
  assert_true(@moonuritemplate.expand("{bad:0}", []) is Err(Parse(_)))
  let duplicate : Array[(String, @moonuritemplate.Value)] = [
    ("x", Scalar("one")),
    ("x", Scalar("two")),
  ]
  assert_true(
    @moonuritemplate.expand("{x}", duplicate)
    is Err(Expand(DuplicateVariable(_))),
  )
}

///|
test "invalid composite prefix and output limit are explicit errors" {
  let values : Array[(String, @moonuritemplate.Value)] = [
    ("x", List(["a", "b"])),
  ]
  assert_true(
    @moonuritemplate.expand("{x:2}", values) is Err(Expand(InvalidValue(_))),
  )
  assert_true(
    @moonuritemplate.expand("/{x}", [("x", Scalar("value"))], max_output=3)
    is Err(Expand(OutputTooLong)),
  )
}
