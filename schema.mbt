///|
/// Aggregate requirements for one variable across all uses in a template.
/// RFC 6570 variables remain optional unless the caller uses `expand_required`.
pub(all) struct VariableProfile {
  name : String
  occurrences : Int
  first_start : Int
  last_end : Int
  scalar_only : Bool
  uses_explode : Bool
  uses_reserved : Bool
  uses_query : Bool
  maximum_prefix : Int?
}

///|
/// Derive an SDK-oriented variable schema from a compiled template. Profiles
/// retain first-appearance order. A prefix modifier on any occurrence forces
/// a scalar binding for that variable under this implementation.
pub fn Template::variable_profiles(self : Template) -> Array[VariableProfile] {
  let profiles : Array[VariableProfile] = []
  let indexes : Map[String, Int] = Map([])
  for segment in self.segments {
    match segment {
      Literal(_) => ()
      Expression(op, specs, _, _) =>
        for spec in specs {
          let query = op is Query || op is QueryContinuation
          let reserved = operator_allows_reserved(op)
          match indexes.get(spec.name) {
            None => {
              indexes[spec.name] = profiles.length()
              profiles.push({
                name: spec.name,
                occurrences: 1,
                first_start: spec.start,
                last_end: spec.end,
                scalar_only: spec.prefix is Some(_),
                uses_explode: spec.explode,
                uses_reserved: reserved,
                uses_query: query,
                maximum_prefix: spec.prefix,
              })
            }
            Some(index) => {
              let previous = profiles[index]
              let max_prefix = match (previous.maximum_prefix, spec.prefix) {
                (None, None) => None
                (Some(value), None) | (None, Some(value)) => Some(value)
                (Some(left), Some(right)) =>
                  Some(if left > right { left } else { right })
              }
              profiles[index] = {
                name: previous.name,
                occurrences: previous.occurrences + 1,
                first_start: previous.first_start,
                last_end: spec.end,
                scalar_only: previous.scalar_only || spec.prefix is Some(_),
                uses_explode: previous.uses_explode || spec.explode,
                uses_reserved: previous.uses_reserved || reserved,
                uses_query: previous.uses_query || query,
                maximum_prefix: max_prefix,
              }
            }
          }
        }
    }
  }
  profiles
}

///|
/// Names that can accept a list or association value in every occurrence.
/// This does not imply a composite is required; scalar values also work.
pub fn Template::composite_capable_variables(self : Template) -> Array[String] {
  let names : Array[String] = []
  for profile in self.variable_profiles() {
    if !profile.scalar_only {
      names.push(profile.name)
    }
  }
  names
}
