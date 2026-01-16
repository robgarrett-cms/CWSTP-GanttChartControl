let
    //
    // TEAMS DIMENSION
    //
    CDS = CommonDataService.Database("org6cd1f51e.crm9.dynamics.com"),
    Teams_Raw = CDS{[Schema="dbo", Item="cr8b0_cwstp_team"]}[Data],
    Teams_Clean =
        Table.Buffer(
            Table.SelectColumns(
                Teams_Raw,
                {"cr8b0_name"}
            )
        ),

    //
    // PROJECTS → BASE COLUMNS
    //
    ProjectsBase =
        Table.SelectColumns(
            Projects,
            {"TeamName", "ID"}
        ),

    //
    // SINGLE‑TEAM PROJECTS
    //
    SingleTeam =
        Table.RenameColumns(
            Table.SelectRows(ProjectsBase, each [TeamName] <> "Both"),
            {{"ID", "SPOID"}}
        ),

    //
    // MULTI‑TEAM PROJECTS (TeamName = "Both")
    //
    Multi_Filtered =
        Table.SelectRows(ProjectsBase, each [TeamName] = "Both"),

    Multi_Renamed =
        Table.RenameColumns(Multi_Filtered, {{"ID", "SPOID"}}),

    // CROSS JOIN: attach all teams
    Multi_AddTeams =
        Table.AddColumn(
            Multi_Renamed,
            "TeamRows",
            (row) => Table.ToRecords(Teams_Clean)
        ),

    Multi_ExpandedList =
        Table.ExpandListColumn(Multi_AddTeams, "TeamRows"),

    Multi_Final =
        Table.ExpandRecordColumn(
            Table.RemoveColumns(Multi_ExpandedList, {"TeamName"}),
            "TeamRows",
            {"cr8b0_name"},
            {"TeamName"}
        ),

    //
    // APPEND SINGLE + MULTI
    //
    Combined =
        Table.Combine({SingleTeam, Multi_Final}),

    //
    // SORT + DEDUPE
    //
    Sorted =
        Table.Sort(Combined, {{"SPOID", Order.Ascending}}),

    Deduped =
        Table.Distinct(Sorted, {"SPOID", "TeamName"}),

    //
    // TYPE FIX FOR DATAVERSE LOOKUP
    //
    Typed =
        Table.TransformColumnTypes(
            Deduped,
            {{"TeamName", type text}}
        )
in
    Typed