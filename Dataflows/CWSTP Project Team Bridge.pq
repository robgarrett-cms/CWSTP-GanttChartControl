let
    //
    // PROJECTS → BASE COLUMNS
    //
    Base =
        Table.SelectColumns(
            Projects,
            {"TeamName", "ID"}
        ),
  #"Filtered rows" = Table.SelectRows(Base, each ([TeamName] <> "Both")),
  RenamedColumns = Table.RenameColumns(#"Filtered rows", {{"ID", "SPOID"}})
in
  RenamedColumns