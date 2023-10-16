### A Pluto.jl notebook ###
# v0.19.29

using Markdown
using InteractiveUtils

# ╔═╡ bf4d2200-6b6b-11ee-3f91-85c5c3c4f350
begin
	using SQLite
	using DataFrames
	using Measurements
end

# ╔═╡ be12976f-1db4-4a64-9b78-0dfaf2867d68
using StatsBase

# ╔═╡ 2cdc9a3b-af49-4c76-b80a-bcb08645cc97
module PDGdb
	using DataFrames
	using SQLite
	using Measurements

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

	export connect
	export pdg
	export properties, decays
	export mass, width, lifetime

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
		db = SQLite.DB("C:\\Users\\Mikhasenko\\Downloads\\pdg-2023-v0.0.5.sqlite")
		# 
		tables_df = let
			query = "SELECT name FROM sqlite_master WHERE type='table';"
			tables_df = DBInterface.execute(db, query) |> DataFrame
			df_dims = determine_dims.(db |> Ref, tables_df.name)
			select(hcat(tables_df, df_dims), :name, :x1 => AsTable)
		end
		print(tables_df)
		
		global pdginfo = read2memory(db, "pdginfo")
		global pdgid = select(read2memory(db, "pdgid"),
			Not(:sort, :year_added, :id, :mode_number))
		# 
		global pdgparticle = read2memory(db, "pdgparticle")
		global pdgdata = read2memory(db, "pdgdata")

		# 
		global pdgdoc = select(read2memory(db, "pdgdoc"),
			Not(:indicator,:comment,:id))
		global legend = [
			Symbol(lowercase(dgb.column_name[1])) =>
				Dict(dgb.value .=> dgb.description)
		for dgb in groupby(pdgdoc, [:table_name, :column_name])]
		# 
		
		# 
		global unique_particles = pdgparticle[
			(pdgparticle.entry_type .== "P") .&& (pdgparticle.charge_type .!= "G"),
			:]
		global all_particles_names = unique_particles.name
		# 
		return pdginfo
	end


	#
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
	    sort!(similarities, by=x->x[2], rev=true)
	    
	    # Return the key with the highest similarity
		return getindex.(similarities[1:5], 1) 
	end
	# 


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
		unique_particles[all_particles_names .== key, :]
	end

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
	properties(df::DataFrame) = properties(df.pdgid[1])

	function decays(df_properties::DataFrame)
		df = df_properties[df_properties.data_type  .|> !ismissing, :]
		selection_list = map(df_properties.pdgid) do p
			!contains(p[2:end], r"M|W|PP|T")
		end
		df = df[selection_list, :]
		select!(df, Not(:unit_text))
	end

	function parameters(df_properties::DataFrame)
		selection_list = map(df_properties.pdgid) do p
			contains(p[2:end], r"M|W|PP|T")
		end
		df = df_properties[selection_list, :]
	end

	function getmeasurenent(df_properties::DataFrame, property)
		selection_list = map(df_properties.pdgid) do p
			# @show p => contains(p[2:end], property)
			contains(p[2:end], property)
		end
		if sum(selection_list) == 0
			@error "No $(property) value is found for $(df_properties.pdgid[1])"
		end
		df = df_properties[selection_list, :]
	end
	Measurements.Measurement(dfr::DataFrameRow) =
		dfr.value ± max(dfr.error_positive, dfr.error_negative)
	# 
	function summarize(df::DataFrame)
		measurements = Measurement.(eachrow(df))
		label = df.description .* "(" .* String.(df.value_type) .* ")"
		label .=> measurements
	end
	pick(df::DataFrame, column_value::Pair{Symbol, String}) = 
		pick(df, [column_value])
	function pick(df::DataFrame,
		column_values::Vector{T} where T<:Pair{Symbol, String})
		selected_list = .*(map(column_values) do (column,value)
			df[:,column] .== value
		end...)
		df_picked = df[selected_list, :]
		
		size(df_picked,1) != 1 && 
			error("More than one value selected by requiring df[$(column)]==$(value)")
		Measurement(df_picked[1,:])
	end

	mass(df_properties::DataFrame) = getmeasurenent(df_properties, "M")
	width(df_properties::DataFrame) = getmeasurenent(df_properties, "W")
	lifetime(df_properties::DataFrame) = getmeasurenent(df_properties, "T")
	pole(df_properties::DataFrame) = getmeasurenent(df_properties, "PP")
end

# ╔═╡ 5c18f81a-9ce2-4f0e-a207-6259f53560db
import .PDGdb: pdg, properties, decays, parameters, mass, width, lifetime, summarize

