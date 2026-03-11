let
    // 1. DATA SOURCE: SHAREPOINT
    SiteUrl = "https://cmsgovonline.sharepoint.com/sites/CWSTPTeam",
    ListName = "CWSTP Project and Task Management",
    OrgUri = "org6cd1f51e.crm9.dynamics.com",
    
    SP = SharePoint.Tables(SiteUrl, [Implementation="2.0", ViewMode="All"]),
    Source = SP{[Title=ListName]}[Items],

    // 2. GET DISTINCT EMAILS (The "Source of Truth")
    StakeholderList = List.Combine(Table.Column(Source, "CMS Stakeholder")),
    OwnerList = List.Combine(Table.Column(Source, "Owner")),
    AllUsers = List.Combine({StakeholderList, OwnerList}),
    
    // Create a Table, Expand, and get UNIQUE emails only
    UserTable = Table.FromList(AllUsers, Splitter.SplitByNothing(), {"Raw"}),
    Expanded = Table.ExpandRecordColumn(UserTable, "Raw", {"title", "email"}, {"Name", "Email"}),
    UniqueSPEmails = Table.Distinct(Table.SelectRows(Expanded, each ([Email] <> null))),

    // 3. BUILD ODATA FILTER
    // We only pull AAD data for the emails we actually found
    EmailList = UniqueSPEmails[Email],
    FilterString = Text.Combine(List.Transform(EmailList, each "mail eq '" & _ & "'"), " or "),

    // 4. CALL ODATA API
    ApiUrl = "https://" & OrgUri & "/api/data/v9.1/aadusers?$select=mail,aaduserid&$filter=" & FilterString,
    AADResponse = Json.Document(Web.Contents(ApiUrl)),
    AADTable = Table.FromRecords(AADResponse[value]),

    // 5. JOIN UNIQUE LIST TO AAD DATA
    // This ensures 1 row per unique email address
    FinalUniqueUsers = Table.Join(
        UniqueSPEmails, "Email", 
        AADTable, "mail", 
        JoinKind.LeftOuter
    ),
    
    // Cleanup: Remove the redundant 'mail' column from the API
    RemoveExtraColumn = Table.RemoveColumns(FinalUniqueUsers, {"mail"}),
  #"Changed column type" = Table.TransformColumnTypes(RemoveExtraColumn, {{"aaduserid", type text}})
in
    #"Changed column type"