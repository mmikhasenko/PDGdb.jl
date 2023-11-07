### A Pluto.jl notebook ###
# v0.19.30

using Markdown
using InteractiveUtils

# ╔═╡ 9bb01d10-711b-11ee-34da-5d786e08d8ff
begin
	import Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	Pkg.instantiate()
	
	using PDGdb
	using DataFrames
	using DataFramesMeta
end

# ╔═╡ 39ada21f-b995-402e-ba0f-5411be779bea
# ╠═╡ show_logs = false
begin
	const db_path = joinpath(@__DIR__, "pdg-2023-v0.0.5.sqlite")
	if !(isfile(db_path))
		db_url = "https://pdg.lbl.gov/2023/api/pdg-2023-v0.0.5.sqlite"
		download(db_url, db_path)
	end
	PDGdb.connect(db_path)
end

# ╔═╡ 562c3812-c683-433e-8c96-4a26ca0f862c
Gparticles = @chain PDGdb.pdgparticle begin
	@subset :entry_type .== "P"
	@subset :charge_type .== "G"
end ;

# ╔═╡ 157176be-b1d8-4fab-b74f-c8edc05a3f53
Sparticles = @chain PDGdb.pdgparticle begin
	@subset :entry_type .== "P"
	@rsubset :charge_type ∈ ["S", "E"]
end ;

# ╔═╡ e6d26613-ca1b-4df7-b0ed-e50502ed523a
notGparticles = @chain PDGdb.pdgparticle begin
	@subset :entry_type .== "P"
	@subset :charge_type .!== "G"
end;

# ╔═╡ e5cc751a-c0c9-4875-808f-96026e6fcbc0
unique_pdgid_S = unique(Sparticles.pdgid) |> sort

# ╔═╡ 14a5a237-6710-49a6-9577-b349cd3c9e2b
unique_pdgid_G = unique(Gparticles.pdgid) |> sort

# ╔═╡ b0e31aff-7490-4590-81d9-68bbe5110eed
md"""
## not G vs S & E
"""

# ╔═╡ 38b11323-978c-4b80-a556-86c28fae410f
unique_pdgid_notG = unique(notGparticles.pdgid) |> sort

# ╔═╡ 4942e415-a9e0-4c0a-8484-52d01f746647
setdiff(unique_pdgid_notG, unique_pdgid_S),
setdiff(unique_pdgid_S, unique_pdgid_notG)

# ╔═╡ 5fcae6b3-dd9c-4fd8-a037-0a877ff2ba27
@subset PDGdb.pdgparticle :pdgid .== "M210"

# ╔═╡ e044630d-cd4e-41bb-8fe0-313add0be8b4
md"""
[Issue](https://github.com/mmikhasenko/PDGdb.jl/issues/7): Here are the particles missing in the generic dataset
"""

# ╔═╡ c4de5e59-9bb9-4948-ab5c-a312c9a3799f
@chain PDGdb.pdgparticle begin
	@rsubset :pdgid ∈ setdiff(unique_pdgid_S, unique_pdgid_G)
	@by :pdgid begin
		:allnames = join(:name, " | ")
	end
end

# ╔═╡ 07e4d05f-91cd-41e1-8913-2b37e903e327
md"""
## Reduce "G" particles when not needed 
"""

# ╔═╡ 65b308f5-9ae1-43db-99a2-8e58de05544b
let ptable = PDGdb.pdgparticle
        Pparticles = subset(ptable, :entry_type => (x -> x .== "P"))
        # 
        Gparticles = subset(Pparticles, :charge_type => (x -> x .== "G"))
        notGparticles = subset(Pparticles, :charge_type => (x -> x .!== "G"))
        missing_pdgid = setdiff(Gparticles.pdgid, notGparticles.pdgid)
        missingGparticles = subset(Gparticles, :pdgid => ByRow(x -> x ∈ missing_pdgid))
        # 
     vcat(notGparticles, missingGparticles)
end

# ╔═╡ a1dcce23-c273-44ac-9ef2-1af4689b3927
md"""
## Variaty of charge types for `pdgid` 
"""

# ╔═╡ 96f4ab9a-6935-4f54-aee0-8b78a905b65a
@chain PDGdb.pdgparticle begin
	@by :pdgid begin
		:pdgid = first(:pdgid)
		:all_charge_types = join(:charge_type, " | ")
		:ifG = "G" ∈ :charge_type
		:lenC = length(:charge_type)
	end
end

# ╔═╡ a6076ebb-6c15-4b34-af84-c4721035f11b
md"""
## Missing in charge-specific set
"""

# ╔═╡ 0b796773-a5f0-4af1-b982-9476d2ede2ff
@chain PDGdb.pdgparticle begin
	@rsubset :pdgid ∈ setdiff(unique_pdgid_G, unique_pdgid_S)
	@by :pdgid begin
		:allnames = join(:name, " | ")
		:entry_types = join(:entry_type, " | ")
		:charge_types = join(:charge_type, " | ")
	end
end

