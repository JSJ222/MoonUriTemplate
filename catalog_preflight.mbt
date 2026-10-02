///|
/// Measure a mixed catalog batch without constructing the URI outputs.
/// The result is the exact total output length under the same per-request and
/// aggregate limits used by `expand_requests`.
pub fn TemplateCatalog::measure_requests(
  self : TemplateCatalog,
  requests : Array[CatalogRequest],
  max_requests? : Int = 4096,
  max_total_output? : Int = 16777216,
  max_each_output? : Int = 1048576,
) -> Result[Int, CatalogBatchError] {
  if max_requests < 0 || requests.length() > max_requests {
    return Err(TooManyRequests)
  }
  if max_total_output < 0 {
    return Err(TotalOutputTooLong)
  }
  let mut total = 0
  for index, request in requests {
    let size = match
      self.measure(request.name, request.bindings, max_output=max_each_output) {
      Ok(value) => value
      Err(error) => return Err(InvalidRequest(index, error))
    }
    if size > max_total_output - total {
      return Err(TotalOutputTooLong)
    }
    total = total + size
  }
  Ok(total)
}

///|
/// List templates that reference one variable, in catalog order. API schema
/// tooling can use this reverse lookup to identify which links may need new
/// bindings when a field is renamed or removed.
pub fn TemplateCatalog::templates_using(
  self : TemplateCatalog,
  variable : String,
) -> Array[String] {
  let names : Array[String] = []
  for name in self.names {
    match self.templates.get(name) {
      Some(template) =>
        for used in template.variables() {
          if used == variable {
            names.push(name)
            break
          }
        }
      None => ()
    }
  }
  names
}
