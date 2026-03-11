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

    // Users Table Setup (Lowercased & Buffered for performance)
    Users_Raw = CDS{[Schema="dbo", Item="cr8b0_cwstpusers"]}[Data],
    Users_Lower = Table.TransformColumns(Users_Raw, {{"cr8b0_email", Text.Lower, type text}}),
    Users_Clean = Table.Buffer(Table.SelectColumns(Users_Lower, {"cr8b0_aadobjectid", "cr8b0_email", "cr8b0_id"})),

    //
    // SHAREPOINT TASKS
    //
    SP = SharePoint.Tables(SiteUrl, [Implementation="2.0", ViewMode="All"]),
    Source = SP{[Title=ListName]}[Items],
    
    // Filter for Tasks (Adjust "Task" string if your SharePoint value differs)
    #"Filtered Tasks" = Table.SelectRows(Source, each ([Type of Action] <> "Parent Project")),

    //
    // NORMALIZE TASK DATA
    //
    Tasks_Normalized = Table.TransformColumns(#"Filtered Tasks", {
        {"Progress (%)", each if _ = null then 0 else _, Int64.Type},
        {"Archived", each if _ = null then false else _, type logical},
        {"Status", each if _ = "" or _ = null then "Not Started" else _, type text}
    }),

    //
    // OWNER + STAKEHOLDER EMAILS (Expanding records)
    //
    ExpandOwner = Table.ExpandRecordColumn(Table.ExpandListColumn(Tasks_Normalized, "Owner"), "Owner", {"email"}, {"OwnerEmail"}),
    ExpandStakeholder = Table.ExpandRecordColumn(Table.ExpandListColumn(ExpandOwner, "CMS Stakeholder"), "CMS Stakeholder", {"email"}, {"StakeholderEmail"}),

    LowerEmails = Table.TransformColumns(ExpandStakeholder, {
        {"OwnerEmail", each Text.Lower(Text.From(_)), type nullable text},
        {"StakeholderEmail", each Text.Lower(Text.From(_)), type nullable text}
    }),

    //
    // JOIN USER TABLE (MATCHING ON EMAIL)
    //
    JoinOwner = Table.NestedJoin(LowerEmails, {"OwnerEmail"}, Users_Clean, {"cr8b0_email"}, "Owner_Data", JoinKind.LeftOuter),
    JoinStakeholder = Table.NestedJoin(JoinOwner, {"StakeholderEmail"}, Users_Clean, {"cr8b0_email"}, "Stakeholder_Data", JoinKind.LeftOuter),
  #"Expanded Owner_Data" = Table.ExpandTableColumn(JoinStakeholder, "Owner_Data", {"cr8b0_aadobjectid", "cr8b0_email", "cr8b0_id"}, {"Owner_Data.cr8b0_aadobjectid", "Owner_Data.cr8b0_email", "Owner_Data.cr8b0_id"}),
  #"Expanded Stakeholder_Data" = Table.ExpandTableColumn(#"Expanded Owner_Data", "Stakeholder_Data", {"cr8b0_aadobjectid", "cr8b0_email", "cr8b0_id"}, {"Stakeholder_Data.cr8b0_aadobjectid", "Stakeholder_Data.cr8b0_email", "Stakeholder_Data.cr8b0_id"}),
  #"Renamed columns" = Table.RenameColumns(#"Expanded Stakeholder_Data", {{"Stakeholder_Data.cr8b0_id", "Stakeholder_ID"}, {"Stakeholder_Data.cr8b0_email", "Stakeholder_Email"}, {"Stakeholder_Data.cr8b0_aadobjectid", "Stakeholder_AADObjectId"}, {"Owner_Data.cr8b0_id", "Owner_ID"}, {"Owner_Data.cr8b0_email", "Owner_Email"}, {"Owner_Data.cr8b0_aadobjectid", "Owner_AADObjectId"}}),
  #"Replaced value" = Table.ReplaceValue(#"Renamed columns", "On Hold - pend stakeholder", "On Hold - Pending Stakeholder", Replacer.ReplaceText, {"Status"})

in
    #"Replaced value"