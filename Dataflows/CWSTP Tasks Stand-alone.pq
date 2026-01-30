let
  Source = #"Tasks Base",
  #"Filtered rows" = Table.SelectRows(
    Source,
    each [Type of Action] = "Stand Alone Activity"
        //and ( [Parent Project] = null or [Parent Project] = "" )
),
  #"Sorted rows" = Table.Sort(#"Filtered rows", {{"ID", Order.Ascending}})
in
  #"Sorted rows"