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
    #"Choose columns" = Table.SelectColumns(
        Source,
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
    ),
    #"Filtered rows" = Table.SelectRows(
        #"Choose columns", each [Type of Action] = "Dependent Task" and [Parent Project] <> null
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
        JoinKind.Inner
    ),
    #"Removed columns" = Table.RemoveColumns(#"Merged queries", {"Parent Projects"}),
    #"Renamed columns" = Table.RenameColumns(#"Removed columns", {{"ID", "SourceSPOID"}})
in
    #"Renamed columns"