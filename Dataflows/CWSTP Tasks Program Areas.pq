let
  Source = #"Tasks Base",
  #"Choose columns" = Table.SelectColumns(Source, {"Program Area"}),
  #"Filtered rows" = Table.SelectRows(#"Choose columns", each ([Program Area] <> "")),
  #"Removed duplicates" = Table.Distinct(#"Filtered rows", {"Program Area"}),
  #"Sorted rows" = Table.Sort(#"Removed duplicates", {{"Program Area", Order.Ascending}})
in
  #"Sorted rows"