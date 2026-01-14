let
    //
    // CONSTANTS
    //
    SiteUrl = "https://cmsgovonline.sharepoint.com/sites/CWSTPTeam",
    ListName = "CWSTP Project and Task Management",

    //
    // LOAD DATAVERSE ONCE
    //
    CDS = CommonDataService.Database("org6cd1f51e.crm9.dynamics.com"),

    //
    // USERS DIMENSION
    //
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

    //
    // TEAMS DIMENSION
    //
    Teams_Raw = CDS{[Schema="dbo", Item="cr8b0_cwstp_team"]}[Data],
    Teams_Clean =
        Table.Buffer(
            Table.SelectColumns(
                Teams_Raw,
                {"cr8b0_cwstp_teamid", "cr8b0_name"}
            )
        ),

    //
    // SHAREPOINT PROJECTS
    //
    SP = SharePoint.Tables(SiteUrl, [Implementation="2.0", ViewMode="All"]),
    Projects = SP{[Title=ListName]}[Items],

    //
    // NORMALIZE PARENT PROJECT
    //
    Projects_Parent =
        Table.ExpandRecordColumn(
            Table.ExpandListColumn(Projects, "Parent Project"),
            "Parent Project",
            {"lookupId","lookupValue"},
            {"lookupId","lookupValue"}
        ),

    Projects_TopOnly = Table.SelectRows(Projects_Parent, each [lookupId] = null),

    //
    // FIX PROGRESS, ROADMAP, ARCHIVED, STATUS
    //
    Projects_Normalized =
        Table.TransformColumns(
            Projects_TopOnly,
            {
                {"Progress (%)", each if _ = null then 0 else _, Int64.Type},
                {"Roadmap_choice", each if _ = "Roadmap" then "True" else if _ = "n/a" or _ = "" then "False" else _, type text},
                {"Archived", each if _ = null then false else _, type logical},
                {"Status", each if _ = "" then "Not Started" else _, type text}
            }
        ),

    Projects_RoadmapBool =
        Table.TransformColumnTypes(Projects_Normalized, {{"Roadmap_choice", type logical}}),

    //
    // FORCE PROGRESS TO 100 IF STATUS = COMPLETE
    //
    Projects_Progress =
        Table.TransformColumns(
            Table.AddColumn(
                Projects_RoadmapBool,
                "ProgressTemp",
                each if Text.Lower([Status]) = "complete" then 100 else [#"Progress (%)"],
                Int64.Type
            ),
            {{"ProgressTemp", each _, Int64.Type}}
        ),

    Projects_FinalProgress =
        Table.RenameColumns(
            Table.RemoveColumns(Projects_Progress, {"Progress (%)"}),
            {{"ProgressTemp", "Progress (%)"}}
        ),

    //
    // OWNER + STAKEHOLDER EMAILS
    //
    ExpandOwner =
        Table.ExpandRecordColumn(
            Table.ExpandListColumn(Projects_FinalProgress, "Owner"),
            "Owner",
            {"email"},
            {"OwnerEmail"}
        ),

    ExpandStakeholder =
        Table.ExpandRecordColumn(
            Table.ExpandListColumn(ExpandOwner, "CMS Stakeholder"),
            "CMS Stakeholder",
            {"email"},
            {"StakeholderEmail"}
        ),

    LowerEmails =
        Table.TransformColumns(
            ExpandStakeholder,
            {
                {"OwnerEmail", each Text.Lower(Text.From(_)), type nullable text},
                {"StakeholderEmail", each Text.Lower(Text.From(_)), type nullable text}
            }
        ),

    Projects_NoParentCols = Table.RemoveColumns(LowerEmails, {"lookupId","lookupValue"}),

    //
    // NORMALIZE TEAM LOOKUP
    //
    NormalizeTeam =
        Table.TransformColumns(
            Projects_NoParentCols,
            {
                {
                    "Team",
                    each
                        if _ is null then {}
                        else if _ is list then _
                        else if _ is record then {_}
                        else if _ is text then { [Value = _, Id = null] }
                        else {},
                    type list
                }
            }
        ),

    ExpandTeam =
        Table.ExpandRecordColumn(
            Table.ExpandListColumn(NormalizeTeam, "Team"),
            "Team",
            {"Value","Id"},
            {"Team.Value","Team.Id"}
        ),

    CleanTeamValue =
        Table.TransformColumns(
            ExpandTeam,
            {{"Team.Value", each Text.Trim(Text.Clean(_)), type text}}
        ),

    //
    // MERGE TEAMS
    //
    MergeTeams =
        Table.NestedJoin(
            CleanTeamValue,
            {"Team.Value"},
            Teams_Clean,
            {"cr8b0_name"},
            "TeamDV",
            JoinKind.LeftOuter
        ),

    ExpandTeams =
        Table.ExpandTableColumn(
            MergeTeams,
            "TeamDV",
            {"cr8b0_cwstp_teamid"},
            {"TeamGUID"}
        ),

    //
    // MERGE OWNER + STAKEHOLDER
    //
    MergeOwner =
        Table.NestedJoin(
            ExpandTeams,
            {"OwnerEmail"},
            Users_Clean,
            {"internalemailaddress"},
            "OwnerUser",
            JoinKind.LeftOuter
        ),

    MergeStakeholder =
        Table.NestedJoin(
            MergeOwner,
            {"StakeholderEmail"},
            Users_Clean,
            {"internalemailaddress"},
            "StakeholderUser",
            JoinKind.LeftOuter
        ),

    ExpandOwnerUser =
        Table.ExpandTableColumn(
            MergeStakeholder,
            "OwnerUser",
            {"systemuserid","azureactivedirectoryobjectid","internalemailaddress"},
            {"Owner.systemuserid","Owner.azureactivedirectoryobjectid","Owner.email"}
        ),

    ExpandStakeholderUser =
        Table.ExpandTableColumn(
            ExpandOwnerUser,
            "StakeholderUser",
            {"systemuserid","azureactivedirectoryobjectid","internalemailaddress"},
            {"Stakeholder.systemuserid","Stakeholder.azureactivedirectoryobjectid","Stakeholder.email"}
        ),

    //
    // REMOVE NOISE COLUMNS
    //
    Final =
        Table.RemoveColumns(
            ExpandStakeholderUser,
            {
                "Team.Id","Dependent Tasks","Color Tag","Compliance Asset Id","Approval Creator",
                "Approval status","Approvers","Responses","Version","Schedule Variance","Content Type",
                "Created","Created By","Modified By","Attachments","Edit","Type","Item Child Count",
                "Folder Child Count","Label setting","Retention label","Retention label Applied",
                "Label applied by","Item is a Record","App Created By","App Modified By","Modified"
            }
        )
in
    Final