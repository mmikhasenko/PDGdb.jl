
pdgdoc = DataFrame()
legend = []
# 
pdginfo = DataFrame()
pdgid = DataFrame()
pdgdata = DataFrame()
# 
pdgparticle = DataFrame()
unique_particles = DataFrame()
#
all_particles_names = String[]


function read2memory(db::SQLite.DB, table_name, nrow=-1)
    query = "SELECT * FROM $(table_name)" * (nrow > 0 ? " LIMIT $(nrow);" : "")
    "SELECT * FROM $(table_name)"
    DBInterface.execute(db, query) |> DataFrame
end

function determine_dims(db::SQLite.DB, table_name)
    # Query to get the number of rows
    row_query = "SELECT COUNT(*) FROM $table_name;"
    num_rows = DBInterface.execute(db, row_query) |> DataFrame |> x -> x[1, 1]

    # Query to get the number of columns
    col_query = "PRAGMA table_info($table_name);"
    num_cols = nrow(DBInterface.execute(db, col_query) |> DataFrame)

    (; num_rows, num_cols)
end

function connect(path2)
    db = SQLite.DB(path2)
    # 
    tables_df = let
        query = "SELECT name FROM sqlite_master WHERE type='table';"
        tables_df = DBInterface.execute(db, query) |> DataFrame
        df_dims = determine_dims.(db |> Ref, tables_df.name)
        select(hcat(tables_df, df_dims), :name, :x1 => AsTable)
    end
    print(tables_df)

    # general info about DB. Printed as output
    global pdginfo = read2memory(db, "pdginfo")

    # three main tables
    global pdgid = select(read2memory(db, "pdgid"),
        Not(:sort, :year_added, :id, :mode_number))
    global pdgparticle = read2memory(db, "pdgparticle")
    global pdgdata = read2memory(db, "pdgdata")

    # documentation: info about short cuts
    global pdgdoc = select(read2memory(db, "pdgdoc"),
        Not(:indicator, :comment, :id))
    global legend = [
        Symbol(lowercase(dgb.column_name[1])) =>
            Dict(dgb.value .=> dgb.description)
        for dgb in groupby(pdgdoc, [:table_name, :column_name])]
    # 
    global unique_particles = pdgparticle[
        (pdgparticle.entry_type.=="P").&&(pdgparticle.charge_type.!="G"),
        :]
    global all_particles_names = unique_particles.name
    # 
    return pdginfo
end