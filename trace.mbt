///|
/// A source segment and the exact UTF-16 range it contributed to the output.
/// Empty expressions still have a zero-width output range.
pub(all) struct OutputSpan {
  source_start : Int
  source_end : Int
  output_start : Int
  output_end : Int
  is_expression : Bool
}

///|
/// Expanded URI text with a source-to-output map for diagnostics and tooling.
pub struct RenderedUri {
  text : String
  spans : Array[OutputSpan]
}

///|
pub fn RenderedUri::text(self : RenderedUri) -> String {
  self.text
}

///|
pub fn RenderedUri::spans(self : RenderedUri) -> Array[OutputSpan] {
  self.spans.copy()
}

///|
/// Expand while recording which source segment produced each output range.
/// This has O(number of segments) additional memory compared with `expand`.
pub fn Template::expand_detailed(
  self : Template,
  bindings : Array[(String, Value)],
  max_output? : Int = 1048576,
  max_bindings? : Int = 4096,
  max_value_length? : Int = 1048576,
  max_items? : Int = 4096,
) -> Result[RenderedUri, ExpandError] {
  self.expand_internal(
    bindings, max_output, max_bindings, max_value_length, max_items, true,
  )
}
