///|
test "contract diff flags added variables and scalar restrictions" {
  let before = match @moonuritemplate.parse("/users/{id}{?tags*}") {
    Ok(value) => value
    Err(_) => fail("old parse")
  }
  let after = match @moonuritemplate.parse("/users/{+id:3}{?tags*,page}{#id}") {
    Ok(value) => value
    Err(_) => fail("new parse")
  }
  let diff = before.diff_contract(after)
  assert_eq(diff.added_variables(), ["page"])
  assert_eq(diff.removed_variables().length(), 0)
  assert_eq(diff.became_scalar_only(), ["id"])
  assert_eq(diff.new_repeated_variables(), ["id"])
  assert_eq(diff.old_level(), 4)
  assert_eq(diff.new_level(), 4)
  assert_true(diff.reserved_added())
  assert_true(diff.fragment_added())
  assert_true(diff.has_flagged_changes())
}

///|
test "contract diff records removed variables in old source order" {
  let before = match @moonuritemplate.parse("{a}{b}{c}") {
    Ok(value) => value
    Err(_) => fail("old parse")
  }
  let after = match @moonuritemplate.parse("{c}") {
    Ok(value) => value
    Err(_) => fail("new parse")
  }
  let diff = before.diff_contract(after)
  assert_eq(diff.removed_variables(), ["a", "b"])
  assert_eq(diff.added_variables().length(), 0)
  assert_true(diff.has_flagged_changes())
}

///|
test "contract diff does not claim URI equivalence" {
  let before = match @moonuritemplate.parse("/users/{id}") {
    Ok(value) => value
    Err(_) => fail("old parse")
  }
  let after = match @moonuritemplate.parse("/accounts/{id}") {
    Ok(value) => value
    Err(_) => fail("new parse")
  }
  let diff = before.diff_contract(after)
  assert_true(!diff.has_flagged_changes())
  assert_true(before.source() != after.source())
}
