let        
    //
    // TEAMS DIMENSION
    //
    CDS = CommonDataService.Database("org6cd1f51e.crm9.dynamics.com"),
    Final =
        Table.RenameColumns(
            Table.SelectColumns(
                CDS{[Schema="dbo", Item="cr8b0_cwstp_team"]}[Data],
                {"cr8b0_cwstp_teamid", "cr8b0_name"}
            ),
            {
                {"cr8b0_cwstp_teamid", "TeamGUID"},
                {"cr8b0_name", "TeamName"}
            }
        )
in
    Final