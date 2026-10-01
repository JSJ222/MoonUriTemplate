///|
/// A preflight observation about the supplied bindings. Missing variables
/// are informational: RFC 6570 deliberately permits undefined variables.
pub(all) enum BindingIssue {
  Missing(String)
  Unused(String)
  Duplicate(String)
  CompositePrefix(String)
}

///|
pub struct BindingReport {
  issues : Array[BindingIssue]
}

///|
pub fn BindingReport::issues(self : BindingReport) -> Array[BindingIssue] {
  self.issues.copy()
}

///|
pub fn BindingReport::is_clean(self : BindingReport) -> Bool {
  self.issues.is_empty()
}

///|
pub fn BindingReport::missing_count(self : BindingReport) -> Int {
  let mut count = 0
  for issue in self.issues {
    if issue is Missing(_) {
      count += 1
    }
  }
  count
}

///|
pub fn BindingIssue::code(self : BindingIssue) -> String {
  match self {
    Missing(_) => "missing"
    Unused(_) => "unused"
    Duplicate(_) => "duplicate"
    CompositePrefix(_) => "composite_prefix"
  }
}

///|
pub fn BindingIssue::name(self : BindingIssue) -> String {
  match self {
    Missing(name) | Unused(name) | Duplicate(name) | CompositePrefix(name) => name
  }
}

///|
/// Inspect variable presence, duplicate bindings, and prefix/type conflicts
/// without expanding or exposing any bound value in the report.
pub fn Template::inspect_bindings(
  self : Template,
  bindings : Array[(String, Value)],
) -> BindingReport {
  let issues : Array[BindingIssue] = []
  let required : Map[String, Bool] = Map([])
  for name in self.variables {
    required[name] = true
  }
  let supplied : Map[String, Bool] = Map([])
  for binding in bindings {
    let (name, _) = binding
    if supplied.contains(name) {
      issues.push(Duplicate(name))
    } else {
      supplied[name] = true
      if !required.contains(name) {
        issues.push(Unused(name))
      }
    }
  }
  for name in self.variables {
    if !supplied.contains(name) {
      issues.push(Missing(name))
    }
  }
  let reported : Map[String, Bool] = Map([])
  for segment in self.segments {
    match segment {
      Literal(_) => ()
      Expression(_, specs, _, _) => for spec in specs {
        if spec.prefix is Some(_) && !reported.contains(spec.name) {
          for binding in bindings {
            let (name, value) = binding
            if name == spec.name {
              match value {
                Scalar(_) => ()
                _ => {
                  issues.push(CompositePrefix(name))
                  reported[name] = true
                }
              }
              break
            }
          }
        }
      }
    }
  }
  { issues, }
}
