///|
pub(all) enum BindingChange {
  SetBinding(String, Value)
  RemoveBinding(String)
}

///|
pub(all) enum LinkSessionError {
  InvalidBudget
  TooManyChanges
  DuplicateChange(String)
  InvalidBindings(ExpandError)
  InvalidEndpoint(String, ExpandError)
  TotalOutputTooLong
}

///|
pub(all) struct LinkChange {
  name : String
  before : String
  after : String
}

///|
/// Immutable snapshot with a private dependency index and captured bindings.
pub struct LinkSession {
  priv catalog : TemplateCatalog
  priv dependencies : Map[String, Array[Int32]]
  priv values : Map[String, Value]
  priv outputs : Array[String]
  priv total : Int32
  priv each_limit : Int32
  priv total_limit : Int32
  priv binding_limit : Int32
  priv value_limit : Int32
  priv item_limit : Int32
}

///|
pub struct LinkUpdate {
  priv session : LinkSession
  priv changes : Array[LinkChange]
  priv recomputed : Int32
}

///|
pub fn LinkUpdate::session(self : LinkUpdate) -> LinkSession {
  self.session
}

///|
pub fn LinkUpdate::changes(self : LinkUpdate) -> Array[LinkChange] {
  self.changes.copy()
}

///|
pub fn LinkUpdate::recomputed(self : LinkUpdate) -> Int32 {
  self.recomputed
}

///|
pub fn LinkSession::links(self : LinkSession) -> Array[(String, String)] {
  let links = []
  for index, name in self.catalog.names {
    links.push((name, self.outputs[index]))
  }
  links
}

///|
pub fn LinkSession::total_length(self : LinkSession) -> Int32 {
  self.total
}

///|
fn Template::session_bindings(
  self : Template,
  values : Map[String, Value],
) -> Array[(String, Value)] {
  let bindings = []
  for name in self.variables {
    if values.get(name) is Some(value) {
      bindings.push((name, value))
    }
  }
  bindings
}

///|
/// Capture shared bindings and generate every endpoint once. Unknown bindings
/// are rejected; missing variables retain ordinary RFC omission semantics.
pub fn TemplateCatalog::start_session(
  self : TemplateCatalog,
  bindings : Array[(String, Value)],
  max_each_output~ : Int32 = 1048576,
  max_total_output~ : Int32 = 16777216,
  max_bindings~ : Int32 = 4096,
  max_value_length~ : Int32 = 1048576,
  max_items~ : Int32 = 4096,
) -> Result[LinkSession, LinkSessionError] {
  if max_each_output < 0 ||
    max_total_output < 0 ||
    max_bindings < 0 ||
    max_value_length < 0 ||
    max_items < 0 {
    return Err(InvalidBudget)
  }
  let raw = match
    prepare_bindings(bindings, max_bindings, max_value_length, max_items) {
    Ok(value) => value
    Err(error) => return Err(InvalidBindings(error))
  }
  let dependencies : Map[String, Array[Int32]] = Map([])
  for index, name in self.names {
    let template = self.templates.get(name).unwrap()
    for variable in template.variables {
      match dependencies.get(variable) {
        Some(indexes) => indexes.push(index)
        None => dependencies[variable] = [index]
      }
    }
  }
  let values : Map[String, Value] = Map([])
  for name, value in raw {
    if !dependencies.contains(name) {
      return Err(InvalidBindings(UnusedVariable(name)))
    }
    values[name] = value.deep_copy()
  }
  // Measure the entire snapshot before allocating expanded output strings.
  let mut total = 0
  for name in self.names {
    let template = self.templates.get(name).unwrap()
    let length = match
      template.measure(
        template.session_bindings(values),
        max_output=max_each_output,
        max_bindings~,
        max_value_length~,
        max_items~,
      ) {
      Ok(length) => length
      Err(error) => return Err(InvalidEndpoint(name, error))
    }
    if length > max_total_output - total {
      return Err(TotalOutputTooLong)
    }
    total += length
  }
  let outputs = []
  for name in self.names {
    let template = self.templates.get(name).unwrap()
    match
      template.expand(
        template.session_bindings(values),
        max_output=max_each_output,
        max_bindings~,
        max_value_length~,
        max_items~,
      ) {
      Ok(value) => outputs.push(value)
      Err(error) => return Err(InvalidEndpoint(name, error))
    }
  }
  Ok({
    catalog: self,
    dependencies,
    values,
    outputs,
    total,
    each_limit: max_each_output,
    total_limit: max_total_output,
    binding_limit: max_bindings,
    value_limit: max_value_length,
    item_limit: max_items,
  })
}

