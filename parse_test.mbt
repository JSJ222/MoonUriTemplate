///|
test "template parser accepts the complete operator set" {
  let cases = [
    "{x}", "{+x}", "{#x}", "{.x}", "{/x}", "{;x}", "{?x}", "{&x}",
    "{x:9999}", "{x*}", "{x,y.z}", "{a%20b}", "fixed%2Fpath",
  ]
  for case in cases {
    assert_true(@moonuritemplate.parse(case) is Ok(_))
  }
}

///|
test "template parser rejects malformed braces and operator spellings" {
  let cases = [
    "{", "}", "{}", "{+}", "{{x}}", "{x}}", "{=x}", "{,x}", "{!x}",
    "{@x}", "{|x}",
  ]
  for case in cases {
    assert_true(@moonuritemplate.parse(case) is Err(_))
  }
}

///|
test "template parser rejects malformed names and modifiers" {
  let cases = [
    "{a.}", "{.a,}", "{a..b}", "{a,}", "{a,,b}", "{a:}", "{a:0}",
    "{a:0001}", "{a:10000}", "{a:*}", "{a**}", "{a:2*}", "{a%GG}",
    "{a%2}", "{%}", "{a-b}",
  ]
  for case in cases {
    assert_true(@moonuritemplate.parse(case) is Err(_))
  }
}

///|
test "template parser rejects malformed literals" {
  let cases = ["a%", "a%G0", "a b", "a\n", "a|b", "a\\b", "a'b", "a\u{80}b", "a\u{FDD0}b"]
  for case in cases {
    assert_true(@moonuritemplate.parse(case) is Err(_))
  }
}

///|
test "compatibility mode accepts the legacy apostrophe test vector" {
  assert_true(@moonuritemplate.parse("'{var}'") is Err(_))
  assert_true(@moonuritemplate.parse("'{var}'", strict_literals=false) is Ok(_))
}

///|
test "parser reports distinct resource limits" {
  assert_true(@moonuritemplate.parse("abc", max_length=2) is Err(InputTooLong))
  assert_true(@moonuritemplate.parse("{x}{y}", max_expressions=1) is Err(TooManyExpressions))
  assert_true(@moonuritemplate.parse("{x,y}", max_variables=1) is Err(TooManyVariables))
}

///|
test "template metadata has unique first-appearance variable names" {
  let parsed = match @moonuritemplate.parse("/v/{id}/{id}{?lang,id}") {
    Ok(value) => value
    Err(_) => fail("expected a valid template")
  }
  assert_eq(parsed.source(), "/v/{id}/{id}{?lang,id}")
  assert_eq(parsed.variables().length(), 2)
  assert_eq(parsed.variables()[0], "id")
  assert_eq(parsed.variables()[1], "lang")
}
