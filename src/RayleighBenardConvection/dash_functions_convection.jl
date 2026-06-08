using DelimitedFiles

make_geometry_parameters() = nothing

"""
    Nu = compute_nusselt(data2D, z)

Compute the Nusselt number from a 2D temperature field.

`data2D[iz, ix]` is temperature in °C, `iz=1` is the bottom boundary and
`iz=end` is the top boundary.  `z` is the 1-D coordinate vector (km),
running from −H (bottom) to 0 (top).

Nu = 1 for pure conduction; Nu > 1 indicates convective heat transport.
"""
function compute_nusselt(data2D, z)
    nz, nx = size(data2D)

    T_top = data2D[end, :]   # top boundary (z = 0)
    T_bot = data2D[1,   :]   # bottom boundary (z = -H)

    mean_T_top = sum(T_top) / nx
    mean_T_bot = sum(T_bot) / nx
    ΔT_actual  = mean_T_top - mean_T_bot   # negative (hot bottom, cold top)

    abs(ΔT_actual) < 1e-10 && return NaN

    # dT/dz at the top boundary [°C / km]
    Δz = z[end] - z[end-1]                                       # > 0
    dT_dz_top = (data2D[end, :] .- data2D[end-1, :]) ./ Δz      # < 0
    mean_dT_dz = sum(dT_dz_top) / nx

    H = z[end] - z[1]   # domain height, positive [km]

    # Nu = H * mean(∂T/∂z|_top) / (T_top - T_bot)
    # Both numerator and denominator are negative → Nu > 0.
    # For pure conduction: ∂T/∂z = -ΔT/H → Nu = 1.
    return H * mean_dT_dz / ΔT_actual
end

"""
    nu, Ra = compute_nu_ra(data; α=3e-5, κ=8.7e-7)

Compute the Nusselt and Rayleigh numbers from a single LaMEM `CartData`
object (as returned by `read_LaMEM_timestep`).

ρ and η are read directly from the `density` and `visc_total` output fields;
ΔT and d are derived from the temperature field and domain coordinates.
Only the thermal expansion coefficient α [1/K] and the thermal diffusivity
κ [m²/s] must be assumed (exercise-sheet defaults: α = 3×10⁻⁵ K⁻¹,
κ = k/(ρ cₚ) = 3/(3300·1050) ≈ 8.7×10⁻⁷ m²/s).

g = 9.81 m/s² is read from the simulation setup.
"""
function compute_nu_ra(data; α=3e-5, κ=8.7e-7, g=9.81)
    T    = data.fields.temperature[:, 1, :]'   # [nz, nx], °C
    z    = data.z.val[1, 1, :]                 # z coordinates, km (bottom → top)

    nu = compute_nusselt(T, z)

    # ΔT from actual boundary temperatures
    nx   = size(T, 2)
    ΔT   = sum(T[1, :]) / nx - sum(T[end, :]) / nx   # T_bot − T_top [K]
    ΔT  <= 0 && return nu, 0.0

    # Domain height (km → m)
    d = (z[end] - z[1]) * 1e3

    # Representative density: spatial mean [kg/m³]
    rho  = data.fields.density[:, 1, :]'
    ρ    = sum(rho) / length(rho)

    # Representative viscosity: geometric mean via log-space average [Pa·s]
    # visc_total is stored as log₁₀(Pa·s) in LaMEM output
    visc = data.fields.visc_total[:, 1, :]'
    η    = 10^(sum(visc) / length(visc))

    Ra = ρ * g * α * ΔT * d^3 / (η * κ)
    return nu, Ra
end

"""
    fig = create_nu_ra_figure(store_data, n_timesteps)

Build a Plotly figure that shows the Nusselt number vs time and annotates
the Rayleigh number.  `store_data` is the Dict stored in `nu_ra_store`;
`n_timesteps` is used to fix the x-axis upper bound.
"""
function create_nu_ra_figure(store_data, n_timesteps)
    ts      = store_data["timesteps"]
    times   = store_data["times"]
    nu_vals = store_data["nu"]
    ra      = store_data["ra"]

    ra_str = ra > 0 ? "Ra = $(round(ra, sigdigits=3))" : "Ra = --"

    base_layout = (
        title     = attr(text="Nu vs Time  |  $ra_str", font=attr(size=13)),
        xaxis     = attr(title="Time [Myrs]", range=[0, nothing]),
        yaxis     = attr(title="Nu", rangemode="tozero"),
        margin    = attr(t=45, b=40, l=55, r=10),
        autosize  = true,
        legend    = attr(x=0.01, y=0.99, xanchor="left", yanchor="top",
                         bgcolor="rgba(255,255,255,0.6)"),
        showlegend = true,
    )

    isempty(nu_vals) && return (data=[], layout=base_layout)

    trace_nu = scatter(
        x    = times,
        y    = nu_vals,
        mode = "lines+markers",
        name = "Nu",
        marker = attr(size=4),
        line   = attr(color="steelblue", width=2),
        customdata = ts,
        hovertemplate = "Time: %{x:.3f} Myrs<br>Timestep: %{customdata}<br>Nu: %{y:.3f}<extra></extra>",
    )

    # reference line Nu = 1 (pure conduction)
    trace_cond = scatter(
        x    = [times[1], times[end]],
        y    = [1.0, 1.0],
        mode = "lines",
        name = "Nu = 1 (conductive)",
        line = attr(color="firebrick", dash="dash", width=1),
        hoverinfo = "skip",
    )

    return (
        data   = [trace_nu, trace_cond],
        layout = base_layout,
        config = (edits = (shapePosition=true,),),
    )
