///|
/// Parse and expand a template once. Use `parse` and `Template::expand` when
/// the same template is expanded repeatedly.
pub fn expand(
  source : String,
  bindings : Array[(String, Value)],
  max_output? : Int = 1048576,
) -> Result[String, TemplateError] {
  let template = match parse(source) {
    Ok(template) => template
    Err(error) => return Err(Parse(error))
  }
  match template.expand(bindings, max_output~) {
    Ok(text) => Ok(text)
    Err(error) => Err(Expand(error))
  }
}

///|
/// Semantic version of this source checkout.
pub fn version() -> String {
  "0.1.0-dev"
}
