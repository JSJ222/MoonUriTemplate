///|
pub(all) enum RequestAuditError {
  RequestLimit
  BindingLimit
  FindingLimit
}

///|
/// No values or expanded URIs are included in a request audit.
pub struct RequestAudit {
  index : Int
  name : String
  unknown_template : Bool
  issues : Array[BindingIssue]
}

///|
pub fn RequestAudit::index(self : RequestAudit) -> Int {
  self.index
}

///|
pub fn RequestAudit::name(self : RequestAudit) -> String {
  self.name
}

///|
pub fn RequestAudit::unknown_template(self : RequestAudit) -> Bool {
  self.unknown_template
}

///|
pub fn RequestAudit::issues(self : RequestAudit) -> Array[BindingIssue] {
  self.issues.copy()
}

///|
/// Inspect every mixed request without stopping at the first unknown endpoint
/// or binding issue. Missing variables are informational under RFC 6570.
/// Limits apply to the complete input and result; failures return no partial audit.
pub fn TemplateCatalog::inspect_requests(
  self : TemplateCatalog,
  requests : Array[CatalogRequest],
  max_requests? : Int = 4096,
  max_bindings? : Int = 16384,
  max_findings? : Int = 16384,
) -> Result[Array[RequestAudit], RequestAuditError] {
  if max_requests < 0 || requests.length() > max_requests {
    return Err(RequestLimit)
  }
  if max_bindings < 0 {
    return Err(BindingLimit)
  }
  if max_findings < 0 {
    return Err(FindingLimit)
  }
  let mut bindings_count = 0
  for request in requests {
    if request.bindings.length() > max_bindings - bindings_count {
      return Err(BindingLimit)
    }
    bindings_count += request.bindings.length()
  }
  let rows : Array[RequestAudit] = []
  let mut findings = 0
  for index, request in requests {
    let (unknown_template, issues) = match self.templates.get(request.name) {
      None => (true, [])
      Some(template) =>
        (false, template.inspect_bindings(request.bindings).issues())
    }
    let count = issues.length() + (if unknown_template { 1 } else { 0 })
    if count > max_findings - findings {
      return Err(FindingLimit)
    }
    findings += count
    rows.push({ index, name: request.name, unknown_template, issues, })
  }
  Ok(rows)
}
