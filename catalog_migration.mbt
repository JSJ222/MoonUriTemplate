///|
/// A changed endpoint retains its contract comparison, including literal-only
/// changes that a variable/operator comparison alone would not detect.
pub struct CatalogTemplateChange {
  name : String
  contract : TemplateDiff
}

///|
pub fn CatalogTemplateChange::name(self : CatalogTemplateChange) -> String {
  self.name
}

///|
pub fn CatalogTemplateChange::contract(
  self : CatalogTemplateChange,
) -> TemplateDiff {
  self.contract
}

///|
pub struct CatalogDiff {
  added : Array[String]
  removed : Array[String]
  changed : Array[CatalogTemplateChange]
}

///|
pub fn CatalogDiff::added(self : CatalogDiff) -> Array[String] {
  self.added.copy()
}

///|
pub fn CatalogDiff::removed(self : CatalogDiff) -> Array[String] {
  self.removed.copy()
}

///|
pub fn CatalogDiff::changed(self : CatalogDiff) -> Array[CatalogTemplateChange] {
  self.changed.copy()
}

///|
pub fn CatalogDiff::is_empty(self : CatalogDiff) -> Bool {
  self.added.is_empty() && self.removed.is_empty() && self.changed.is_empty()
}

///|
/// Compare two endpoint catalogs before deploying a new API/link definition.
/// Additions and changes follow the next catalog order; removals follow the old.
/// A report is structural evidence, not a proof of backward compatibility.
pub fn TemplateCatalog::diff_catalog(
  self : TemplateCatalog,
  next : TemplateCatalog,
) -> CatalogDiff {
  let added : Array[String] = []
  let removed : Array[String] = []
  let changed : Array[CatalogTemplateChange] = []
  for name in next.names {
    let after = next.templates[name]
    match self.templates.get(name) {
      None => added.push(name)
      Some(before) =>
        if before.source != after.source {
          changed.push({ name, contract: before.diff_contract(after), })
        }
    }
  }
  for name in self.names {
    if !next.templates.contains(name) {
      removed.push(name)
    }
  }
  { added, removed, changed, }
}
