let
  Source = #"Tasks Base",
  #"Expanded Dependent Tasks" = Table.ExpandTableColumn(Source, "Dependent Tasks", {"lookupId", "lookupValue"}, {"lookupId", "lookupValue"}),
  #"Filtered rows" = Table.SelectRows(#"Expanded Dependent Tasks", each ([lookupId] <> null)),
  #"Choose columns" = Table.SelectColumns(#"Filtered rows", {"Title", "lookupId", "lookupValue", "ID"}),
  #"Reordered columns" = Table.ReorderColumns(#"Choose columns", {"Title", "ID", "lookupId", "lookupValue"}),
  #"Renamed columns" = Table.RenameColumns(#"Reordered columns", {{"lookupId", "Dep Task SPOID"}, {"ID", "Source SPOID"}, {"lookupValue", "Dep Task Value"}}),
  #"Sorted rows" = Table.Sort(#"Renamed columns", {{"Source SPOID", Order.Ascending}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Sorted rows", {{"Dep Task SPOID", Int64.Type}})
in
  #"Changed column type"