///|
fn Value::same_content(self : Value, other : Value) -> Bool {
  match (self, other) {
    (Scalar(a), Scalar(b)) => a == b
    (List(a), List(b)) => a == b
    (Assoc(a), Assoc(b)) => a == b
    (SparseList(a), SparseList(b)) => a == b
    (SparseAssoc(a), SparseAssoc(b)) => a == b
    _ => false
  }
}

///|
/// Transactional patch: failure leaves this snapshot intact. Each affected
/// endpoint is measured/rendered once, even if several variables change.
pub fn LinkSession::update(
  self : LinkSession,
  patch : Array[BindingChange],
) -> Result[LinkUpdate, LinkSessionError] {
  if patch.length() > 4096 {
    return Err(TooManyChanges)
  }
  let seen : Map[String, Bool] = Map([])
  for change in patch {
    let name = match change {
      SetBinding(name, _) | RemoveBinding(name) => name
    }
    if seen.contains(name) {
      return Err(DuplicateChange(name))
    }
    seen[name] = true
    if !self.dependencies.contains(name) {
      return Err(InvalidBindings(UnusedVariable(name)))
    }
    if change is SetBinding(_, value) {
      match check_value(value, name, self.value_limit, self.item_limit) {
        Ok(_) => ()
        Err(error) => return Err(InvalidBindings(error))
      }
    }
  }
  let values : Map[String, Value] = Map([])
  for name, value in self.values {
    values[name] = value
  }
  let affected : Map[Int32, Bool] = Map([])
  for change in patch {
    let (name, changed) = match change {
      SetBinding(name, value) => {
        let changed = match values.get(name) {
          Some(old) => !old.same_content(value)
          None => true
        }
        if changed {
          values[name] = value.deep_copy()
        }
        (name, changed)
      }
      RemoveBinding(name) => {
        let changed = values.contains(name)
        values.remove(name)
        (name, changed)
      }
    }
    if changed {
      for index in self.dependencies.get(name).unwrap() {
        affected[index] = true
      }
    }
  }
  if values.length() > self.binding_limit {
    return Err(InvalidBindings(TooManyBindings))
  }
  let mut total = self.total
  for index, _ in affected {
    total -= self.outputs[index].length()
  }
  for index, name in self.catalog.names {
    if !affected.contains(index) {
      continue
    }
    let template = self.catalog.templates.get(name).unwrap()
    let length = match
      template.measure(
        template.session_bindings(values),
        max_output=self.each_limit,
        max_bindings=self.binding_limit,
        max_value_length=self.value_limit,
        max_items=self.item_limit,
      ) {
      Ok(value) => value
      Err(error) => return Err(InvalidEndpoint(name, error))
    }
    if length > self.total_limit - total {
      return Err(TotalOutputTooLong)
    }
    total += length
  }
  let outputs = self.outputs.copy()
  let changes = []
  for index, name in self.catalog.names {
    if !affected.contains(index) {
      continue
    }
    let template = self.catalog.templates.get(name).unwrap()
    let output = match
      template.expand(
        template.session_bindings(values),
        max_output=self.each_limit,
        max_bindings=self.binding_limit,
        max_value_length=self.value_limit,
        max_items=self.item_limit,
      ) {
      Ok(value) => value
      Err(error) => return Err(InvalidEndpoint(name, error))
    }
    if output != outputs[index] {
      changes.push({ name, before: outputs[index], after: output, })
    }
    outputs[index] = output
  }
  let session = { ..self, values, outputs, total, }
  Ok({ session, changes, recomputed: affected.length(), })
}