# ╔═╡ 6ecdbcf9-789e-4c7a-a5f9-99e1e7acdaf2
 .*([true, false, true], [true, true, true], [true, true, false])

# ╔═╡ cd6e8f57-cbf0-4945-9f55-fcd0892e5ea2
md"""
## Connect to the DG, load info
"""

# ╔═╡ c896f433-94e3-45aa-b41a-a0e887b71300
PDGdb.connect("C:\\Users\\Mikhasenko\\Downloads\\pdg-2023-v0.0.5.sqlite")

# ╔═╡ 9681e81c-1937-4fa2-8c0e-1aa63b0ab294
properties(pdg("pi(1800)+")) |> decays

# ╔═╡ f56445ea-f97b-4e7a-962d-0f7b66afbda2
md"""
## J/ψ information
"""

# ╔═╡ 2f76db9a-5eca-4eed-9f32-f3f833b5fe8f
begin
	jpsi_decays = properties(pdg("J/psi(1S)")) |> decays
	jpsi_decays[contains.(jpsi_decays.description, "Sigma"), :]
end

# ╔═╡ 01094c8d-c496-453e-ba75-ebe33688cb69
md"""
## Charm baryons
"""

# ╔═╡ 6bcd116d-df93-4efe-a8f7-812a934e0de6
charmed_baryon_names = ["Lambda_c", "Sigma_c", "Xi_c", "Omega_c"]

# ╔═╡ 2133ff6b-ec3c-47f3-8bb6-d4b6063c6046
begin
	pi1_decays = PDGdb.pdg("pi_1") |> properties |> decays
end

# ╔═╡ b4a7bd24-974c-45c5-98c1-bf42b4268285
particle_props = properties(pdg("Omega_c()0"))

# ╔═╡ 9ccfc71a-44ca-4d09-99ba-7e68fa65f9ea
PDGdb.pick(mass(particle_props), :value_type=>"AC")

# ╔═╡ 506a18ff-a4c5-47c1-9efc-63d6bc728e46
df_charm_baryons = vcat(
	pdg("Lambda_c()+"),
	pdg("Sigma_c()0"), pdg("Sigma_c()+"), pdg("Sigma_c()++"),
	pdg("Xi_c()+"), pdg("Xi_c()0"),
	pdg("Omega_c()0"))

# ╔═╡ 2fbe76cf-5504-47c9-9048-c132c1e348ee
vcat(pdg("Delta(1700)0"),pdg("Delta(1700)+"),pdg("Delta(1700)++"))

# ╔═╡ f44122ca-320e-46d3-9e9c-a13a09bdabd7
vcat(pdg("rho(770)+"),pdg("rho(770)0"))

# ╔═╡ 88bdfe5a-5add-4c39-9c45-6b7259786354
properties(pdg("rho(770)+")) |> mass |> eachrow .|> Measurement

# ╔═╡ d429ee6d-6b46-4267-9b68-b452578d5499
vcat(pdg("Sigma_c()++"),pdg("Sigma_c()+"),pdg("Sigma_c()0"))

# ╔═╡ adaa2bd1-8053-4304-b9f8-e912a120451e
pdg("Lambda_c()+") |> properties |> parameters

# ╔═╡ 53ae109b-4bad-4bf7-ac63-3bebf6fb238b
vcat(pdg("D_s()+"),pdg("D_s()-"))

# ╔═╡ 8d017473-03fa-42a6-a13f-144722673bb6
properties(pdg("Xi_c()+").pdgid[1])

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
SQLite = "0aa819cd-b072-5ff4-a722-6bc24af294d9"
StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"

[compat]
DataFrames = "~1.6.1"
Measurements = "~2.10.0"
SQLite = "~1.6.0"
StatsBase = "~0.34.2"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.3"
manifest_format = "2.0"
project_hash = "a2a72580a20b0dfe353a222c72ab99246cbfe9d1"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[deps.Compat]]
deps = ["UUIDs"]
git-tree-sha1 = "8a62af3e248a8c4bad6b32cbbe663ae02275e32c"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.10.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.5+0"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DBInterface]]
git-tree-sha1 = "9b0dc525a052b9269ccc5f7f04d5b3639c65bca5"
uuid = "a10d1c49-ce27-4219-8d33-6db1a4562965"
version = "2.5.0"

