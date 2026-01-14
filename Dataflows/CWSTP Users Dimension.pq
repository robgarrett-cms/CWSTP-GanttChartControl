let
    CDS = CommonDataService.Database("org6cd1f51e.crm9.dynamics.com"),
    
    SystemUsers = CDS{[Schema="dbo", Item="systemuser"]}[Data],

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

    Users_Deduped = Table.Distinct(Users_Sorted, {"email_lower"})
in
  Users_Deduped