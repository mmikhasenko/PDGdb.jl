using Test
using PDGdb
using PDGdb.DataFrames
using PDGdb.Measurements

# Set up the path to your database
db_url = "https://pdg.lbl.gov/2023/api/pdg-2023-v0.0.5.sqlite"
tmp_dir = mktempdir()
const db_path = joinpath(tmp_dir, "pdg-2023-v0.0.5.sqlite")
download(db_url, joinpath(tmp_dir, "pdg-2023-v0.0.5.sqlite"))

@testset "PDGdb Tests" begin

    @testset "connect function" begin
        info_df = PDGdb.connect(db_path)
        @test isa(info_df, DataFrame)
        @test ncol(info_df) == 3  # Assuming the returned DataFrame has 3 columns
    end

    @testset "pdg function" begin
        pip_df = PDGdb.pdg("pi+")
        @test isa(pip_df, DataFrame)
        @test size(pip_df, 1) == 1  # Assuming "pi" returns exactly one row
    end

    @testset "properties function" begin
        props_df = PDGdb.properties(PDGdb.pdg("rho(770)+"))
        @test isa(props_df, DataFrame)
        # Additional tests can be added based on the expected properties of "muon"
    end

    @testset "pick function" begin
        particle_props = PDGdb.properties(PDGdb.pdg("a_1(1260)+"))
        measurement = PDGdb.pick(mass(particle_props), :value_type => "AC")
        @test isa(measurement, Measurement)
        # Additional tests can be added based on the expected measurement for "muon" mass
    end

end
