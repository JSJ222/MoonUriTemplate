///|
test "static analysis reports expression spans and feature levels" {
  let template = match @moonuritemplate.parse("/users/{id}{?fields*,limit}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let analysis = template.analyze()
  assert_eq(analysis.max_level(), 4)
  assert_true(!analysis.has_reserved_expansion())
  let expressions = analysis.expressions()
  assert_eq(expressions.length(), 2)
  assert_eq(expressions[0].start, 7)
  assert_eq(expressions[0].end, 11)
  assert_eq(expressions[0].level, 1)
  assert_eq(expressions[1].operator, "?")
  assert_eq(expressions[1].variable_count, 2)
  assert_eq(expressions[1].level, 4)
}

///|
test "static analysis preserves each variable occurrence and modifier" {
  let template = match @moonuritemplate.parse("{+id:2}/{id}{?id,fields*}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let analysis = template.analyze()
  assert_true(analysis.has_reserved_expansion())
  assert_eq(template.reference_count("id"), 3)
  assert_eq(template.reference_count("missing"), 0)
  let uses = analysis.uses()
  assert_eq(uses.length(), 4)
  assert_eq(uses[0].name, "id")
  assert_eq(uses[0].operator, "+")
  assert_eq(uses[0].prefix, Some(2))
  assert_eq(uses[0].start, 2)
  assert_eq(uses[0].end, 6)
  assert_true(uses[3].explode)
  assert_eq(uses[3].expression_index, 2)
}
