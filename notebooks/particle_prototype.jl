### A Pluto.jl notebook ###
# v0.19.30

using Markdown
using InteractiveUtils

# ╔═╡ 322b5020-74eb-11ee-0864-6fa3b8629056
begin
	import Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	Pkg.instantiate()
	
	using PDGdb
	using DataFrames
	using DataFramesMeta
end

# ╔═╡ 1a48c02f-c7fa-47f5-8c9e-c24ea3e96be8
begin
	const db_path = joinpath(@__DIR__, "pdg-2023-v0.0.5.sqlite")
	if !(isfile(db_path))
		db_url = "https://pdg.lbl.gov/2023/api/pdg-2023-v0.0.5.sqlite"
		download(db_url, db_path)
	end
	PDGdb.connect(db_path)
end

# ╔═╡ 4ce5e4c4-5e54-43b8-9d68-07eb2267460a
pdg("D_1")

# ╔═╡ 72c7b1dc-2b98-4e27-89e6-5db8156fd2b9
pdg("pi_1()0")

# ╔═╡ cf83a5ab-65dd-4658-a116-6483083c5982
begin
	struct Particle
		name::String
		charge::Int
		class::String
		id::DataFrame
		properties::DataFrame
	end
	
	function Particle(name::String)
		record_by_name = pdg(name)
		pdgid = record_by_name.pdgid[1]
		charge = record_by_name.charge[1]
		if ismissing(charge)
			@info "No charge"
			record_by_name.charge_type[1] == "G" && @info "Only generic node"
			charge = 0
		end
		id = @subset PDGdb.unique_particles :pdgid .== pdgid
		props = properties(pdgid)

		Particle(name, 0, "Light Meson", id, props)
	end

	Base.show(io::IO, p::Particle) = print(io, p.name, "\n", p.class, "")
end

# ╔═╡ 5b5139f4-20de-4849-9c96-846efccde236
Particle("rho(770)+").id

# ╔═╡ 8fdc002e-142d-4e66-9fb4-aac3eeca07e1
md"""
## Can I exclude :charge_type != "B" and "C" ?
"""

# ╔═╡ de93bf3c-91e7-478f-a40f-71d44ec1e4f1
map((@chain PDGdb.unique_particles begin
	@subset :charge_type .== "C"
end).name) do x
	x[end-1:end]
end |> Set

# ╔═╡ eab67fc8-2cfa-4d34-bead-63819a03984d
@chain PDGdb.unique_particles begin
	@subset :charge_type .== "C"
end

# ╔═╡ b10b73e4-3863-4207-bb98-5c93c4d1d7ec
Set(PDGdb.unique_particles.pdgid) |> length

# ╔═╡ 6aba3fb9-032c-41c7-b142-84804e6569b6
unique_resonances = @chain PDGdb.unique_particles begin
	@subset :name .!= "graviton"
	@subset :name .!== "W+"
	@subset :name .!== "W-"
	@subset :name .!== "gamma"
	@subset :name .!== "g"
	# 
	@subset :pdgid .!== "S003" # e
	@subset :pdgid .!== "S004" # mu
	@subset :pdgid .!== "S035" # tau
	# 
	@subset :pdgid .!== "S066" # nu & nubar
	@subset :pdgid .!== "S126" # higgs
	# 
	@rsubset :pdgid[1] !== 'Q' # quarks
	# 
	# 
	# 
	@subset :charge_type .!= "B"
	@subset :charge_type .!= "C" # miss Z_c(3900)
	# @subset :charge_type .!= "C" # miss Z_c(3900)
	# 
	# Now, I can drop extra items (5-8 records for pdgid, [1,2,2,1], respectively)
	# @subset :charge_type .!= "G" # drop large number of states
end

# ╔═╡ adf3743a-2f2b-473a-b0f8-3565f83f6a7e
# map(unique_resonances.name) do x
# 	x[end]
# end |> Set

# ╔═╡ b21e7904-2367-4aa7-82ff-c9986834f151
@chain unique_resonances begin
	@by :pdgid begin
		:n = length(:name)
		:joined = join(:name, " | ")
	end
	@by :n begin
		:N = length(:n)
		# :joint_pdgid = joint
	end
end

# ╔═╡ 97333e7e-30f2-4c7d-b2f0-af0daf623898
vcat(pdg("K_1(1400)+"), pdg("K(1400)+"))

# ╔═╡ 27922603-209c-4f75-8265-7fb8fabf5050
@subset unique_resonances :pdgid .== "M059"

# ╔═╡ 013a8281-f252-4993-9635-aa8aabe918af
PDGdb.legend

# ╔═╡ 38f8c02b-32d7-43c9-80eb-a19f3d48bccb
(@subset unique_resonances :cc_type .== "P").pdgid |> Set |> length

