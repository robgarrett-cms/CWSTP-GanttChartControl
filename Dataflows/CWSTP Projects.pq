let
    Source = #"Projects Base",
  #"Sorted rows" = Table.Sort(Source, {{"ID", Order.Ascending}}),
  #"Choose columns" = Table.SelectColumns(#"Sorted rows", {"Priority", "Due Date", "Status", "Title", "Outcome / Definition of Done", "Start Date", "End Date", "File URLs", "Notes/Comments", "External Dependencies", "Risks to Project or Task", "Roadmap_choice", "Type of Action", "Parent Project", "Archived", "Impact on Roadmap", "TeamName", "Program Area", "Frequency", "Contract Period", "ID", "HHS OCIO Goal", "Work Type", "Type", "Progress (%)", "TeamDV.cr8b0_name", "Owner_AADObjectId", "Owner_Email", "Owner_ID", "Stakeholder_AADObjectId", "Stackeholder_Email", "Stakeholder_ID"}),
  #"Removed columns" = Table.RemoveColumns(#"Choose columns", {"Type of Action", "Parent Project"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed columns", {{"TeamDV.cr8b0_name", "Team"}})
in
    #"Renamed columns"