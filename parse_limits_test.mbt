///|
test "negative parser limits are rejected even for empty templates" {
  assert_true(@moonuritemplate.parse("", max_length=-1) is Err(InputTooLong))
  assert_true(
    @moonuritemplate.parse("", max_expressions=-1) is Err(TooManyExpressions),
  )
  assert_true(
    @moonuritemplate.parse("", max_variables=-1) is Err(TooManyVariables),
  )
}

///|
test "zero parser budgets admit literals but reject expressions" {
  assert_true(
    @moonuritemplate.parse("abc", max_expressions=0, max_variables=0) is Ok(_),
  )
  assert_true(
    @moonuritemplate.parse("{x}", max_expressions=0) is Err(TooManyExpressions),
  )
  assert_true(
    @moonuritemplate.parse("{x}", max_variables=0) is Err(TooManyVariables),
  )
}
