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
# ╠═╡ show_logs = false
begin
	const db_path = joinpath(@__DIR__, "pdg-2023-v0.0.5.sqlite")
	if !(isfile(db_path))
		db_url = "https://pdg.lbl.gov/2023/api/pdg-2023-v0.0.5.sqlite"
		download(db_url, db_path)
	end
	PDGdb.connect(db_path)
end ;

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
# ╠═cf83a5ab-65dd-4658-a116-6483083c5982
# ╠═5b5139f4-20de-4849-9c96-846efccde236
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