# ╔═╡ 82a7dbd4-9ba6-4e22-9635-8c78ebf3614f
unique_resonances.pdgid |> Set |> length

# ╔═╡ 055f886e-da73-412c-bd73-3d0444cdbe8f
(@rsubset unique_resonances !ismissing(:cc_type)).pdgid |> Set |> length

# ╔═╡ 1a209e10-cc28-49fe-a964-064029d27330
setdiff(
	unique_resonances.pdgid |> Set,
	(@rsubset unique_resonances !ismissing(:cc_type)).pdgid |> Set
)

# ╔═╡ 4b8d4cf3-f041-41fe-9760-9dabc34bb6c0
PDGdb.legend

# ╔═╡ a5f1c23c-854c-467c-8a64-2858dc9710e2
@chain unique_resonances begin
	@rsubset !(:name[end] ∈ ['+', '-', '0'])
	@rsubset :charge_type !== "G"
	@rsubset :charge_type !== "E"
end

# ╔═╡ 0fa9d7d0-b2ca-416a-96e3-ebd47f6760d6
unique_resonances.pdgid |> Set |> length

# ╔═╡ 7e122aee-fa1b-4c61-b7b9-eaac5738ceff
unique_particles_no_BC = 
	@chain PDGdb.unique_particles begin
		@subset :charge_type .!= "B"
		@subset :charge_type .!= "C"
	end

# ╔═╡ 4b5fc2d5-ffb8-44cf-ac6d-2d6fbe980678
setdiff(
	PDGdb.unique_particles.pdgid |> Set,
	unique_particles_no_BC.pdgid |> Set)

# ╔═╡ 54bfc5f4-1edc-48c6-bc68-ee0535ee9992
properties("M210")

# ╔═╡ 856a93b7-02b2-4095-9089-a7acb194b45f
md"""
## Improvements of the database

1. Remove generic particles, add missing
2. Remove B and C, add missing
3. 

"""

# ╔═╡ 2983bd33-c9e3-470a-aa3b-511db50e1608
 pdg("Z(3900)")

# ╔═╡ b37c39e2-b721-4ac1-bfda-43cd43293d35
@chain PDGdb.unique_particles begin
	@rsubset contains(:name, "nu")
end

# ╔═╡ c6e86dfe-6213-4c46-b70d-b8e06b2a313d
md"""
Scenarious:
 - Multiplet - generic PDGID
 - State - charge specific PDGID
"""

# ╔═╡ 338e083f-17ea-4fdf-92d8-45aeabc9ba86
PDGdb.legend

# ╔═╡ f57c7a33-cbcb-4ccb-b37f-94c294053a4f
Set(PDGdb.pdgparticle.pdgid) |>length

# ╔═╡ 58b8e48b-b01c-4f19-956f-d80881e06a73
@chain PDGdb.pdgparticle begin
	@subset :entry_type .== "P"
	@subset :pdgid .!== "G"
end

# ╔═╡ fe581092-0ff9-4884-9884-828258e746ac
PDGdb

# ╔═╡ 7a69fb7b-1481-4cc5-b06b-146f51586d85
Particle("Xi_c(2923)+").id

# ╔═╡ 578998ca-814a-4bcd-a768-1ce79e91c2c0
pdg("Xi_c(2923)+")

# ╔═╡ a4546673-ee96-4a43-840a-f9a00a2ee768
function similarities_token_based(user_input::String)
	keys = PDGdb.all_particles_names
	# 
    user_tokens = PDGdb.tokenize(user_input)
    similarities = [(key, PDGdb.jaccard_similarity(user_tokens, PDGdb.tokenize(key))) for key in keys]

    sort!(similarities, by=x -> x[2], rev=true)

    return similarities
end

# ╔═╡ 22413aca-0ad2-42f7-b54c-c56c320fdb0a
similarities_token_based("rho(770)+")[1:5]

# ╔═╡ 5ca4ed65-fe89-4b73-9475-e04b5211d202
similarities_token_based("Xi_c(2923)+")[1:5]

# ╔═╡ aec854e6-3e46-4e7c-9e35-0468b0dce6eb
PDGdb.tokenize.(PDGdb.all_particles_names[1:10])

# ╔═╡ e1816df6-d692-4548-95bd-56954ee1b9e8
let
	df = DataFrame(name = PDGdb.all_particles_names)
	x = @chain df begin
		# @transform :f1 = first.(:name)
		@transform :f1 = :name .|> PDGdb.tokenize .|> first
		@by :f1 begin
			:n = length(:name)
			:allnames = join(:name, "|")
		end
		# @rsubset contains(string(:f1), r"[^udstWHlgmn]")
	end
	# unique(x.f1)
