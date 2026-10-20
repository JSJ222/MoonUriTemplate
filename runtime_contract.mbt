///|
/// Application-level value shape; sparse and dense composites share a shape.
pub(all) enum BindingKind {
  TextValue
  ListValue
  AssociationValue
} derive(Eq)

///|
pub extend BindingKind with Eq::{equal, not_equal}

///|
pub(all) struct BindingRule {
  name : String
  kind : BindingKind
  required : Bool
}

///|
pub(all) enum ContractError {
  UnknownRule(String)
  DuplicateRule(String)
  IncompatibleRule(String)
  MissingRequired(String)
  WrongKind(String, BindingKind)
  InvalidBindings(ExpandError)
}

///|
/// Opt-in application contract. Unspecified variables retain RFC semantics.
pub struct ContractTemplate {
  priv template : Template
  priv rules : Array[BindingRule]
  priv reject_unused : Bool
  priv names : Map[String, Bool]
  priv scalar_names : Array[String]
}

///|
pub fn Template::with_contract(
  self : Template,
  rules : Array[BindingRule],
  reject_unused~ : Bool = true,
) -> Result[ContractTemplate, ContractError] {
  let profiles : Map[String, VariableProfile] = Map([])
  let names : Map[String, Bool] = Map([])
  let scalar_names : Array[String] = []
  for profile in self.variable_profiles() {
    profiles[profile.name] = profile
    names[profile.name] = true
    if profile.scalar_only {
      scalar_names.push(profile.name)
    }
  }
  let seen : Map[String, Bool] = Map([])
  for rule in rules {
    if seen.contains(rule.name) {
      return Err(DuplicateRule(rule.name))
    }
    seen[rule.name] = true
    let profile = match profiles.get(rule.name) {
      Some(value) => value
      None => return Err(UnknownRule(rule.name))
    }
    if profile.scalar_only && rule.kind != TextValue {
      return Err(IncompatibleRule(rule.name))
    }
  }
  Ok({
    template: self,
    rules: rules.copy(),
    reject_unused,
    names,
    scalar_names,
  })
}

///|
fn Value::binding_kind(self : Value) -> BindingKind {
  match self {
    Scalar(_) => TextValue
    List(_) | SparseList(_) => ListValue
    Assoc(_) | SparseAssoc(_) => AssociationValue
  }
}

///|
fn Value::has_defined_content(self : Value) -> Bool {
  match self {
    Scalar(_) => true
    List(items) => !items.is_empty()
    Assoc(items) => !items.is_empty()
    SparseList(items) => items.any(fn(item) { item is Some(_) })
    SparseAssoc(items) => items.any(fn(item) { item.1 is Some(_) })
  }
}

///|
/// Validate shape, presence and ordinary expansion limits without rendering.
/// Empty composites are undefined; an empty scalar is defined, as in RFC 6570.
pub fn ContractTemplate::validate(
  self : ContractTemplate,
  bindings : Array[(String, Value)],
  max_bindings~ : Int32 = 4096,
  max_value_length~ : Int32 = 1048576,
  max_items~ : Int32 = 4096,
) -> Result[Unit, ContractError] {
  if max_value_length < 0 {
    return Err(InvalidBindings(InvalidLimit("max_value_length")))
  }
  if max_items < 0 {
    return Err(InvalidBindings(InvalidLimit("max_items")))
  }
  let values = match
    prepare_bindings(bindings, max_bindings, max_value_length, max_items) {
    Ok(value) => value
    Err(error) => return Err(InvalidBindings(error))
  }
  if self.reject_unused {
    for (name, _) in bindings {
      if !self.names.contains(name) {
        return Err(InvalidBindings(UnusedVariable(name)))
      }
    }
  }
  for rule in self.rules {
    match values.get(rule.name) {
      None => if rule.required { return Err(MissingRequired(rule.name)) }
      Some(value) => {
        if value.binding_kind() != rule.kind {
          return Err(WrongKind(rule.name, rule.kind))
        }
        if rule.required && !value.has_defined_content() {
          return Err(MissingRequired(rule.name))
        }
      }
    }
  }
  // Also check restrictions on variables without an explicit application rule.
  for name in self.scalar_names {
    if values.get(name) is Some(value) && value.binding_kind() != TextValue {
      return Err(InvalidBindings(InvalidValue(name)))
    }
  }
  Ok(())
}

///|
pub fn ContractTemplate::expand(
  self : ContractTemplate,
  bindings : Array[(String, Value)],
  max_output~ : Int32 = 1048576,
  max_bindings~ : Int32 = 4096,
  max_value_length~ : Int32 = 1048576,
  max_items~ : Int32 = 4096,
) -> Result[String, ContractError] {
  match self.validate(bindings, max_bindings~, max_value_length~, max_items~) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match
    self.template.expand(
      bindings,
      max_output~,
      max_bindings~,
      max_value_length~,
      max_items~,
    ) {
    Ok(value) => Ok(value)
    Err(error) => Err(InvalidBindings(error))
  }
}
