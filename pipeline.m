let
    // Data Source (csv file)
    Source = Csv.Document(File.Contents(FilePath),[Delimiter=",", Columns=6, Encoding=1252, QuoteStyle=QuoteStyle.None]),
    
    // Promote Headers
    #"Promoted Headers" = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),

    // Clean data dynamically (trim + clean)
    #"Clean Text Columns" = 
        Table.TransformColumns(
            #"Promoted Headers",
            List.Transform(
                Table.ColumnNames(#"Promoted Headers"),
                (columnName) => {
                    columnName,
                    each
                        if _ = null 
                            then null
                        else
                            let
                                cleanedValue = Text.Trim(Text.Clean(_))
                            in
                                if (columnName = "card" and cleanedValue = "")
                                    then "Cash"
                                else if (columnName = "cash_type" or columnName = "coffee_name")
                                    then Text.Proper(cleanedValue)
                                else
                                    cleanedValue,
                type text}
            )
        ),

    // Assign Required Date Types
    #"Changed Date And Datetime Types" = 
        Table.TransformColumnTypes(
            #"Clean Text Columns",
            {
                {"datetime", type datetime}, 
                {"date", type date}
            }
        ),

    // Business Transformations
    #"Added Time Date and Text Dimensions" = 
        Table.ExpandRecordColumn(
            Table.AddColumn(
                #"Changed Date And Datetime Types", 
                "TemporalRecord", 
                each [
                    coffee_product_category = 
                        (
                            if (Text.Contains([coffee_name], "Americano With Milk", Comparer.OrdinalIgnoreCase))
                                then "Milk Variants" 
                            else if (Text.Contains([coffee_name], "Cocoa", Comparer.OrdinalIgnoreCase) or Text.Contains([coffee_name], "Hot Chocolate", Comparer.OrdinalIgnoreCase))
                                then "Chocolate Based" 
                            else "Coffee Based"
                        ),

                    year = Date.Year([date]),
                    month_name = Date.MonthName([date]),
                    number_of_products = 1,

                    shift = 
                        (
                            let
                                hourOfDay = Time.Hour([datetime])
                            in
                                if (hourOfDay < 12) 
                                    then "Morning"
                                else if (hourOfDay < 18) 
                                    then "Afternoon"
                                else "Evening"
                        ),

                    type_of_day = 
                        (
                            let
                                dayOfWeek = Date.DayOfWeekName([date])
                            in
                                if (dayOfWeek = "Saturday" or dayOfWeek = "Sunday") 
                                    then "Weekend Day" 
                                else "Weekday"
                        )
                    ]
            ), 
            "TemporalRecord", 
            {"coffee_product_category", "year", "month_name", "number_of_products", "shift", "type_of_day"}
        ),

    // Final Types
    #"Changed Remaining Data Types" = 
        Table.TransformColumnTypes(
            #"Added Time Date and Text Dimensions",
            {
                {"cash_type", type text},
                {"card", type text},
                {"coffee_product_category", type text}, 
                {"year", Int64.Type},
                {"month_name", type text},
                {"number_of_products", Int64.Type},
                {"shift", type text}, 
                {"type_of_day", type text},
                {"coffee_name", type text},
                {"money", Currency.Type}
            }
        ),

    // Renamed useful columns
    #"Renamed Columns" = 
        Table.RenameColumns(
            #"Changed Remaining Data Types",
            {
                {"money", "amount"}, 
                {"cash_type", "payment_method"},
                {"card", "payment_method_id"}
            }
        ),

    // Reordered dataset columns
    #"Reordered Columns" = 
        Table.ReorderColumns(
            #"Renamed Columns",
            {"date", "datetime", "shift", "month_name", "type_of_day", "year", "payment_method", "payment_method_id", "coffee_name", "coffee_product_category", "amount", "number_of_products"}
        )
in
    #"Reordered Columns"