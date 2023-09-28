using DelimitedFiles

"""
Returns an accordion menu containing the rheological parameters.
"""
function make_rheological_parameters()
    return dbc_accordionitem(title="Rheological Parameters", [
        make_accordion_item("ρₛ (kg/m³):", "density_sphere", "Density of the sphere in kg/m³ (0 < ρₛ ≤ 10_000.0).", 3000.0, 1.0e-10),
        dbc_row(html_p()),
        make_accordion_item("ρₘ (kg/m³):", "density_matrix", "Density of the matrix in kg/m³ (0 < ρₛ ≤ 10_000.0).", 3400.0, 1.0e-10),
        dbc_row(html_p()),
        make_accordion_item("rₛ (km):", "radius_sphere", "Radius of the sphere in kilometers (0 < rₛ ≤ Lₓ).", 0.1, 1.0e-10),
        dbc_row(html_p()),
        make_accordion_item("ηₘ (log₁₀(Pa⋅s)):", "viscosity", "Logarithm of the viscosity of the matrix (15 < ηₘ ≤ 25).", 25.0, 15.0, 25.0),
    ])
end

"""
Returns an accordion menu containing the simulation parameters.
"""
function make_simulation_parameters()
    return dbc_accordionitem(title="Simulation Parameters", [
        make_accordion_item("Lₓ (km):", "domain_width", "Width of the domain, given in kilometers.", 1.0, 1.0e-10),
        dbc_row(html_p()),
        make_accordion_item("nx:", "nel_x", "Number of elements in the x-direction. Must be an integer greater than 2.", 64, 2),
        dbc_row(html_p()),
        make_accordion_item("nz:", "nel_z", "Number of elements in the z-direction. Must be an integer greater than 2.", 64, 2),
        dbc_row(html_p()),
        make_accordion_item("nt:", "n_timesteps", "Maximum number of timesteps. Must be an integer greater than 1.", 30, 1),
    ])
end

"""
Creates a setup with noisy temperature and one phase
"""
function CreateSetup(ParamFile, ΔT=1000, ampl_noise=100; args)
    Grid = ReadLaMEM_InputFile(ParamFile, args=args)
    Phases = zeros(Int64, size(Grid.X))
    Temp = ones(Float64, size(Grid.X)) * ΔT / 2
    Temp = Temp + rand(size(Temp)...) .* ampl_noise
    Phases[Grid.Z.>0.0] .= 1
    Temp[Grid.Z.>0.0] .= 0.0

    Model3D = CartData(Grid, (Phases=Phases, Temp=Temp))   # Create LaMEM model
    Write_Paraview(Model3D, "LaMEM_ModelSetup", verbose=false)   # Save model to paraview (load with opening LaMEM_ModelSetup.vts in paraview)  

    Save_LaMEMMarkersParallel(Model3D, directory="./markers", verbose=false)   # save markers on one core

    return nothing
end
