
function decays(df_properties::DataFrame)
    df = df_properties[df_properties.data_type.|>!ismissing, :]
    selection_list = map(df.pdgid) do p
        !contains(p[2:end], r"M|W|PP|T")
    end
    df = df[selection_list, :]
    select!(df, Not(:unit_text))
end

function parameters(df_properties::DataFrame)
    selection_list = map(df_properties.pdgid) do p
        contains(p[2:end], r"M|W|PP|T")
    end
    df_properties[selection_list, :]
end

function getmeasurenent(df_properties::DataFrame, property)
    selection_list = map(df_properties.pdgid) do p
        # @show p => contains(p[2:end], property)
        contains(p[2:end], property)
    end
    if sum(selection_list) == 0
        @error "No $(property) value is found for $(df_properties.pdgid[1])"
    end
    df_properties[selection_list, :]
end
Measurements.Measurement(dfr::DataFrameRow) =
    dfr.value ± max(dfr.error_positive, dfr.error_negative)
# 
function summarize(df::DataFrame)
    measurements = Measurement.(eachrow(df))
    label = df.description .* "(" .* String.(df.value_type) .* ")"
    label .=> measurements
end


"""
    pick(df::DataFrame, column_values::Vector{Pair{Symbol,String}}) -> Measurement

Retrieve a specific measurement from a DataFrame based on provided column-value pairs.

# Arguments
- `df::DataFrame`: The DataFrame from which to retrieve the measurement.
- `column_values::Vector{Pair{Symbol,String}}`: A vector of pairs. Each pair consists of a column name (as a `Symbol`) and a value (as a `String`). The function will use these pairs to filter rows in the DataFrame.

# Returns
- A `Measurement` object, typically containing a value and its associated uncertainty.

# Behavior
- The function filters the DataFrame based on the provided column-value pairs.
- If more than one row matches the provided criteria, an error is thrown.

# Example
```julia
particle_props = properties(pdg("muon"))
measurement = pick(particle_props, [(:data_type, "mass")])
```

# Notes
- The function assumes that the filtered DataFrame contains exactly one relevant row. If the filtering criteria match multiple rows or no rows, an error is raised.
- This function is particularly useful for extracting specific parameter values from a DataFrame containing particle properties.

"""
function pick(df::DataFrame,
    column_values::Vector{T} where {T<:Pair{Symbol,String}})
    selected_list = .*(map(column_values) do (column, value)
        df[:, column] .== value
    end...)
    df_picked = df[selected_list, :]

    size(df_picked, 1) != 1 &&
        error("More than one value selected by requiring df[$(column)]==$(value)")
    Measurement(df_picked[1, :])
end


"""
    pick(df::DataFrame, column_value::Pair{Symbol,String}) -> Measurement

Retrieve a specific measurement from a DataFrame based on a provided column-value pair.

# Arguments
- `df::DataFrame`: The DataFrame from which to retrieve the measurement.
- `column_value::Pair{Symbol,String}`: A pair consisting of a column name (as a `Symbol`) and a value (as a `String`). The function will use this pair to filter rows in the DataFrame.

# Returns
- A `Measurement` object, typically containing a value and its associated uncertainty.

# Behavior
- The function filters the DataFrame based on the provided column-value pair.
- If more than one row matches the provided criteria, an error is thrown.

# Example
```julia
mass_records = pdg("Omega_c()") |> properties |> mass
measurement = pick(mass_records, :value_type=>"AC")
```

# Notes
- This is a convenience function that wraps around the primary `pick` function to handle the common use-case of filtering based on a single column-value criterion.
- The function assumes that the filtered DataFrame contains exactly one relevant row. If the filtering criteria match multiple rows or no rows, an error is raised.

"""
pick(df::DataFrame, column_value::Pair{Symbol,String}) = pick(df, [column_value])


mass(df_properties::DataFrame) = getmeasurenent(df_properties, "M")
width(df_properties::DataFrame) = getmeasurenent(df_properties, "W")
lifetime(df_properties::DataFrame) = getmeasurenent(df_properties, "T")
pole(df_properties::DataFrame) = getmeasurenent(df_properties, "PP")
