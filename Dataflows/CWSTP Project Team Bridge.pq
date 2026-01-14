let
    //
    // PROJECTS → BASE COLUMNS
    //
    Base =
        Table.SelectColumns(
            Projects,
            {"Team.Value", "ID", "TeamGUID"},
            MissingField.Ignore
        ),

    //
    // TEAMS DIMENSION (clean, typed, renamed)
    //
    CDS = CommonDataService.Database("org6cd1f51e.crm9.dynamics.com"),

    TeamDim =
        Table.TransformColumnTypes(
            Table.RenameColumns(
                Table.SelectColumns(
                    CDS{[Schema="dbo", Item="cr8b0_cwstp_team_dim"]}[Data],
                    {"cr8b0_teamname", "cr8b0_teamguid"},
                    MissingField.Ignore
                ),
                {
                    {"cr8b0_teamname", "TeamName"},
                    {"cr8b0_teamguid", "TeamGUID"}
                }
            ),
            {
                {"TeamName", type text},
                {"TeamGUID", type text}
            }
        ),

    //
    // EXPAND SINGLE OR MULTIPLE TEAMS
    //
    WithTeamRows =
        Table.AddColumn(
            Base,
            "TeamRows",
            (row) =>
                if row[TeamGUID] <> null then
                    {
                        [
                            TeamGUID = row[TeamGUID],
                            TeamName = row[Team.Value]
                        ]
                    }
                else
                    List.Transform(
                        Table.ToRecords(TeamDim),
                        each [
                            TeamGUID = [TeamGUID],
                            TeamName = [TeamName]
                        ]
                    )
        ),

    //
    // REMOVE ORIGINAL COLUMNS TO AVOID COLLISIONS
    //
    WithoutOriginal =
        Table.RemoveColumns(
            WithTeamRows,
            {"TeamGUID", "Team.Value"}
        ),

    //
    // EXPAND LIST → RECORDS → COLUMNS
    //
    Expanded =
        Table.ExpandListColumn(WithoutOriginal, "TeamRows"),

    Final =
        Table.TransformColumnTypes(
            Table.ExpandRecordColumn(
                Expanded,
                "TeamRows",
                {"TeamGUID", "TeamName"},
                {"TeamGUID", "TeamName"}
            ),
            {{"TeamName", type text}}
        )
in
    Final