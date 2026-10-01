///|
/// One named link request in a mixed catalog batch.
pub(all) struct CatalogRequest {
  name : String
  bindings : Array[(String, Value)]
}

///|
pub(all) enum CatalogBatchError {
  TooManyRequests
  TotalOutputTooLong
  InvalidRequest(Int, CatalogExpandError)
}

///|
pub fn CatalogBatchError::code(self : CatalogBatchError) -> String {
  match self {
    TooManyRequests => "too_many_requests"
    TotalOutputTooLong => "total_output_too_long"
    InvalidRequest(_, _) => "invalid_request"
  }
}

///|
/// Zero-based request index when a catalog batch failed on one row.
pub fn CatalogBatchError::index(self : CatalogBatchError) -> Int? {
  match self {
    InvalidRequest(index, _) => Some(index)
    _ => None
  }
}

///|
/// Expand a mixed set of catalog entries in request order. A failure returns
/// the failing request index; no partial collection is returned to the caller.
pub fn TemplateCatalog::expand_requests(
  self : TemplateCatalog,
  requests : Array[CatalogRequest],
  max_requests? : Int = 4096,
  max_total_output? : Int = 16777216,
  max_each_output? : Int = 1048576,
) -> Result[Array[String], CatalogBatchError] {
  if max_requests < 0 || requests.length() > max_requests {
    return Err(TooManyRequests)
  }
  if max_total_output < 0 {
    return Err(TotalOutputTooLong)
  }
  let outputs : Array[String] = []
  let mut used = 0
  for index, request in requests {
    let output = match
      self.expand(request.name, request.bindings, max_output=max_each_output) {
      Ok(value) => value
      Err(error) => return Err(InvalidRequest(index, error))
    }
    if output.length() > max_total_output - used {
      return Err(TotalOutputTooLong)
    }
    used += output.length()
    outputs.push(output)
  }
  Ok(outputs)
}
