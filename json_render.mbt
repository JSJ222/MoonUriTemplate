///|
/// The JSON adapter distinguishes conversion failures from URI expansion
/// failures. A JSON number is never silently coerced to text.
pub(all) enum JsonRenderError {
  Conversion(JsonBridgeError)
  Expansion(ExpandError)
}

///|
pub fn JsonRenderError::code(self : JsonRenderError) -> String {
  match self {
    Conversion(error) => "json_" + error.code()
    Expansion(error) => "expand_" + error.code()
  }
}

///|
/// Convert a JSON object to ordered bindings and expand a compiled template.
/// This is suitable for clients that already have a decoded JSON tree. It
/// does not parse JSON text or validate a resulting network destination.
pub fn Template::expand_json(
  self : Template,
  values : Json,
  max_output? : Int = 1048576,
  max_bindings? : Int = 4096,
  max_value_length? : Int = 1048576,
  max_items? : Int = 4096,
) -> Result[String, JsonRenderError] {
  let bindings = match bindings_from_json(values) {
    Ok(value) => value
    Err(error) => return Err(Conversion(error))
  }
  match
    self.expand(
      bindings,
      max_output~,
      max_bindings~,
      max_value_length~,
      max_items~,
    ) {
    Ok(value) => Ok(value)
    Err(error) => Err(Expansion(error))
  }
}

///|
/// Parse a template and expand it from a JSON object in a single call.
pub fn expand_json(
  source : String,
  values : Json,
  max_output? : Int = 1048576,
) -> Result[String, JsonTemplateError] {
  let template = match parse(source) {
    Ok(value) => value
    Err(error) => return Err(TemplateParse(error))
  }
  match template.expand_json(values, max_output~) {
    Ok(value) => Ok(value)
    Err(error) => Err(TemplateRender(error))
  }
}

///|
/// A single-call JSON expansion failed during syntax compilation or render.
pub(all) enum JsonTemplateError {
  TemplateParse(ParseError)
  TemplateRender(JsonRenderError)
}

///|
pub fn JsonTemplateError::code(self : JsonTemplateError) -> String {
  match self {
    TemplateParse(error) => "parse_" + error.code()
    TemplateRender(error) => error.code()
  }
}
