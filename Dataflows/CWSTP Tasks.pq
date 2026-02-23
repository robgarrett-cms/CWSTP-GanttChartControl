let
  Source = Table.Combine({#"Tasks under Project", #"Tasks Stand-Alone", #"Tasks missing Parent Project"}),
  #"Replaced value" = Table.ReplaceValue(Source, null, #datetime(2026, 1, 1, 0, 0, 0), Replacer.ReplaceValue, {"Start Date"}),
  #"Choose columns" = Table.SelectColumns(#"Replaced value", {"Priority", "Due Date", "Status", "Title", "Outcome / Definition of Done", "Start Date", "End Date", "File URLs", "Notes/Comments", "External Dependencies", "Risks to Project or Task", "Roadmap_choice", "Type of Action", "ParentProjectID", "Impact on Roadmap", "TeamName", "Program Area", "Frequency", "Contract Period", "ID", "HHS OCIO Goal", "Progress (%)", "Owner.azureactivedirectoryobjectid", "Owner.email", "Stakeholder.azureactivedirectoryobjectid", "Stakeholder.email"}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Choose columns", "Is Stand-alone", each [Type of Action] = "Stand Alone Activity"), {{"Is Stand-alone", type logical}}),
  #"Renamed columns" = Table.RenameColumns(#"Added custom", {{"ID", "Source SPOID"}})
in
  #"Renamed columns"