# ╔═╡ 7f2ea7f9-9c13-4021-b3fb-fe03d3771e85
size(Sparticles,1), length(unique(Sparticles.name))

# ╔═╡ 263b2603-62b3-42da-a61e-5c733aa62508
md"""
## Same name different pdgid

Duplication of the name in the table of Specific particles, happens.
The only reasons for it is a mistake.
"""

# ╔═╡ 63136d67-0b15-460f-874e-ffef872c5153
@chain Sparticles begin
	@by :name begin
		:allids = join(:pdgid, " | ")
		:nnames = length(:pdgid)
	end
	@subset :nnames .> 1
end

# ╔═╡ f3c93d20-9c07-4918-a79f-1c585b0a9aab
md"""
Here is the mistake of `Xi_b` more explicitly
"""

# ╔═╡ c2472eed-6440-4c3c-8eeb-d56c927dcbf0
select((@subset Sparticles :pdgid .== "S070"), :pdgid, :name)

# ╔═╡ 100889c3-37e3-4054-9fac-bacfc9d18e9d
select(properties("S070") |> mass, :pdgid, :description)

# ╔═╡ 4c29b254-3111-4151-acdb-77c6156057db
md"""
For generic particles it happes because both charges can be referred to as the same name without charge. However, it is still not cool.
"""

# ╔═╡ e34e8fcf-6140-4c97-996b-536ac6bf024e
@chain Gparticles begin
	@by :name begin
		:allids = join(:pdgid, " | ")
		:nnames = length(:pdgid)
	end
	@subset :nnames .> 1
end

# ╔═╡ cf60d06b-eb8a-4bc9-b375-c93b67ba5600
md"""
## Duplications with Generic particles

Here I check in the table for generic particles has duplications of `pdgid`. And it does. Many of them, They are related to several reasons:

 - particle and anti-particles have the same `pdgid`. For several particles, espesially when belong to different multiplets, there are separate entries. E.g. `Kbar^*(892) | K^*(892)`
 - updated name: `eta^'() | eta^'`, `omega(782) | omega`
 - mass eigen states, `K0L | K0S | K`
"""

# ╔═╡ 5bbdfc7e-3721-464d-9d18-e098eeacc1ed
(@chain Gparticles begin
	@by :pdgid begin
		:allnames = join(:name, " | ")
		:nnames = length(:name)
	end
	@subset :nnames .> 1
end) |> sort

# ╔═╡ 75424ee7-cde9-4b1e-86f5-b0e7eb71e46a
(@chain Sparticles begin
	@by :pdgid begin
		:allnames = join(:name, " | ")
		:nnames = length(:name)
	end
	@subset :nnames .> 1
end) |> sort

# ╔═╡ Cell order:
# ╠═9bb01d10-711b-11ee-34da-5d786e08d8ff
# ╠═39ada21f-b995-402e-ba0f-5411be779bea
# ╠═562c3812-c683-433e-8c96-4a26ca0f862c
# ╠═157176be-b1d8-4fab-b74f-c8edc05a3f53
# ╠═e6d26613-ca1b-4df7-b0ed-e50502ed523a
# ╠═e5cc751a-c0c9-4875-808f-96026e6fcbc0
# ╠═14a5a237-6710-49a6-9577-b349cd3c9e2b
# ╟─b0e31aff-7490-4590-81d9-68bbe5110eed
# ╠═38b11323-978c-4b80-a556-86c28fae410f
# ╠═4942e415-a9e0-4c0a-8484-52d01f746647
# ╠═5fcae6b3-dd9c-4fd8-a037-0a877ff2ba27
# ╟─e044630d-cd4e-41bb-8fe0-313add0be8b4
# ╠═c4de5e59-9bb9-4948-ab5c-a312c9a3799f
# ╟─07e4d05f-91cd-41e1-8913-2b37e903e327
# ╠═65b308f5-9ae1-43db-99a2-8e58de05544b
# ╟─a1dcce23-c273-44ac-9ef2-1af4689b3927
# ╠═96f4ab9a-6935-4f54-aee0-8b78a905b65a
# ╟─a6076ebb-6c15-4b34-af84-c4721035f11b
# ╠═0b796773-a5f0-4af1-b982-9476d2ede2ff
# ╠═7f2ea7f9-9c13-4021-b3fb-fe03d3771e85
# ╟─263b2603-62b3-42da-a61e-5c733aa62508
# ╠═63136d67-0b15-460f-874e-ffef872c5153
# ╟─f3c93d20-9c07-4918-a79f-1c585b0a9aab
# ╠═c2472eed-6440-4c3c-8eeb-d56c927dcbf0
# ╠═100889c3-37e3-4054-9fac-bacfc9d18e9d
# ╟─4c29b254-3111-4151-acdb-77c6156057db
# ╠═e34e8fcf-6140-4c97-996b-536ac6bf024e
# ╟─cf60d06b-eb8a-4bc9-b375-c93b67ba5600
# ╠═5bbdfc7e-3721-464d-9d18-e098eeacc1ed
# ╠═75424ee7-cde9-4b1e-86f5-b0e7eb71e46a
