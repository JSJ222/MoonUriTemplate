///|
test "catalog audit identifies policy findings by endpoint" {
  let catalog = match
    @moonuritemplate.compile_catalog([
      ("health", "/health"),
      ("search", "/search{?q}"),
      ("proxy", "{+target}"),
    ]) {
    Ok(value) => value
    Err(_) => fail("catalog")
  }
  let policy : @moonuritemplate.TemplatePolicy = {
    allow_reserved: false,
    allow_fragment: false,
    max_level: 3,
    max_references: 4,
    forbid_repeated_variables: true,
  }
  let audit = match catalog.audit(policy) {
    Ok(value) => value
    Err(_) => fail("audit")
  }
  let entries = audit.entries()
  assert_eq(entries.length(), 3)
  assert_eq(entries[0].name(), "health")
  assert_eq(entries[0].expression_count(), 0)
  assert_eq(entries[1].name(), "search")
  assert_eq(entries[1].variable_count(), 1)
  assert_eq(entries[2].name(), "proxy")
  assert_eq(entries[2].max_level(), 2)
  assert_eq(entries[2].findings().length(), 1)
  assert_eq(entries[2].findings()[0].kind.code(), "reserved_expansion")
  assert_eq(audit.total_findings(), 1)
  assert_true(!audit.is_clean())
}

///|
test "empty catalog still rejects invalid audit policy" {
  let catalog = match @moonuritemplate.compile_catalog([]) {
    Ok(value) => value
    Err(_) => fail("catalog")
  }
  let invalid : @moonuritemplate.TemplatePolicy = {
    allow_reserved: true,
    allow_fragment: true,
    max_level: 0,
    max_references: 0,
    forbid_repeated_variables: false,
  }
  assert_true(catalog.audit(invalid) is Err(InvalidFeatureLevel))
  let valid = match catalog.audit(@moonuritemplate.permissive_policy()) {
    Ok(value) => value
    Err(_) => fail("valid audit")
  }
  assert_true(valid.is_clean())
  assert_eq(valid.entries().length(), 0)
}
