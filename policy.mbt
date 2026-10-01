///|
/// Static restrictions for an application that consumes URI templates.
/// This checks template structure only; it cannot validate a final URI host.
pub(all) struct TemplatePolicy {
  allow_reserved : Bool
  allow_fragment : Bool
  max_level : Int
  max_references : Int
  forbid_repeated_variables : Bool
}

///|
/// Policy matching the syntactic capabilities of this library.
pub fn permissive_policy() -> TemplatePolicy {
  {
    allow_reserved: true,
    allow_fragment: true,
    max_level: 4,
    max_references: 4096,
    forbid_repeated_variables: false,
  }
}

///|
pub(all) enum PolicyError {
  InvalidFeatureLevel
  InvalidReferenceLimit
}

///|
pub fn PolicyError::code(self : PolicyError) -> String {
  match self {
    InvalidFeatureLevel => "invalid_feature_level"
    InvalidReferenceLimit => "invalid_reference_limit"
  }
}

///|
fn TemplatePolicy::validate(self : TemplatePolicy) -> Result[Unit, PolicyError] {
  if self.max_level < 1 || self.max_level > 4 {
    return Err(InvalidFeatureLevel)
  }
  if self.max_references < 0 {
    return Err(InvalidReferenceLimit)
  }
  Ok(())
}

///|
pub(all) enum PolicyFindingKind {
  ReservedExpansion
  FragmentExpansion
  FeatureLevelExceeded(Int)
  ReferenceLimitExceeded
  RepeatedVariable(String)
}

///|
pub fn PolicyFindingKind::code(self : PolicyFindingKind) -> String {
  match self {
    ReservedExpansion => "reserved_expansion"
    FragmentExpansion => "fragment_expansion"
    FeatureLevelExceeded(_) => "feature_level_exceeded"
    ReferenceLimitExceeded => "reference_limit_exceeded"
    RepeatedVariable(_) => "repeated_variable"
  }
}

///|
/// UTF-16 source range of a static policy finding.
pub(all) struct PolicyFinding {
  kind : PolicyFindingKind
  start : Int
  end : Int
}

///|
/// Check a compiled template without bindings. All findings are returned in
/// source order; a single expression may produce several distinct findings.
pub fn Template::check_policy(
  self : Template,
  policy : TemplatePolicy,
) -> Result[Array[PolicyFinding], PolicyError] {
  match policy.validate() {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let analysis = self.analyze()
  let findings : Array[PolicyFinding] = []
  let seen : Map[String, Bool] = Map([])
  let uses = analysis.uses()
  for expression in analysis.expressions() {
    if expression.level > policy.max_level {
      findings.push({
        kind: FeatureLevelExceeded(expression.level),
        start: expression.start,
        end: expression.end,
      })
    }
    if expression.permits_reserved && !policy.allow_reserved {
      findings.push({
        kind: ReservedExpansion,
        start: expression.start,
        end: expression.end,
      })
    }
    if expression.operator == "#" && !policy.allow_fragment {
      findings.push({
        kind: FragmentExpansion,
        start: expression.start,
        end: expression.end,
      })
    }
  }
  if uses.length() > policy.max_references {
    findings.push({
      kind: ReferenceLimitExceeded,
      start: 0,
      end: self.source.length(),
    })
  }
  if policy.forbid_repeated_variables {
    for use_ in uses {
      if seen.contains(use_.name) {
        findings.push({
          kind: RepeatedVariable(use_.name),
          start: use_.start,
          end: use_.end,
        })
      } else {
        seen[use_.name] = true
      }
    }
  }
  findings.sort_by(fn(a, b) { a.start.compare(b.start) })
  Ok(findings)
}
