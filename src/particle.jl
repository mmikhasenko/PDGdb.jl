function tokenize(s::String)::Vector{String}
    # Split the string at non-alphanumeric characters
    tokens = split(s, r"[^a-zA-Z0-9]+")
    # Filter out empty tokens
    return filter(!isempty, tokens)
end

function jaccard_similarity(A::Vector{String}, B::Vector{String})::Float64
    union_size = length(union(A, B))
    intersection_size = length(intersect(A, B))

    # Handle case where both sets are empty
    if union_size == 0
        return 1.0
    end

    return intersection_size / union_size
end

function closest_key_token_based(user_input::String, keys::Vector{String})
    user_tokens = tokenize(user_input)
    similarities = [(key, jaccard_similarity(user_tokens, tokenize(key))) for key in keys]

    # Sort by similarity (highest first)
    sort!(similarities, by=x -> x[2], rev=true)

    # Return the key with the highest similarity
    return getindex.(similarities[1:5], 1)
end


"""
    pdg(particle_name::String) -> DataFrame

Search for a particle in the `pdgparticle` table based on a provided name or guess.

# Arguments
- `particle_name::String`: The name or a guess for the particle's name.

# Returns
- A DataFrame containing information about the particle from the `pdgparticle` table.

# Behavior
- If an exact match for the provided `particle_name` is found, the corresponding data for that particle is returned.
- If no exact match is found, the function searches for similar particle names and selects the most similar one.
- If multiple matches are found for the provided `particle_name`, a warning is issued, and one of the matching particles is returned.

# Example
```julia
particle_df = pdg("Lambda_c")
```

# Notes
- This function uses a token-based similarity measure to find the closest matching particle name if an exact match is not found.
- In cases where multiple matches or no matches are found, the function provides feedback via logging messages.

"""
function pdg(particle_name)
    key = particle_name
    if sum(all_particles_names .== particle_name) == 0
        list = closest_key_token_based(particle_name, all_particles_names)
        @info "No exact key found for $(particle_name). Similar items: $(list).\nI pick the first one!"
        key = list[1]
    end
    if sum(all_particles_names .== particle_name) > 1
        list = closest_key_token_based(particle_name, all_particles_names)
        @warn "More than key exists for $(particle_name), likely a problem in the PDG table.\nPerhaps try other key, e.g. $(list)"
    end
    unique_particles[all_particles_names.==key, :]
end

"""
    properties(particle_pdgid::String) -> DataFrame

Retrieve properties of a particle based on its PDG ID.

Given the PDG ID (`particle_pdgid`) of a particle, this function returns a DataFrame
containing all its associated properties from the `pdgdata` table.

The returned DataFrame excludes certain columns like `id`, `pdgid_id`, `confidence_level`,
and others that are deemed less relevant or redundant for the purpose of this function.

Additionally, the function performs a left join with the `pdgid` table to add descriptions
to the properties, excluding the `parent_id` column as it doesn't provide new information.

# Arguments
- `particle_pdgid::String`: The PDG ID of the particle of interest.

# Returns
- `DataFrame`: A DataFrame containing properties and descriptions associated with the given particle's PDG ID.

# Example
```julia
df = properties("B010")
"""
function properties(particle_pdgid::String)
    df = pdgdata[contains.(pdgdata.pdgid, particle_pdgid), :]
    select!(df,
        Not(:id, :pdgid_id, :confidence_level, :limit_type,
            :edition, :in_summary_table, :comment, :sort,
            :display_in_percent, :display_power_of_ten, :scale_factor))

    # add description
    df_merged = leftjoin(df,
        select(pdgid, Not(
            :parent_id, # pdgid_id not new info (->pdgid)
            :parent_pdgid)), on=:pdgid)
    return df_merged
end


"""
    properties(df::DataFrame) -> DataFrame

Retrieve particle properties from the `pdgdata` table based on the provided particle DataFrame.

# Arguments
- `df::DataFrame`: A DataFrame, typically the result from the `pdg(name)` function, containing information about a specific particle. The function will use the `pdgid` from the first row of this DataFrame.

# Returns
- A DataFrame containing detailed properties of the particle from the `pdgdata` table. This DataFrame is a result of joining information from the `pdgid` and `pdgdata` tables.

# Example
```julia
particle_df = PDGdb.pdg("pi+")
props = properties(particle_df)
```

# Notes
- This function is a convenience function designed to work in tandem with the `pdg(name)` function.
- If the input DataFrame has more than one row, only the `pdgid` from the first row is used.
"""
properties(df::DataFrame) = properties(df.pdgid[1])
