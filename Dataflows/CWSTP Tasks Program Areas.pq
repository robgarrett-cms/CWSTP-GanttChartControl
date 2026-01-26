let
  Source = #"Tasks Base",
  #"Choose columns" = Table.SelectColumns(Source, {"Program Area"}),
  #"Removed duplicates" = Table.Distinct(#"Choose columns", {"Program Area"}),
  #"Sorted rows" = Table.Sort(#"Removed duplicates", {{"Program Area", Order.Ascending}})
in
  #"Sorted rows"