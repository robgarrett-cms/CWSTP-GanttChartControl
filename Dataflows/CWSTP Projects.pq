let
    Source = #"Projects Base",

    //
    // REMOVE NOISE COLUMNS
    //
    Final =
        Table.RemoveColumns(
            Source,
            {
                "Dependent Tasks","Color Tag","Compliance Asset Id","Approval Creator",
                "Approval status","Approvers","Responses","Version","Schedule Variance","Content Type",
                "Created","Created By","Modified By","Attachments","Edit","Type","Item Child Count",
                "Folder Child Count","Label setting","Retention label","Retention label Applied",
                "Label applied by","Item is a Record","App Created By","App Modified By","Modified", "Collaborators"
            }
        )
in
    Final