let
  Source = Table.Combine({#"Tasks under Project", #"Tasks Stand-Alone", #"Tasks missing Parent Project"}),
  #"Choose columns" = Table.SelectColumns(Source, {"Priority", "Due Date", "Status", "Title", "Outcome / Definition of Done", "Start Date", "End Date", "File URLs", "Notes/Comments", "External Dependencies", "Risks to Project or Task", "Roadmap_choice", "Type of Action", "ParentProjectID", "Impact on Roadmap", "TeamName", "Program Area", "Frequency", "Contract Period", "ID", "HHS OCIO Goal", "Progress (%)", "Owner.azureactivedirectoryobjectid", "Owner.email", "Stakeholder.azureactivedirectoryobjectid", "Stakeholder.email"}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Choose columns", "Is Stand-alone", each [Type of Action] = "Stand Alone Activity"), {{"Is Stand-alone", type logical}})
in
  #"Added custom"