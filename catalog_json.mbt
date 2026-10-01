///|
/// A JSON catalog manifest must map each endpoint name to one URI Template
/// string. Key order is sorted for reproducible `TemplateCatalog::names`.
pub(all) enum CatalogJsonError {
  RootMustBeObject
  TemplateMustBeString(String)
  Compilation(CatalogError)
}

///|
pub fn CatalogJsonError::code(self : CatalogJsonError) -> String {
  match self {
    RootMustBeObject => "root_must_be_object"
    TemplateMustBeString(_) => "template_must_be_string"
    Compilation(error) => "compile_" + error.code()
  }
}

///|
pub fn CatalogJsonError::path(self : CatalogJsonError) -> String {
  match self {
    RootMustBeObject => ""
    TemplateMustBeString(path) => path
    Compilation(_) => ""
  }
}

///|
/// Build a named catalog from an already-decoded JSON object. JSON parsers
/// may have discarded duplicate object keys before this method is called;
/// callers that reject duplicates must enforce that while reading JSON text.
pub fn compile_catalog_json(
  input : Json,
  max_templates? : Int = 1024,
  max_template_length? : Int = 65536,
) -> Result[TemplateCatalog, CatalogJsonError] {
  let fields = match input {
    Object(fields) => fields
    _ => return Err(RootMustBeObject)
  }
  let names : Array[String] = []
  for name, _ in fields {
    names.push(name)
  }
  names.sort_by(fn(a, b) { a.lexical_compare(b) })
  let entries : Array[(String, String)] = []
  for name in names {
    match fields.get(name) {
      Some(String(source)) => entries.push((name, source))
      Some(_) => return Err(TemplateMustBeString(pointer_child("", name)))
      None => ()
    }
  }
  match compile_catalog(entries, max_templates~, max_template_length~) {
    Ok(value) => Ok(value)
    Err(error) => Err(Compilation(error))
  }
}

///|
pub(all) enum CatalogJsonRenderError {
  BindingConversion(JsonBridgeError)
  CatalogExpansion(CatalogExpandError)
}

///|
pub fn CatalogJsonRenderError::code(self : CatalogJsonRenderError) -> String {
  match self {
    BindingConversion(error) => "json_" + error.code()
    CatalogExpansion(error) => "catalog_" + error.code()
  }
}

///|
/// Render a named URI using a conservative JSON binding object. This method
/// shares the same string/null/array/object conversion as `expand_json`.
pub fn TemplateCatalog::expand_json(
  self : TemplateCatalog,
  name : String,
  values : Json,
  max_output? : Int = 1048576,
) -> Result[String, CatalogJsonRenderError] {
  if !self.contains(name) {
    return Err(CatalogExpansion(UnknownTemplate(name)))
  }
  let bindings = match bindings_from_json(values) {
    Ok(value) => value
    Err(error) => return Err(BindingConversion(error))
  }
  match self.expand(name, bindings, max_output~) {
    Ok(value) => Ok(value)
    Err(error) => Err(CatalogExpansion(error))
  }
}
