let
    //
    // TEAMS DIMENSION
    //
    CDS = CommonDataService.Database("org6cd1f51e.crm9.dynamics.com"),
    Teams_Final =
        Table.RenameColumns(
            Table.SelectColumns(
                CDS{[Schema="dbo", Item="cr8b0_cwstp_team"]}[Data],
                {"cr8b0_cwstp_teamid", "cr8b0_name"}
            ),
            {
                {"cr8b0_cwstp_teamid", "TeamGUID"},
                {"cr8b0_name", "TeamName"}
            }
        ),

    //
    // PROJECTS → BASE COLUMNS
    //
    Base =
        Table.SelectColumns(
            Projects,
            {"Team.Value", "ID", "TeamGUID"}
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
                    // Single team → one row
                    { [ 
                        TeamGUID = row[TeamGUID],
                        TeamName = row[Team.Value] 
                    ] }
                else
                    // No match → return BOTH teams
                    List.Transform(
                        Table.ToRecords(Teams_Final),
                        each [
                            TeamGUID = [TeamGUID],
                            TeamName = [TeamName]
                        ]
                    )
        ),

    //
    // REMOVE ORIGINAL TeamGUID TO AVOID COLLISION
    //
    WithoutOriginal =
        Table.RemoveColumns(WithTeamRows, {"TeamGUID", "Team.Value"}),

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