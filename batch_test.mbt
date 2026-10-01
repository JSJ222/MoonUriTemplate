///|
test "batch expansion reuses one compiled template across rows" {
  let template = match @moonuritemplate.parse("/users/{id}{?lang}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let inputs : Array[Array[(String, @moonuritemplate.Value)]] = [
    [("id", Scalar("1")), ("lang", Scalar("en"))],
    [("id", Scalar("two/three"))],
    [("id", Scalar("三")), ("lang", Scalar("zh"))],
  ]
  let result = match template.expand_many(inputs) {
    Ok(value) => value
    Err(_) => fail("batch")
  }
  assert_eq(result.length(), 3)
  assert_eq(result[0], "/users/1?lang=en")
  assert_eq(result[1], "/users/two%2Fthree")
  assert_eq(result[2], "/users/%E4%B8%89?lang=zh")
}

///|
test "batch expansion reports exact failing row" {
  let template = match @moonuritemplate.parse("{id}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let inputs : Array[Array[(String, @moonuritemplate.Value)]] = [
    [("id", Scalar("1"))],
    [("id", Scalar("first")), ("id", Scalar("second"))],
    [("id", Scalar("3"))],
  ]
  let error = match template.expand_many(inputs) {
    Err(value) => value
    Ok(_) => fail("duplicate was accepted")
  }
  assert_eq(error.code(), "invalid_item")
  assert_eq(error.index(), Some(1))
  assert_true(error is InvalidItem(1, DuplicateVariable("id")))
}

///|
test "batch limits cover input count, each row, and aggregate output" {
  let template = match @moonuritemplate.parse("{x}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let inputs : Array[Array[(String, @moonuritemplate.Value)]] = [
    [("x", Scalar("ab"))],
    [("x", Scalar("cd"))],
  ]
  assert_true(template.expand_many(inputs, max_inputs=1) is Err(TooManyInputs))
  assert_true(
    template.expand_many(inputs, max_each_output=1)
    is Err(InvalidItem(0, OutputTooLong)),
  )
  assert_true(
    template.expand_many(inputs, max_total_output=3) is Err(TotalOutputTooLong),
  )
  assert_true(template.expand_many([], max_total_output=0) is Ok(_))
  assert_true(
    template.expand_many([], max_total_output=-1) is Err(TotalOutputTooLong),
  )
}
