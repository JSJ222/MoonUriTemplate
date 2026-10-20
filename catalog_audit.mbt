///|
/// Static analysis of one named template in a catalog.
pub struct CatalogEntryAudit {
  name : String
  variable_count : Int32
  expression_count : Int32
  max_level : Int32
  findings : Array[PolicyFinding]
}

///|
pub fn CatalogEntryAudit::name(self : CatalogEntryAudit) -> String {
  self.name
}

///|
pub fn CatalogEntryAudit::variable_count(self : CatalogEntryAudit) -> Int32 {
  self.variable_count
}

///|
pub fn CatalogEntryAudit::expression_count(self : CatalogEntryAudit) -> Int32 {
  self.expression_count
}

///|
pub fn CatalogEntryAudit::max_level(self : CatalogEntryAudit) -> Int32 {
  self.max_level
}

///|
pub fn CatalogEntryAudit::findings(
  self : CatalogEntryAudit,
) -> Array[PolicyFinding] {
  self.findings.copy()
}

///|
/// Policy findings for every catalog entry, preserving catalog order.
pub struct CatalogAudit {
  entries : Array[CatalogEntryAudit]
  total_findings : Int32
}

///|
pub fn CatalogAudit::entries(self : CatalogAudit) -> Array[CatalogEntryAudit] {
  self.entries.copy()
}

///|
pub fn CatalogAudit::total_findings(self : CatalogAudit) -> Int32 {
  self.total_findings
}

///|
pub fn CatalogAudit::is_clean(self : CatalogAudit) -> Bool {
  self.total_findings == 0
}

///|
/// Audit every named template for SDK or server startup checks. The audit
/// never reads values or produces URI text. An invalid policy is rejected even
/// when the catalog contains no templates.
pub fn TemplateCatalog::audit(
  self : TemplateCatalog,
  policy : TemplatePolicy,
) -> Result[CatalogAudit, PolicyError] {
  match policy.validate() {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let entries : Array[CatalogEntryAudit] = []
  let mut total_findings = 0
  for name in self.names {
    match self.templates.get(name) {
      None => ()
      Some(template) => {
        let analysis = template.analyze()
        let findings = match template.check_policy(policy) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        total_findings += findings.length()
        entries.push({
          name,
          variable_count: template.variables().length(),
          expression_count: analysis.expressions().length(),
          max_level: analysis.max_level(),
          findings,
        })
      }
    }
  }
  Ok({ entries, total_findings, })
}
