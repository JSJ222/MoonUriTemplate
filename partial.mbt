///|
/// A template with some values fixed in advance. Useful for per-client base
/// paths or per-tenant URI prefixes that recur across many requests.
pub struct BoundTemplate {
  template : Template
  fixed : Array[(String, Value)]
  fixed_names : Map[String, Bool]
}

///|
fn Value::deep_copy(self : Value) -> Value {
  match self {
    Scalar(text) => Scalar(text)
    List(items) => List(items.copy())
    Assoc(entries) => Assoc(entries.copy())
    SparseList(items) => SparseList(items.copy())
    SparseAssoc(entries) => SparseAssoc(entries.copy())
  }
}

///|
/// Capture validated bindings without retaining caller-owned mutable arrays.
/// A bound name cannot be supplied again at expansion time.
pub fn Template::bind(
  self : Template,
  bindings : Array[(String, Value)],
  max_bindings? : Int = 4096,
  max_value_length? : Int = 1048576,
  max_items? : Int = 4096,
) -> Result[BoundTemplate, ExpandError] {
  if max_bindings < 0 || bindings.length() > max_bindings {
    return Err(TooManyBindings)
  }
  let fixed : Array[(String, Value)] = []
  let fixed_names : Map[String, Bool] = Map([])
  for binding in bindings {
    let (name, value) = binding
    if fixed_names.contains(name) {
      return Err(DuplicateVariable(name))
    }
    match check_value(value, name, max_value_length, max_items) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    fixed_names[name] = true
    fixed.push((name, value.deep_copy()))
  }
  Ok({ template: self, fixed, fixed_names, })
}

///|
pub fn BoundTemplate::fixed_names(self : BoundTemplate) -> Array[String] {
  let names : Array[String] = []
  for binding in self.fixed {
    names.push(binding.0)
  }
  names
}

///|
/// Supply request-local bindings to a partially bound template. Fixed values
/// are never overridden. The usual expansion budgets apply to the combined set.
pub fn BoundTemplate::expand(
  self : BoundTemplate,
  dynamic : Array[(String, Value)],
  max_output? : Int = 1048576,
  max_bindings? : Int = 4096,
  max_value_length? : Int = 1048576,
  max_items? : Int = 4096,
) -> Result[String, ExpandError] {
  let combined = match self.combine(dynamic, max_bindings) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  self.template.expand(
    combined,
    max_output~,
    max_bindings~,
    max_value_length~,
    max_items~,
  )
}

///|
fn BoundTemplate::combine(
  self : BoundTemplate,
  dynamic : Array[(String, Value)],
  max_bindings : Int,
) -> Result[Array[(String, Value)], ExpandError] {
  if max_bindings < 0 ||
    self.fixed.length() > max_bindings ||
    dynamic.length() > max_bindings - self.fixed.length() {
    return Err(TooManyBindings)
  }
  let combined = self.fixed.copy()
  for binding in dynamic {
    let (name, _) = binding
    if self.fixed_names.contains(name) {
      return Err(DuplicateVariable(name))
    }
    combined.push(binding)
  }
  Ok(combined)
}

///|
/// Measure a partially bound expansion before constructing its URI text.
pub fn BoundTemplate::measure(
  self : BoundTemplate,
  dynamic : Array[(String, Value)],
  max_output? : Int = 1048576,
  max_bindings? : Int = 4096,
  max_value_length? : Int = 1048576,
  max_items? : Int = 4096,
) -> Result[Int, ExpandError] {
  let combined = match self.combine(dynamic, max_bindings) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  self.template.measure(
    combined,
    max_output~,
    max_bindings~,
    max_value_length~,
    max_items~,
  )
}
