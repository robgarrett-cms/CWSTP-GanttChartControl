let
    CDS = CommonDataService.Database("org6cd1f51e.crm9.dynamics.com"),

    // LOWERCASE THE USER EMAILS ---
    Users_Raw = CDS{[Schema="dbo", Item="cr8b0_cwstpusers"]}[Data],
    Users_Lower = Table.TransformColumns(Users_Raw, {{"cr8b0_email", Text.Lower, type text}}),
    Users_Clean = Table.Buffer(Table.SelectColumns(Users_Lower, {"cr8b0_aadobjectid", "cr8b0_email", "cr8b0_id"})),

    Source = #"Projects Base",

    // Expand collaborators directly
    ExpandCollaborators =
        Table.ExpandTableColumn(
            Source,
            "Collaborators",
            {"email"},
            {"CollaboratorEmail"}
        ),

    // Clean email
    CleanEmail =
        Table.TransformColumns(
            ExpandCollaborators,
            {{"CollaboratorEmail", each Text.Lower(Text.From(_)), type nullable text}}
        ),

    // Join to users
    MergeUsers =
        Table.NestedJoin(
            CleanEmail,
            {"CollaboratorEmail"},
            Users_Clean,
            {"cr8b0_email"},
            "UserDV",
            JoinKind.Inner
        ),
  #"Expanded UserDV" = Table.ExpandTableColumn(MergeUsers, "UserDV", {"cr8b0_aadobjectid", "cr8b0_email", "cr8b0_id"}, {"UserDV.cr8b0_aadobjectid", "UserDV.cr8b0_email", "UserDV.cr8b0_id"}),
  #"Renamed columns" = Table.RenameColumns(#"Expanded UserDV", {{"UserDV.cr8b0_id", "Collaborator_ID"}, {"UserDV.cr8b0_email", "Collaborator_Email"}, {"UserDV.cr8b0_aadobjectid", "Collaborator_AADObjectId"}}),
  #"Choose columns" = Table.SelectColumns(#"Renamed columns", {"ID", "Collaborator_AADObjectId", "Collaborator_Email", "Collaborator_ID"}),
  #"Sorted rows" = Table.Sort(#"Choose columns", {{"ID", Order.Ascending}})
in
    #"Sorted rows"