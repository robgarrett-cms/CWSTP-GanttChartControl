let
  Source = #"Tasks Base",
  #"Choose columns" = Table.SelectColumns(Source, {"Priority", "Due Date", "Status", "Title", "Outcome / Definition of Done", "Start Date", "End Date", "File URLs", "Notes/Comments", "External Dependencies", "Risks to Project or Task", "Type of Action", "Parent Project", "Impact on Roadmap", "TeamName", "Program Area", "Modified", "Frequency", "ID", "Progress (%)", "Owner.azureactivedirectoryobjectid", "Owner.email", "Stakeholder.azureactivedirectoryobjectid", "Stakeholder.email"}),
  #"Filtered rows" = Table.SelectRows(#"Choose columns", each ([Type of Action] = "Dependent Task")),
  #"Renamed columns" = Table.RenameColumns(#"Filtered rows", {{"ID", "SourceSPOID"}})
in
  #"Renamed columns"