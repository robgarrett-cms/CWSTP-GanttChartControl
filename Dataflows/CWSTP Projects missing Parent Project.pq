let
    //
    // CONSTANTS
    //
    SiteUrl = "https://cmsgovonline.sharepoint.com/sites/CWSTPTeam",
    ListName = "CWSTP Project and Task Management",
    //
    // SHAREPOINT PARENT PROJECTS
    //
    SP = SharePoint.Tables(SiteUrl, [Implementation = "2.0", ViewMode = "All"]),
    Projects = SP{[Title = ListName]}[Items],
    #"PP Filtered rows" = Table.SelectRows(Projects, each ([Type of Action] = "Parent Project")),
    #"PP Choose columns" = Table.SelectColumns(#"PP Filtered rows", {"ID"}),
    ParentProjects = Table.RenameColumns(#"PP Choose columns", {{"ID", "Source SPOID"}}),
    Source = #"Tasks Base",
    #"Filtered rows" = Table.SelectRows(
        Source, each [Type of Action] = "Dependent Task" and [Parent Project] <> null
    ),
    #"Expanded Parent Project" = Table.ExpandListColumn(#"Filtered rows", "Parent Project"),
    #"Expanded Parent Project 1" = Table.ExpandRecordColumn(
        #"Expanded Parent Project",
        "Parent Project",
        {"lookupId", "lookupValue"},
        {"Parent Project.lookupId", "Parent Project.lookupValue"}
    ),
    #"Merged queries" = Table.NestedJoin(
        #"Expanded Parent Project 1",
        {"Parent Project.lookupId"},
        #"ParentProjects",
        {"Source SPOID"},
        "Parent Projects",
        JoinKind.LeftAnti
    ),
  #"Expanded Parent Projects" = Table.ExpandTableColumn(#"Merged queries", "Parent Projects", {"Source SPOID"}, {"Parent Projects.Source SPOID"}),
  #"Removed columns" = Table.RemoveColumns(#"Expanded Parent Projects", {"Parent Project.lookupId"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed columns", {{"Parent Projects.Source SPOID", "ParentProjectID"}})
in
    #"Renamed columns"