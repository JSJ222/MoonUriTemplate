# Expand templates without reverse matching

MoonURITemplate implements RFC 6570 Level 4 parsing and forward expansion. It does not reverse-match a URI to variable values: the RFC notes that matching is ambiguous for general templates, and a partial matcher would mislead API and MCP users about interoperability. Applications needing route matching should use a dedicated matcher.
