using DelimitedFiles


"""
Returns an accordion menu containing the simulation parameters.
"""
function make_simulation_parameters()
    return dbc_accordionitem(title="Simulation Parameters", [
        make_accordion_item("Width (km):", "domain_width", "Width of the domain, given in kilometers.", 2000.0, 1.0e-10),
        dbc_row(html_p()),
        make_accordion_item("Height (km):", "domain_height", "Height of the domain, given in kilometers.", 1000.0, 1.0e-10),
        dbc_row(html_p()),
        make_accordion_item("nx:", "nel_x", "Number of elements in the x-direction. Must be an integer greater than 2.", 128, 2),
        dbc_row(html_p()),
        make_accordion_item("nz:", "nel_z", "Number of elements in the z-direction. Must be an integer greater than 2.", 64, 2),
        dbc_row(html_p()),
        make_accordion_item("nt:", "n_timesteps", "Maximum number of timesteps. Must be an integer greater than 1.", 250, 1),
    ])
end

"""
Returns an accordion menu containing the rheological parameters.
"""
function make_rheological_parameters()
    return dbc_accordionitem(title="Rheological Parameters", [
        make_accordion_item("ΔT:", "ΔT", "Temperature difference between the base and the top.", 2000.0, 1.0-10, 10_000.0),
        dbc_row(html_p()),
        make_accordion_item("η=η₀exp(-γT), γ:", "γ", "Parameter for Frank-Kamenetzky viscosity (0.0 ≤ γ ≤ 1.0)", 0.001, 0.0, 1.0),
        dbc_row(html_p()),
        make_accordion_item("Cohesion (MPa):", "cohesion", "Logarithm of the cohesion of the model (0 ≤ cohesion ≤ 10_000) [MPa].", 500.0, 0.0, 10_000.0),
        dbc_row(html_p()),
        make_accordion_item("η (log₁₀(Pa⋅s)):", "viscosity", "Logarithm of the viscosity of the matrix (15 < η ≤ 25).", 21.0, 15.0, 25.0),
        dbc_row(html_p()),
        dbc_row([
            dbc_checklist(options=["FreeSurf"],
                    id="switch-FreeSurf",
                    switch=true,
            )
        ]),
    ])
end

"""
Creates a setup with noisy temperature and one phase
"""
function CreateSetup(ParamFile, ΔT=1000, ampl_noise=100; args)
    Grid = ReadLaMEM_InputFile(ParamFile, args=args)
    Phases = zeros(Int64, size(Grid.X))
    Temp = [ΔT / 2 + rand()*ampl_noise for _ in axes(Grid.X,1), _ in axes(Grid.X,2), _ in axes(Grid.X,3)]
    Phases[Grid.Z.>0.0] .= 1
    Temp[Grid.Z.>0.0] .= 0.0

    Model3D = CartData(Grid, (Phases=Phases, Temp=Temp))   # Create LaMEM model
    Write_Paraview(Model3D, "LaMEM_ModelSetup", verbose=false)   # Save model to paraview (load with opening LaMEM_ModelSetup.vts in paraview)  

    Save_LaMEMMarkersParallel(Model3D, directory="./markers", verbose=false)   # save markers on one core

    return nothing
end
