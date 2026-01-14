let

    //
    // TEAMS DIMENSION (Dataverse)
    //
    SourceTeams = CommonDataService.Database("org6cd1f51e.crm9.dynamics.com"),
    Teams_DV = SourceTeams{[Schema="dbo", Item="cr8b0_cwstp_team"]}[Data],

    Teams_Selected =
    Table.SelectColumns(
        Teams_DV,
        {
            "cr8b0_cwstp_teamid",   // GUID
            "cr8b0_name"            // Team name
        }
    ),

    //
    // USERS DIMENSION (Dataverse)
    //
    SourceUsers = CommonDataService.Database("org6cd1f51e.crm9.dynamics.com"),
    SystemUsers = SourceUsers{[Schema="dbo", Item="systemuser"]}[Data],

    Users_Selected = Table.SelectColumns(
        SystemUsers,
        {
            "systemuserid",
            "azureactivedirectoryobjectid",
            "internalemailaddress",
            "isdisabled",
            "createdon"
        }
    ),

    Users_NoNulls = Table.SelectRows(
        Users_Selected,
        each ([azureactivedirectoryobjectid] <> null and [internalemailaddress] <> null)
    ),

    Users_NoBadEmails = Table.SelectRows(
        Users_NoNulls,
        each 
            let
                cleanAad = Text.Lower(Text.Remove([azureactivedirectoryobjectid], "-")),
                emailLower = Text.Lower([internalemailaddress])
            in
                not Text.StartsWith(emailLower, cleanAad)
    ),

    Users_WithLower = Table.AddColumn(
        Users_NoBadEmails,
        "email_lower",
        each Text.Lower([internalemailaddress]),
        type text
    ),

    Users_Sorted = Table.Sort(
        Users_WithLower,
        {
            {"email_lower", Order.Ascending},
            {"isdisabled", Order.Ascending},
            {"createdon", Order.Descending}
        }
    ),

    Users_Deduped = Table.Distinct(Users_Sorted, {"email_lower"}),


    //
    // PROJECTS (SharePoint)
    //
    SourceProjects = SharePoint.Tables(
        "https://cmsgovonline.sharepoint.com/sites/CWSTPTeam",
        [Implementation="2.0", ViewMode="All"]
    ),

    Projects_Items = SourceProjects{[Id="a21845db-bb29-4aaa-ae9a-fb1f810a0e44"]}[Items],

    Projects_Reordered = Table.ReorderColumns(
        Projects_Items,
        {
            "Team","Program Area","Title","Priority","Owner","Due Date","Start Date",
            "End Date","Progress (%)","Status","Outcome / Definition of Done",
            "Notes/Comments","External Dependencies","Risks to Project or Task",
            "Roadmap_choice","Impact on Roadmap","Collaborators","CMS Stakeholder",
            "Parent Project","Type of Action","File URLs","Archived","Dependent Tasks",
            "Frequency","Contract Period"
        },
        MissingField.Ignore
    ),

    Projects_ExpandParent = Table.ExpandListColumn(Projects_Reordered, "Parent Project"),
    Projects_ExpandParent2 = Table.ExpandRecordColumn(
        Projects_ExpandParent,
        "Parent Project",
        {"lookupId","lookupValue"},
        {"lookupId","lookupValue"}
    ),

    Projects_FilterTop = Table.SelectRows(Projects_ExpandParent2, each ([lookupId] = null)),

    Projects_FixProgress = Table.ReplaceValue(Projects_FilterTop, null, 0, Replacer.ReplaceValue, {"Progress (%)"}),
    Projects_FixRoadmap1 = Table.ReplaceValue(Projects_FixProgress, "Roadmap", "True", Replacer.ReplaceText, {"Roadmap_choice"}),
    Projects_FixRoadmap2 = Table.ReplaceValue(Projects_FixRoadmap1, "n/a", "False", Replacer.ReplaceText, {"Roadmap_choice"}),
    Projects_FixRoadmap3 = Table.ReplaceValue(Projects_FixRoadmap2, "", "False", Replacer.ReplaceValue, {"Roadmap_choice"}),

    Projects_RoadmapBool = Table.TransformColumnTypes(Projects_FixRoadmap3, {{"Roadmap_choice", type logical}}),
    Projects_FixArchived = Table.ReplaceValue(Projects_RoadmapBool, null, false, Replacer.ReplaceValue, {"Archived"}),
    Projects_FixStatus = Table.ReplaceValue(Projects_FixArchived, "", "Not Started", Replacer.ReplaceValue, {"Status"}),

    Projects_Progress100 =
    Table.TransformColumns(
        Table.AddColumn(
            Projects_FixStatus,
            "ProgressTemp",
            each if Text.Lower([Status]) = "complete" then 100 else [#"Progress (%)"],
            Int64.Type
        ),
        {{"ProgressTemp", each _, Int64.Type}}
    ),

    Projects_ProgressFinal =
    Table.RenameColumns(
        Table.RemoveColumns(Projects_Progress100, {"Progress (%)"}),
        {{"ProgressTemp", "Progress (%)"}}
    ),

    Projects_ExpandOwner = Table.ExpandListColumn(Projects_ProgressFinal, "Owner"),
    Projects_ExpandOwner2 = Table.ExpandRecordColumn(Projects_ExpandOwner, "Owner", {"email"}, {"OwnerEmail"}),

    Projects_ExpandStakeholder = Table.ExpandListColumn(Projects_ExpandOwner2, "CMS Stakeholder"),
    Projects_ExpandStakeholder2 = Table.ExpandRecordColumn(
        Projects_ExpandStakeholder,
        "CMS Stakeholder",
        {"email"},
        {"StakeholderEmail"}
    ),

    Projects_LowerEmails = Table.TransformColumns(
        Projects_ExpandStakeholder2,
        {
            {"OwnerEmail", each Text.Lower(Text.From(_)), type nullable text},
            {"StakeholderEmail", each Text.Lower(Text.From(_)), type nullable text}
        }
    ),

    Projects_Clean = Table.RemoveColumns(Projects_LowerEmails, {"lookupId","lookupValue"}),

    //
    // EXPAND SHAREPOINT TEAM LOOKUP
    //
    Projects_NormalizeTeam =
    Table.TransformColumns(
        Projects_Clean,
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
    Projects_ExpandTeam =
    Table.ExpandListColumn(Projects_NormalizeTeam, "Team"),

    Projects_ExpandTeam2 =
    Table.ExpandRecordColumn(
        Projects_ExpandTeam,
        "Team",
        {"Value", "Id"},
        {"Team.Value", "Team.Id"}
    ),

    Projects_ExpandTeam3 =
    Table.TransformColumns(
        Projects_ExpandTeam2,
        {{"Team.Value", each Text.Trim(Text.Clean(_)), type text}}
    ),

    Merge_Team =
    Table.NestedJoin(
        Projects_ExpandTeam3,
        {"Team.Value"},
        Teams_Selected,
        {"cr8b0_name"},
        "TeamDV",
        JoinKind.LeftOuter
    ),

    Expand_Team =
    Table.ExpandTableColumn(
        Merge_Team,
        "TeamDV",
        {"cr8b0_cwstp_teamid"},
        {"TeamGUID"}
    ),
    
    //
    // MERGE OWNER + STAKEHOLDER IN ONE PASS
    //
    Merge_Owner = Table.NestedJoin(
        Expand_Team,
        {"OwnerEmail"},
        Users_Deduped,
        {"email_lower"},
        "OwnerUser",
        JoinKind.LeftOuter
    ),

    Merge_Stakeholder = Table.NestedJoin(
        Merge_Owner,
        {"StakeholderEmail"},
        Users_Deduped,
        {"email_lower"},
        "StakeholderUser",
        JoinKind.LeftOuter
    ),

    Expand_Owner = Table.ExpandTableColumn(
        Merge_Stakeholder,
        "OwnerUser",
        {"systemuserid","azureactivedirectoryobjectid","email_lower"},
        {"Owner.systemuserid","Owner.azureactivedirectoryobjectid","Owner.email"}
    ),

    Expand_Stakeholder = Table.ExpandTableColumn(
        Expand_Owner,
        "StakeholderUser",
        {"systemuserid","azureactivedirectoryobjectid","email_lower"},
        {"Stakeholder.systemuserid","Stakeholder.azureactivedirectoryobjectid","Stakeholder.email"}
    ),
  #"Removed columns" = Table.RemoveColumns(Expand_Stakeholder, {"Team.Id", "Dependent Tasks", "Color Tag", "Compliance Asset Id", "Approval Creator", "Approval status", "Approvers", "Responses", "Version", "Schedule Variance", "Content Type", "Created", "Created By", "Modified By", "Attachments", "Edit", "Type", "Item Child Count", "Folder Child Count", "Label setting", "Retention label", "Retention label Applied", "Label applied by", "Item is a Record", "App Created By", "App Modified By", "Modified"})

in
    #"Removed columns"