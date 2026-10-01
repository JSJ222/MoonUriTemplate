///|
/// Expand only when every referenced variable is bound. This opt-in policy is
/// useful for fixed SDK operations; ordinary RFC 6570 expansion allows missing
/// variables and remains available through `Template::expand`.
pub fn Template::expand_required(
  self : Template,
  bindings : Array[(String, Value)],
  reject_unused? : Bool = false,
  max_output? : Int = 1048576,
  max_bindings? : Int = 4096,
  max_value_length? : Int = 1048576,
  max_items? : Int = 4096,
) -> Result[String, ExpandError] {
  if max_bindings < 0 || bindings.length() > max_bindings {
    return Err(TooManyBindings)
  }
  let required : Map[String, Bool] = Map([])
  for name in self.variables {
    required[name] = true
  }
  let supplied : Map[String, Bool] = Map([])
  for binding in bindings {
    let (name, _) = binding
    if supplied.contains(name) {
      return Err(DuplicateVariable(name))
    }
    supplied[name] = true
    if reject_unused && !required.contains(name) {
      return Err(UnusedVariable(name))
    }
  }
  for name in self.variables {
    if !supplied.contains(name) {
      return Err(MissingVariable(name))
    }
  }
  self.expand(
    bindings,
    max_output~,
    max_bindings~,
    max_value_length~,
    max_items~,
  )
}
