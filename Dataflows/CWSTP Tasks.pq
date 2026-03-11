let
  Source = Table.Combine({#"Tasks under Project", #"Tasks Stand-Alone", #"Tasks missing Parent Project"}),
  #"Choose columns" = Table.SelectColumns(Source, {"Priority", "Due Date", "Status", "Title", "Outcome / Definition of Done", "Progress (%)", "Start Date", "End Date", "File URLs", "Notes/Comments", "External Dependencies", "Risks to Project or Task", "Roadmap_choice", "Type of Action", "ParentProjectID", "Parent Project.lookupValue", "Dependent Tasks", "Impact on Roadmap", "Team", "Program Area", "Frequency", "Contract Period", "ID", "HHS OCIO Goal", "Work Type", "Owner_AADObjectId", "Owner_Email", "Owner_ID", "Stakeholder_AADObjectId", "Stakeholder_Email", "Stakeholder_ID"}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Choose columns", "Is Stand-alone", each [Type of Action] = "Stand Alone Activity"), {{"Is Stand-alone", type logical}}),
  #"Renamed columns" = Table.RenameColumns(#"Added custom", {{"ID", "Source SPOID"}})
in
  #"Renamed columns"