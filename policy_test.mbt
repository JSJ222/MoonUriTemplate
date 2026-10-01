///|
test "policy flags reserved expansion and source position" {
  let template = match @moonuritemplate.parse("/files/{+path}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let policy : @moonuritemplate.TemplatePolicy = {
    allow_reserved: false,
    allow_fragment: true,
    max_level: 4,
    max_references: 10,
    forbid_repeated_variables: false,
  }
  let findings = match template.check_policy(policy) {
    Ok(value) => value
    Err(_) => fail("policy")
  }
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].kind.code(), "reserved_expansion")
  assert_eq(findings[0].start, 7)
  assert_eq(findings[0].end, 14)
}

///|
test "policy reports feature level, fragment, and repeats" {
  let template = match @moonuritemplate.parse("{#x}{?x*}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let policy : @moonuritemplate.TemplatePolicy = {
    allow_reserved: false,
    allow_fragment: false,
    max_level: 2,
    max_references: 1,
    forbid_repeated_variables: true,
  }
  let findings = match template.check_policy(policy) {
    Ok(value) => value
    Err(_) => fail("policy")
  }
  assert_eq(findings.length(), 5)
  let counts : Map[String, Int] = Map([])
  for finding in findings {
    let code = finding.kind.code()
    counts[code] = counts.get_or_default(code, 0) + 1
  }
  assert_eq(counts.get_or_default("reserved_expansion", 0), 1)
  assert_eq(counts.get_or_default("fragment_expansion", 0), 1)
  assert_eq(counts.get_or_default("reference_limit_exceeded", 0), 1)
  assert_eq(counts.get_or_default("feature_level_exceeded", 0), 1)
  assert_eq(counts.get_or_default("repeated_variable", 0), 1)
}

///|
test "permissive policy produces no findings for Level 4 template" {
  let template = match @moonuritemplate.parse("{#x}{?x*}") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let findings = match
    template.check_policy(@moonuritemplate.permissive_policy()) {
    Ok(value) => value
    Err(_) => fail("policy")
  }
  assert_eq(findings.length(), 0)
}

///|
test "policy rejects invalid configuration" {
  let template = match @moonuritemplate.parse("x") {
    Ok(value) => value
    Err(_) => fail("parse")
  }
  let invalid : @moonuritemplate.TemplatePolicy = {
    allow_reserved: true,
    allow_fragment: true,
    max_level: 5,
    max_references: 1,
    forbid_repeated_variables: false,
  }
  assert_true(template.check_policy(invalid) is Err(InvalidFeatureLevel))
  let invalid_limit : @moonuritemplate.TemplatePolicy = {
    allow_reserved: true,
    allow_fragment: true,
    max_level: 4,
    max_references: -1,
    forbid_repeated_variables: false,
  }
  assert_true(
    template.check_policy(invalid_limit) is Err(InvalidReferenceLimit),
  )
}
