///|
/// Catalog compilation failure. Template syntax errors retain the entry name.
pub(all) enum CatalogError {
  TooManyTemplates
  EmptyName
  DuplicateName(String)
  InvalidTemplate(String, ParseError)
}

///|
/// Expansion failure retains the catalog entry name when one was selected.
pub(all) enum CatalogExpandError {
  UnknownTemplate(String)
  InvalidBinding(String, ExpandError)
}

///|
/// A named set of precompiled templates for API endpoints or link relations.
pub struct TemplateCatalog {
  names : Array[String]
  templates : Map[String, Template]
}

///|
/// Compile every catalog entry once. Names remain in caller order. Duplicate
/// names are rejected so a later template cannot silently replace an earlier
/// endpoint or link relation.
pub fn compile_catalog(
  entries : Array[(String, String)],
  max_templates? : Int = 1024,
  max_template_length? : Int = 65536,
) -> Result[TemplateCatalog, CatalogError] {
  if max_templates < 0 || entries.length() > max_templates {
    return Err(TooManyTemplates)
  }
  let names : Array[String] = []
  let templates : Map[String, Template] = Map([])
  for entry in entries {
    let (name, source) = entry
    if name == "" {
      return Err(EmptyName)
    }
    if templates.contains(name) {
      return Err(DuplicateName(name))
    }
    let template = match parse(source, max_length=max_template_length) {
      Ok(value) => value
      Err(error) => return Err(InvalidTemplate(name, error))
    }
    names.push(name)
    templates[name] = template
  }
  Ok({ names, templates, })
}

///|
pub fn TemplateCatalog::names(self : TemplateCatalog) -> Array[String] {
  self.names.copy()
}

///|
pub fn TemplateCatalog::contains(self : TemplateCatalog, name : String) -> Bool {
  self.templates.contains(name)
}

///|
/// Look up the original compiled template for analysis or specialized limits.
pub fn TemplateCatalog::get(self : TemplateCatalog, name : String) -> Template? {
  self.templates.get(name)
}

///|
/// Expand one named template with a supplied value set. The catalog itself is
/// immutable after compilation and can be reused across requests.
pub fn TemplateCatalog::expand(
  self : TemplateCatalog,
  name : String,
  bindings : Array[(String, Value)],
  max_output? : Int = 1048576,
) -> Result[String, CatalogExpandError] {
  let template = match self.templates.get(name) {
    Some(value) => value
    None => return Err(UnknownTemplate(name))
  }
  match template.expand(bindings, max_output~) {
    Ok(value) => Ok(value)
    Err(error) => Err(InvalidBinding(name, error))
  }
}

///|
pub fn CatalogError::code(self : CatalogError) -> String {
  match self {
    TooManyTemplates => "too_many_templates"
    EmptyName => "empty_name"
    DuplicateName(_) => "duplicate_name"
    InvalidTemplate(_, _) => "invalid_template"
  }
}

///|
pub fn CatalogExpandError::code(self : CatalogExpandError) -> String {
  match self {
    UnknownTemplate(_) => "unknown_template"
    InvalidBinding(_, _) => "invalid_binding"
  }
}
