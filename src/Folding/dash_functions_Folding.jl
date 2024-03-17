using DelimitedFiles


"""
Returns an accordion menu containing the rheological parameters.
"""
function make_rheological_parameters()
    return dbc_accordionitem(title="Rheological Parameters", [
        make_accordion_item("log₁₀(η_fold [Pa⋅s]):", "viscosity_fold", "Logarithm of the viscosity of the slab.", 22.0, 16.0, 25.0),
        dbc_row(html_p()),
        make_accordion_item("(log₁₀(η_matrix [Pa⋅s]):", "viscosity_matrix", "Logarithm of the viscosity of the mantle", 20.0, 16.0, 23.0),
        dbc_row(html_p()),
    ])
end

"""
Returns an accordion menu containing the rheological parameters.
"""
function make_geometry_parameters()
    return dbc_accordionitem(title="Fold Geometry", [
        make_accordion_item("# layers:", "nlayers", "Number of layers. Must be an integer greater/equal than 1", 1, 1),
        dbc_row(html_p()),
        make_accordion_item("Thickness layers [m]:", "ThicknessLayers", "Thickness of each of the layers", 10.0, 1.0),
        dbc_row(html_p()),
        make_accordion_item("Spacing layers [m]:", "SpacingLayers", "Distance between center layers", 20.0, 1.0),
        dbc_row(html_p()),
        make_accordion_item("Amplitude noise [m]:", "A0_rand", "Amplitude of the random noise on the layer interface [m]", 0.1, 0.0),
        dbc_row(html_p()),
        make_accordion_item("Amplitude sin [m]:", "A0_sin", "Amplitude of the sinusoidal perturbation on the layer interface [m]", 0.0, 0.0),
        dbc_row(html_p()),
        
        ])
end

"""
Returns an accordion menu containing the simulation parameters.
"""
function make_simulation_parameters()
    return dbc_accordionitem(title="Simulation Parameters", [
        make_accordion_item("Thickness (m):", "thickness", "Model Thickness [m]", 100.0, 10.0),
        dbc_row(html_p()),
        make_accordion_item("Width (m):", "width", "Model Width [m]", 100.0, 10.0),
        dbc_row(html_p()),
        make_accordion_item("nx:", "nel_x", "Number of elements in the x-direction. Must be an integer greater than 2.", 64, 2),
        dbc_row(html_p()),
        make_accordion_item("nz:", "nel_z", "Number of elements in the z-direction. Must be an integer greater than 2.", 128, 2),
        dbc_row(html_p()),
        
        make_accordion_item("nt:", "n_timesteps", "Maximum number of timesteps. Must be an integer greater than 1.", 50, 1),
        dbc_row(html_p()),
    ])
end