end

# ╔═╡ 6ea86ea5-706c-4beb-87ee-3ee6aaf76feb
pdg("n")

# ╔═╡ b1500394-f2b8-4a89-9eff-2c8b9e948cee
function split_and_keep(input_string, regex)
    tokens = []
    last_idx = 1
    for match in eachmatch(regex, input_string)
        push!(tokens, input_string[last_idx:match.offset-1])
        push!(tokens, match.match)
        last_idx = match.offset + length(match) + 1
    end
    push!(tokens, input_string[last_idx:end])
    return tokens
end

# ╔═╡ 04ceab26-2959-4c9c-b1bf-3bc4f5b6e9f1
split_and_keep("Xi_c(33293)+", r"[^A-Za-z0-9+-\_]")

# ╔═╡ 30d83b2c-9043-418c-be93-117ea2b23d4f
split_and_keep("J//__p_si", r"[^A-Za-z0-9+/\-_]")

# ╔═╡ Cell order:
# ╠═322b5020-74eb-11ee-0864-6fa3b8629056
# ╠═1a48c02f-c7fa-47f5-8c9e-c24ea3e96be8
# ╠═4ce5e4c4-5e54-43b8-9d68-07eb2267460a
# ╠═72c7b1dc-2b98-4e27-89e6-5db8156fd2b9
# ╠═cf83a5ab-65dd-4658-a116-6483083c5982
# ╠═5b5139f4-20de-4849-9c96-846efccde236
# ╠═8fdc002e-142d-4e66-9fb4-aac3eeca07e1
# ╠═de93bf3c-91e7-478f-a40f-71d44ec1e4f1
# ╠═eab67fc8-2cfa-4d34-bead-63819a03984d
# ╠═b10b73e4-3863-4207-bb98-5c93c4d1d7ec
# ╠═6aba3fb9-032c-41c7-b142-84804e6569b6
# ╠═adf3743a-2f2b-473a-b0f8-3565f83f6a7e
# ╠═b21e7904-2367-4aa7-82ff-c9986834f151
# ╠═97333e7e-30f2-4c7d-b2f0-af0daf623898
# ╠═27922603-209c-4f75-8265-7fb8fabf5050
# ╠═013a8281-f252-4993-9635-aa8aabe918af
# ╠═38f8c02b-32d7-43c9-80eb-a19f3d48bccb
# ╠═82a7dbd4-9ba6-4e22-9635-8c78ebf3614f
# ╠═055f886e-da73-412c-bd73-3d0444cdbe8f
# ╠═1a209e10-cc28-49fe-a964-064029d27330
# ╠═4b8d4cf3-f041-41fe-9760-9dabc34bb6c0
# ╠═a5f1c23c-854c-467c-8a64-2858dc9710e2
# ╠═0fa9d7d0-b2ca-416a-96e3-ebd47f6760d6
# ╠═7e122aee-fa1b-4c61-b7b9-eaac5738ceff
# ╠═4b5fc2d5-ffb8-44cf-ac6d-2d6fbe980678
# ╠═54bfc5f4-1edc-48c6-bc68-ee0535ee9992
# ╠═856a93b7-02b2-4095-9089-a7acb194b45f
# ╠═2983bd33-c9e3-470a-aa3b-511db50e1608
# ╠═b37c39e2-b721-4ac1-bfda-43cd43293d35
# ╟─c6e86dfe-6213-4c46-b70d-b8e06b2a313d
# ╠═338e083f-17ea-4fdf-92d8-45aeabc9ba86
# ╠═f57c7a33-cbcb-4ccb-b37f-94c294053a4f
# ╠═58b8e48b-b01c-4f19-956f-d80881e06a73
# ╠═fe581092-0ff9-4884-9884-828258e746ac
# ╠═7a69fb7b-1481-4cc5-b06b-146f51586d85
# ╠═578998ca-814a-4bcd-a768-1ce79e91c2c0
# ╠═a4546673-ee96-4a43-840a-f9a00a2ee768
# ╠═22413aca-0ad2-42f7-b54c-c56c320fdb0a
# ╠═5ca4ed65-fe89-4b73-9475-e04b5211d202
# ╠═aec854e6-3e46-4e7c-9e35-0468b0dce6eb
# ╠═e1816df6-d692-4548-95bd-56954ee1b9e8
# ╠═6ea86ea5-706c-4beb-87ee-3ee6aaf76feb
# ╠═04ceab26-2959-4c9c-b1bf-3bc4f5b6e9f1
# ╠═30d83b2c-9043-418c-be93-117ea2b23d4f
# ╠═b1500394-f2b8-4a89-9eff-2c8b9e948cee
