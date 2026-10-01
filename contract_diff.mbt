///|
/// Structural changes between two compiled templates. This is a source-level
/// report for API reviews, not a proof that two templates render equivalent
/// URIs or that a deployment is backward compatible.
pub struct TemplateDiff {
  added_variables : Array[String]
  removed_variables : Array[String]
  became_scalar_only : Array[String]
  new_repeated_variables : Array[String]
  old_level : Int
  new_level : Int
  reserved_added : Bool
  fragment_added : Bool
}

///|
pub fn TemplateDiff::added_variables(self : TemplateDiff) -> Array[String] {
  self.added_variables.copy()
}

///|
pub fn TemplateDiff::removed_variables(self : TemplateDiff) -> Array[String] {
  self.removed_variables.copy()
}

///|
pub fn TemplateDiff::became_scalar_only(self : TemplateDiff) -> Array[String] {
  self.became_scalar_only.copy()
}

///|
pub fn TemplateDiff::new_repeated_variables(
  self : TemplateDiff,
) -> Array[String] {
  self.new_repeated_variables.copy()
}

///|
pub fn TemplateDiff::old_level(self : TemplateDiff) -> Int {
  self.old_level
}

///|
pub fn TemplateDiff::new_level(self : TemplateDiff) -> Int {
  self.new_level
}

///|
pub fn TemplateDiff::reserved_added(self : TemplateDiff) -> Bool {
  self.reserved_added
}

///|
pub fn TemplateDiff::fragment_added(self : TemplateDiff) -> Bool {
  self.fragment_added
}

///|
pub fn TemplateDiff::has_flagged_changes(self : TemplateDiff) -> Bool {
  !self.added_variables.is_empty() ||
  !self.removed_variables.is_empty() ||
  !self.became_scalar_only.is_empty() ||
  !self.new_repeated_variables.is_empty() ||
  self.old_level != self.new_level ||
  self.reserved_added ||
  self.fragment_added
}

///|
fn Template::uses_fragment(self : Template) -> Bool {
  for expression in self.analyze().expressions() {
    if expression.operator == "#" {
      return true
    }
  }
  false
}

///|
/// Compare variable and operator requirements before replacing a deployed
/// template. Added variables matter to `expand_required`; newly scalar-only
/// variables can reject previously valid composite bindings.
pub fn Template::diff_contract(
  self : Template,
  next : Template,
) -> TemplateDiff {
  let old_profiles = self.variable_profiles()
  let new_profiles = next.variable_profiles()
  let old_by_name : Map[String, VariableProfile] = Map([])
  let new_by_name : Map[String, VariableProfile] = Map([])
  for profile in old_profiles {
    old_by_name[profile.name] = profile
  }
  for profile in new_profiles {
    new_by_name[profile.name] = profile
  }
  let added_variables : Array[String] = []
  let removed_variables : Array[String] = []
  let became_scalar_only : Array[String] = []
  let new_repeated_variables : Array[String] = []
  for profile in new_profiles {
    match old_by_name.get(profile.name) {
      None => added_variables.push(profile.name)
      Some(previous) => {
        if profile.scalar_only && !previous.scalar_only {
          became_scalar_only.push(profile.name)
        }
        if profile.occurrences > 1 && profile.occurrences > previous.occurrences {
          new_repeated_variables.push(profile.name)
        }
      }
    }
  }
  for profile in old_profiles {
    if !new_by_name.contains(profile.name) {
      removed_variables.push(profile.name)
    }
  }
  let before = self.analyze()
  let after = next.analyze()
  {
    added_variables,
    removed_variables,
    became_scalar_only,
    new_repeated_variables,
    old_level: before.max_level(),
    new_level: after.max_level(),
    reserved_added: after.has_reserved_expansion() &&
    !before.has_reserved_expansion(),
    fragment_added: next.uses_fragment() && !self.uses_fragment(),
  }
}
