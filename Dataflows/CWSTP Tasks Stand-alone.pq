let
  Source = #"Tasks Base",
  #"Filtered rows" = Table.SelectRows(
    Source,
    each [Type of Action] = "Stand Alone Activity"
        and ( [Parent Project] = null or [Parent Project] = "" )
),
  #"Choose columns" = Table.SelectColumns(
        #"Filtered rows",
        {
            "Priority",
            "Due Date",
            "Status",
            "Title",
            "Outcome / Definition of Done",
            "Start Date",
            "End Date",
            "File URLs",
            "Notes/Comments",
            "External Dependencies",
            "Risks to Project or Task",
            "Type of Action",
            "Parent Project",
            "Impact on Roadmap",
            "TeamName",
            "Program Area",
            "Modified",
            "Frequency",
            "ID",
            "Progress (%)",
            "Owner.azureactivedirectoryobjectid",
            "Owner.email",
            "Stakeholder.azureactivedirectoryobjectid",
            "Stakeholder.email"
        }
    )
in
  #"Choose columns"