[[deps.DataAPI]]
git-tree-sha1 = "8da84edb865b0b5b0100c0666a9bc9a0b71c553c"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.15.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "DataStructures", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "REPL", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "04c738083f29f86e62c8afc341f0967d8717bdb8"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.6.1"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "3dbd312d370723b6bb43ba9d02fc36abade4518d"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.15"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "9cc2baf75c6d09f9da536ddf58eb2f29dedaf461"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InvertedIndices]]
git-tree-sha1 = "0dc7b50b8d436461be01300fd8cd45aa0274b038"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "7e5d6779a1e09a36db2a7b6cff50942a0a7d0fca"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.5.0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "7d6dd4e9212aebaeed356de34ccf262a3cd415aa"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.26"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+0"

[[deps.Measurements]]
deps = ["Calculus", "LinearAlgebra", "Printf", "Requires"]
git-tree-sha1 = "bf645d369306c848b6e44e37a1e216b15468c4fc"
uuid = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
version = "2.10.0"

    [deps.Measurements.extensions]
    MeasurementsJunoExt = "Juno"
    MeasurementsRecipesBaseExt = "RecipesBase"
    MeasurementsSpecialFunctionsExt = "SpecialFunctions"
    MeasurementsUnitfulExt = "Unitful"

    [deps.Measurements.weakdeps]
    Juno = "e5e0dc1b-0480-54bc-9374-aad01c23163d"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.10.11"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.21+4"

[[deps.OrderedCollections]]
git-tree-sha1 = "2e73fe17cac3c62ad1aebe70d44c963c3cfdc3e3"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.2"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "716e24b21538abc91f6205fd1d8363f39b442851"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.7.2"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.2"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "03b4c25b43cb84cee5c90aa9b5ea0a78fd848d2f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.0"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00805cd429dcb4870060ff49ef443486c262e38e"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.1"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "Printf", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "ee094908d720185ddbdc58dbe0c1cbe35453ec7a"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.2.7"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SQLite]]
deps = ["DBInterface", "Random", "SQLite_jll", "Serialization", "Tables", "WeakRefStrings"]
git-tree-sha1 = "eb9a473c9b191ced349d04efa612ec9f39c087ea"
uuid = "0aa819cd-b072-5ff4-a722-6bc24af294d9"
version = "1.6.0"

[[deps.SQLite_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "81f7d934b52b2441f7b44520bd982fdb3607b0da"
uuid = "76ed43ae-9a5d-5a62-8c75-30186b810ce8"
version = "3.43.0+0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "04bdff0b09c65ff3e06a05e3eb7b120223da3d39"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "c60ec5c62180f27efea3ba2908480f8055e17cee"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.1.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1ff449ad350c9c4cbc756624d6f8a8c3ef56d3ed"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.7.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "1d77abd07f617c4868c33d4f5b9e1dbb2643c9cf"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.2"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "a04cabe79c5f01f4d723cc6704070ada0b9d46d5"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.3.4"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "5.10.1+6"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "a1f34829d5ac0ef499f6d84428bd6b4c71f02ead"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.11.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╠═bf4d2200-6b6b-11ee-3f91-85c5c3c4f350
# ╠═be12976f-1db4-4a64-9b78-0dfaf2867d68
# ╠═2cdc9a3b-af49-4c76-b80a-bcb08645cc97
# ╠═5c18f81a-9ce2-4f0e-a207-6259f53560db
# ╠═6ecdbcf9-789e-4c7a-a5f9-99e1e7acdaf2
# ╟─cd6e8f57-cbf0-4945-9f55-fcd0892e5ea2
# ╠═c896f433-94e3-45aa-b41a-a0e887b71300
# ╠═9681e81c-1937-4fa2-8c0e-1aa63b0ab294
# ╟─f56445ea-f97b-4e7a-962d-0f7b66afbda2
# ╠═2f76db9a-5eca-4eed-9f32-f3f833b5fe8f
# ╟─01094c8d-c496-453e-ba75-ebe33688cb69
# ╠═6bcd116d-df93-4efe-a8f7-812a934e0de6
# ╠═2133ff6b-ec3c-47f3-8bb6-d4b6063c6046
# ╠═b4a7bd24-974c-45c5-98c1-bf42b4268285
# ╠═9ccfc71a-44ca-4d09-99ba-7e68fa65f9ea
# ╠═506a18ff-a4c5-47c1-9efc-63d6bc728e46
# ╠═2fbe76cf-5504-47c9-9048-c132c1e348ee
# ╠═f44122ca-320e-46d3-9e9c-a13a09bdabd7
# ╠═88bdfe5a-5add-4c39-9c45-6b7259786354
# ╠═d429ee6d-6b46-4267-9b68-b452578d5499
# ╠═adaa2bd1-8053-4304-b9f8-e912a120451e
# ╠═53ae109b-4bad-4bf7-ac63-3bebf6fb238b
# ╠═8d017473-03fa-42a6-a13f-144722673bb6
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