end

"""
    make_nu_ra_plot(; width, height)

Return a `dbc_row` containing the Nu-vs-time graph element.
"""
function make_nu_ra_plot(; width="80vw", height="22vh")
    return dbc_row([
        dcc_graph(
            id     = "figure_nu_ra",
            figure = (data=[], layout=(title="Nu vs Time  |  Ra = --",
                                       autosize=true,
                                       margin=attr(t=45, b=40, l=55, r=10))),
            style  = attr(width=width, height=height),
        )
    ])
end


"""
    create_temp_profile_figure(data2D, z)

Build a Plotly figure of the horizontally averaged temperature profile.
`data2D[iz, ix]` is temperature in °C; `z` is the depth coordinate vector [km].
"""
function create_temp_profile_figure(data2D, z)
    nx     = size(data2D, 2)
    T_mean = vec(sum(data2D, dims=2)) ./ nx

    trace = scatter(
        x    = T_mean,
        y    = z,
        mode = "lines",
        line = attr(color="steelblue", width=2),
        hovertemplate = "T: %{x:.1f} °C<br>z: %{y:.1f} km<extra></extra>",
        showlegend = false,
    )

    return (
        data   = [trace],
        layout = (
            title    = attr(text="Mean Temperature Profile", font=attr(size=13)),
            xaxis    = attr(title="Temperature [°C]"),
            yaxis    = attr(title="Depth [km]"),
            margin   = attr(t=45, b=40, l=55, r=10),
            autosize = true,
        ),
        config = (edits = (shapePosition=true,),),
    )
end

"""
    make_temp_profile_plot(; width, height)

Return a `dbc_row` containing the mean-T-profile graph element.
"""
function make_temp_profile_plot(; width="80vw", height="30vh")
    return dbc_row([
        dcc_graph(
            id     = "figure_temp_profile",
            figure = (data=[], layout=(title="Mean Temperature Profile",
                                       autosize=true,
                                       margin=attr(t=45, b=40, l=55, r=10))),
            style  = attr(width=width, height=height),
        )
    ])
end

"""
    make_extra_plot_controls()

Card with toggle switches for the diagnostic plots below the main figure.
"""
function make_extra_plot_controls()
    return dbc_row([
        html_p(),
        dbc_card([
            dbc_label("Diagnostic plots:", size="sm"),
            dbc_checklist(
                options = ["Nu/Ra over time", "Mean T(z) profile"],
                value   = ["Nu/Ra over time"],
                id      = "switch-extra-plots",
                switch  = true,
            ),
        ],
        color      = "secondary",
        class_name = "mx-auto col-11",
        outline    = true),
        html_p(),
    ])
end

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
        make_accordion_item("ΔT:", "ΔT", "Temperature difference between the base and the top.", 2000.0, 1.0-10, 4_000.0),
        dbc_row(html_p()),
        make_accordion_item("η=η₀exp(-γ(T-½ΔT)), γ:", "γ", "Parameter for Frank-Kamenetzky viscosity (0.0 ≤ γ ≤ 0.1)", 0.001, 0.0, 0.1),
        dbc_row(html_p()),
        make_accordion_item("Yield stress (MPa):", "cohesion", "Maximum stress allowed in the model (0 ≤ Yield stress ≤ 1000) [MPa].", 500.0, 0.0, 1000.0),
        dbc_row(html_p()),
        make_accordion_item("η₀ (log₁₀(Pa⋅s)):", "viscosity", "Logarithm of the viscosity of the matrix at ΔT/2 (15 < η ≤ 25).", 21.0, 15.0, 25.0),
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
    Grid = read_LaMEM_inputfile(ParamFile, args=args)
    Phases = zeros(Int64, size(Grid.X))
    Temp = [ΔT / 2 + rand()*ampl_noise for _ in axes(Grid.X,1), _ in axes(Grid.X,2), _ in axes(Grid.X,3)]
    Phases[Grid.Z.>0.0] .= 1
    Temp[Grid.Z.>0.0] .= 0.0

    Model3D = CartData(Grid, (Phases=Phases, Temp=Temp))   # Create LaMEM model
    write_paraview(Model3D, "LaMEM_ModelSetup", verbose=false)   # Save model to paraview (load with opening LaMEM_ModelSetup.vts in paraview)  

    save_LaMEM_markers_parallel(Model3D, directory="./markers", verbose=false)   # save markers on one core

    return nothing
end

