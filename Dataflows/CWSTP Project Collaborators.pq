let
    CDS = CommonDataService.Database("org6cd1f51e.crm9.dynamics.com"),

    Users_Raw = CDS{[Schema="dbo", Item="cr8b0_cwstp_users_dim"]}[Data],
    Users_Clean =
        Table.Buffer(
            Table.TransformColumnNames(
                Table.SelectColumns(
                    Users_Raw,
                    {
                        "cr8b0_azureactivedirectoryobjectid",
                        "cr8b0_internalemailaddress",
                        "cr8b0_isdisabled",
                        "cr8b0_systemuserid"
                    }
                ),
                each Text.AfterDelimiter(_, "_")
            )
        ),

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
            {"internalemailaddress"},
            "UserDV",
            JoinKind.Inner
        ),

    ExpandUser =
    Table.ExpandTableColumn(
        MergeUsers,
        "UserDV",
        {"systemuserid", "azureactivedirectoryobjectid"},
        {"Collaborator.systemuserid", "Collaborator.azureactivedirectoryobjectid"}
    ),

    Final = ExpandUser,
  #"Choose columns" = Table.SelectColumns(Final, {"CollaboratorEmail", "ID", "Collaborator.azureactivedirectoryobjectid"}),
  #"Sorted rows" = Table.Sort(#"Choose columns", {{"ID", Order.Ascending}}),
  #"Renamed columns" = Table.RenameColumns(#"Sorted rows", {{"ID", "SPOID"}})
in
    #"Renamed columns"