///|
test "profiles combine repeated variable constraints" {
  let template = match
    @moonuritemplate.parse("/users/{id}{?id,fields*}{+id:3}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let profiles = template.variable_profiles()
  assert_eq(profiles.length(), 2)
  assert_eq(profiles[0].name, "id")
  assert_eq(profiles[0].occurrences, 3)
  assert_eq(profiles[0].first_start, 8)
  assert_eq(profiles[0].last_end, 30)
  assert_true(profiles[0].scalar_only)
  assert_true(profiles[0].uses_reserved)
  assert_true(profiles[0].uses_query)
  assert_eq(profiles[0].maximum_prefix, Some(3))
  assert_eq(profiles[1].name, "fields")
  assert_eq(profiles[1].occurrences, 1)
  assert_true(profiles[1].uses_explode)
  assert_true(!profiles[1].scalar_only)
  assert_eq(template.composite_capable_variables(), ["fields"])
}

///|
test "profile prefix maximum and source span are stable" {
  let template = match @moonuritemplate.parse("{x:2}/{x:5}/{x}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let profiles = template.variable_profiles()
  assert_eq(profiles.length(), 1)
  assert_eq(profiles[0].occurrences, 3)
  assert_eq(profiles[0].maximum_prefix, Some(5))
  assert_eq(profiles[0].first_start, 1)
  assert_eq(profiles[0].last_end, 14)
  assert_true(profiles[0].scalar_only)
}

///|
test "empty template has no variable profiles" {
  let template = match @moonuritemplate.parse("/health") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  assert_eq(template.variable_profiles().length(), 0)
  assert_eq(template.composite_capable_variables().length(), 0)
}
