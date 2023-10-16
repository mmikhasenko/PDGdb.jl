# PDGdb.jl

A Julia module for interacting with the Particle Data Group (PDG) SQLite database. `PDGdb.jl` provides a convenient interface to load and query entire particle physics data stored in the PDG database, which includes particle properties, decay modes, and more.

## About the PDG Database

The PDG database is a compilation of five databases stored in SQLite format. The structure is as follows:

| Table Name   | Number of Rows | Number of Columns |
|--------------|----------------|-------------------|
| pdgdoc       | 62            | 7                 |
| pdginfo      | 9             | 3                 |
| pdgid        | 19404         | 10                |
| pdgparticle  | 1233          | 15                |
| pdgdata      | 17655         | 18                |

## Purpose

The package is designed to offer tools for exploring the intricacies and complications inherent to the PDG databases:

- **Handling Hadronic Resonances**: Hadronic resonances within isospin multiplets correspond to the same `pdgid`. For instance, "Delta(1700)0", "Delta(1700)+", and "Delta(1700)++" all share the `pdgid="B010"`. This design choice stems from the similarities in the parameters of these resonances. However, it means that distinct state information is not directly accessible.
  
- **Weakly decaying particles**: Most hadronic ground states are categorized into separate nodes. Nevertheless, some states, like `Sigma_c()0`, `Sigma_c()+`, and `Sigma_c()0++`, are merged. The decision to merge is influenced by their strong decay characteristics.

The overarching goal of `PDGdb.jl` is to facilitate efficient data manipulation, assisting users in exploring the database's wealth of information. Once the desired node is identified, users can leverage the provided functions to extract specific values and insights.

## Utilities

- **Particle Search**: Use `pdg(guess_for_particle_name)` to look up particles based on a name or guess.
  
- **Retrieve Particle Properties**: `properties(pdgid)` fetches data about all properties of a particle, including its parameters and decay modes. You can also use `properties(pdg(guess_name))`.
  
- **Narrow Down Information**:
  - `parameters(properties)`: Selects particle parameters.
  - `decays(properties)`: Selects decay modes.
  - `mass`, `width`, `lifetime`, and `pole`: Retrieve specific properties of a particle.
  
- **Extract Values**: Once you've identified the node you're interested in, use:
  - `pick`: Extracts a specific value from the data.
  - `summarize`: Provides a comprehensive summary of the data.


## **Preparations**

1. Install `PDGdb.jl`

```julia
julia> ] # for Pkg mode
julia> add https://github.com/mmikhasenko/PDGdb.jl
julia> # (backspace)
julia> using PDGdb.jl
julia> PDGdb.connect(path2file)
```

2. **Download the PDG database**

The database is available from the [API page](https://pdg.lbl.gov/2023/api/index.html).


## Basic Usage

1. **Connect to the database**:
   ```julia
   using PDGdb
   PDGdb.connect("path_to_database/pdg-2023-v0.0.5.sqlite")
   ```

2. **Retrieve particle data**:

Use `PDGdb.pdg(name)` to search in `pdgparticle`, followed by `properties` to connect with `pdgdata`.

Here is how one checks all registered parameters of a particle:
```julia
julia> pi1_parameters = PDGdb.pdg("pi_1") |> properties |> parameters
pi1_parameters |> summarize

Pair{String}[
 "pi(1)(1600) T-Matrix Pole sqrt(s)(E)" => missing,
 "pi(1)(1600) MASS(AC)" => 1661.0 ± 15.0,
 "pi(1)(1600) WIDTH(AC)" => 240.0 ± 54.0]
```

We can select mass values only,
```julia
julia> rho_masses = properties(pdg("rho(770)+")) |> parameters |> mass
julia> rho_masses |> summarize

Pair{String, Measurements.Measurement{Float64}}[
    "NEUTRAL ONLY, e+ e-(AC)" => 775.26 ± 0.23,
    "CHARGED ONLY, tau DECAYS and --> e+ e-(AC)" => 775.11 ± 0.34,
    "MIXED CHARGES, OTHER REACTIONS(AC)" => 763.0 ± 1.2,
    "CHARGED ONLY, HADROPRODUCED(AC)" => 766.5 ± 1.1,
    "NEUTRAL ONLY, PHOTOPRODUCED(AC)" => 769.22 ± 0.95,
    "NEUTRAL ONLY, OTHER REACTIONS(AC)" => 769.01 ± 0.85]
```

The line,
```julia
julia> properties(pdg("pi(1800)+")) |> decays
```
gives the data frame of all decay channels measured.
