let
    //
    // CONSTANTS
    //
    SiteUrl = "https://cmsgovonline.sharepoint.com/sites/CWSTPTeam",
    ListName = "CWSTP Project and Task Management",

    //
    // LOAD DATAVERSE
    //
    CDS = CommonDataService.Database("org6cd1f51e.crm9.dynamics.com"),

    Teams_Raw = CDS{[Schema="dbo", Item="cr8b0_cwstp_team"]}[Data],
    Teams_Clean = Table.Buffer(Table.SelectColumns(Teams_Raw, {"cr8b0_name"})),

    // LOWERCASE THE USER EMAILS ---
    Users_Raw = CDS{[Schema="dbo", Item="cr8b0_cwstpusers"]}[Data],
    Users_Lower = Table.TransformColumns(Users_Raw, {{"cr8b0_email", Text.Lower, type text}}),
    Users_Clean = Table.Buffer(Table.SelectColumns(Users_Lower, {"cr8b0_aadobjectid", "cr8b0_email", "cr8b0_id"})),
        
    //
    // SHAREPOINT PROJECTS
    //
    SP = SharePoint.Tables(SiteUrl, [Implementation="2.0", ViewMode="All"]),
    Projects = SP{[Title=ListName]}[Items],
    #"Filtered rows" = Table.SelectRows(Projects, each ([Type of Action] = "Parent Project")),

    //
    // FIX PROGRESS, ROADMAP, ARCHIVED, STATUS
    //
    Projects_Normalized = Table.TransformColumns(#"Filtered rows", {
        {"Progress (%)", each if _ = null then 0 else _, Int64.Type},
        {"Roadmap_choice", each if _ = "Roadmap" then "True" else if _ = "n/a" or _ = "" then "False" else _, type text},
        {"Archived", each if _ = null then false else _, type logical},
        {"Status", each if _ = "" then "Not Started" else _, type text}
    }),

    Projects_RoadmapBool = Table.TransformColumnTypes(Projects_Normalized, {{"Roadmap_choice", type logical}}),

    Projects_Progress = Table.TransformColumns(
        Table.AddColumn(Projects_RoadmapBool, "ProgressTemp", each if Text.Lower([Status]) = "complete" then 100 else [#"Progress (%)"], Int64.Type),
        {{"ProgressTemp", each _, Int64.Type}}
    ),

    Projects_FinalProgress = Table.RenameColumns(
        Table.RemoveColumns(Projects_Progress, {"Progress (%)"}),
        {{"ProgressTemp", "Progress (%)"}}
    ),

    //
    // OWNER + STAKEHOLDER EMAILS (Expanding records)
    //
    ExpandOwner = Table.ExpandRecordColumn(Table.ExpandListColumn(Projects_FinalProgress, "Owner"), "Owner", {"email"}, {"OwnerEmail"}),
    ExpandStakeholder = Table.ExpandRecordColumn(Table.ExpandListColumn(ExpandOwner, "CMS Stakeholder"), "CMS Stakeholder", {"email"}, {"StakeholderEmail"}),

    LowerEmails = Table.TransformColumns(ExpandStakeholder, {
        {"OwnerEmail", each Text.Lower(Text.From(_)), type nullable text},
        {"StakeholderEmail", each Text.Lower(Text.From(_)), type nullable text}
    }),

    //
    // NORMALIZE TEAM LOOKUP
    //
    NormalizeTeam = Table.TransformColumns(LowerEmails, {
        {"Team", each if _ is null then {} else if _ is list then _ else if _ is record then {_} else if _ is text then { [Value = _, Id = null] } else {}, type list}
    }),

    ExpandTeam = Table.ExpandRecordColumn(Table.ExpandListColumn(NormalizeTeam, "Team"), "Team", {"Value"}, {"Team.Value"}),
    CleanTeamValue = Table.TransformColumns(ExpandTeam, {{"Team.Value", each Text.Trim(Text.Clean(_)), type text}}),

    //
    // MERGE TEAMS
    //
    MergeTeams = Table.NestedJoin(CleanTeamValue, {"Team.Value"}, Teams_Clean, {"cr8b0_name"}, "TeamDV", JoinKind.LeftOuter),
    #"Replaced value" = Table.ReplaceValue(MergeTeams, "On Hold - pend stakeholder", "On Hold - Pending Stakeholder", Replacer.ReplaceText, {"Status"}),
    FinalPrep = Table.RenameColumns(#"Replaced value", {{"Team.Value", "TeamName"}}),

    //
    // JOIN USER TABLE (MATCHING ON EMAIL)
    //
    JoinOwner = Table.NestedJoin(FinalPrep, {"OwnerEmail"}, Users_Clean, {"cr8b0_email"}, "Owner_Data", JoinKind.LeftOuter),
    JoinStakeholder = Table.NestedJoin(JoinOwner, {"StakeholderEmail"}, Users_Clean, {"cr8b0_email"}, "Stakeholder_Data", JoinKind.LeftOuter),

    //
    // FINAL EXPANSION
    //
    #"Expanded TeamDV" = Table.ExpandTableColumn(JoinStakeholder, "TeamDV", {"cr8b0_name"}, {"TeamDV.cr8b0_name"}),
    #"Expanded Owner_Data" = Table.ExpandTableColumn(#"Expanded TeamDV", "Owner_Data", {"cr8b0_aadobjectid", "cr8b0_email", "cr8b0_id"}, {"Owner_Data.cr8b0_aadobjectid", "Owner_Data.cr8b0_email", "Owner_Data.cr8b0_id"}),
    #"Expanded Stakeholder_Data" = Table.ExpandTableColumn(#"Expanded Owner_Data", "Stakeholder_Data", {"cr8b0_aadobjectid", "cr8b0_email", "cr8b0_id"}, {"Stakeholder_Data.cr8b0_aadobjectid", "Stakeholder_Data.cr8b0_email", "Stakeholder_Data.cr8b0_id"}),
  #"Renamed columns" = Table.RenameColumns(#"Expanded Stakeholder_Data", {{"Stakeholder_Data.cr8b0_aadobjectid", "Stakeholder_AADObjectId"}, {"Stakeholder_Data.cr8b0_email", "Stackeholder_Email"}, {"Stakeholder_Data.cr8b0_id", "Stakeholder_ID"}, {"Owner_Data.cr8b0_id", "Owner_ID"}, {"Owner_Data.cr8b0_email", "Owner_Email"}, {"Owner_Data.cr8b0_aadobjectid", "Owner_AADObjectId"}})

in
    #"Renamed columns"