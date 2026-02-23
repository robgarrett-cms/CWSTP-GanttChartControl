let
    Source = #"Projects Base",
  #"Replaced value" = Table.ReplaceValue(Source, null, #datetime(2026, 1, 1, 0, 0, 0), Replacer.ReplaceValue, {"Start Date"}),
  #"Sorted rows" = Table.Sort(#"Replaced value", {{"ID", Order.Ascending}}),
  #"Reordered columns" = Table.ReorderColumns(#"Sorted rows", {"Priority", "ID", "Title", "Due Date", "Status", "Outcome / Definition of Done", "Start Date", "End Date", "File URLs", "Notes/Comments", "External Dependencies", "Risks to Project or Task", "Collaborators", "StakeholderEmail", "OwnerEmail", "Roadmap_choice", "Type of Action", "Parent Project", "Color Tag", "Compliance Asset Id", "Archived", "Dependent Tasks", "Impact on Roadmap", "Approvers", "Responses", "Approval Creator", "Approval status", "TeamName", "Program Area", "Modified", "Frequency", "Contract Period", "Version", "Schedule Variance", "HHS OCIO Goal", "Content Type", "Created", "Created By", "Modified By", "Attachments", "Edit", "Type", "Item Child Count", "Folder Child Count", "Label setting", "Retention label", "Retention label Applied", "Label applied by", "Item is a Record", "App Created By", "App Modified By", "Progress (%)", "TeamDV", "Owner.systemuserid", "Owner.azureactivedirectoryobjectid", "Owner.email", "Stakeholder.systemuserid", "Stakeholder.azureactivedirectoryobjectid", "Stakeholder.email"}),

    //
    // REMOVE NOISE COLUMNS
    //
    Final =
        Table.RemoveColumns(
            #"Reordered columns",
            {
                "Dependent Tasks","Color Tag","Compliance Asset Id","Approval Creator",
                "Approval status","Approvers","Responses","Version","Schedule Variance","Content Type",
                "Created","Created By","Modified By","Attachments","Edit","Type","Item Child Count",
                "Folder Child Count","Label setting","Retention label","Retention label Applied",
                "Label applied by","Item is a Record","App Created By","App Modified By","Modified", "Collaborators", "TeamDV"
            }
        )
in
    Final