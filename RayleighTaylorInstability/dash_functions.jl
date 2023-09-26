using DelimitedFiles

"""
Creates the main figure plot.
"""
function create_main_figure(
    OutFile, cur_t, 
    x=-10:10, y=-10:0, data=rand(10, 20), # heatmap plot
    x_con=-10:10, y_con=-10:0, data_con=rand(10, 20), # contour plot
    cmaps=read_colormaps() # colormaps
    ; colorscale="batlow", field="phase", add_contours=true, add_velocity=false, contour_field="phase")

    cbar_thk = 20
    
    # add heatmap
    data_plot = [
        heatmap(
            x=x,
            y=y,
            z=data,
            colorscale=cmaps[Symbol(colorscale)],
            colorbar=attr(thickness=cbar_thk, title=field)
        )
    ]
    # add contours
    if add_contours == true
        push!(
            data_plot, (
                contour(
                    x=x_con,
                    y=y_con,
                    z=data_con,
                    colorscale=cmaps[Symbol(colorscale)],
                    contours_coloring="lines",
                    line_width=2,
                    colorbar=attr(thickness=cbar_thk, title=contour_field, x=1.1, yanchor=0.5, contour_label=true),
                )
            )
        )
    end
    # add velocity
    if add_velocity == true
        arrowhead, line = calculate_quiver(OutFile, cur_t, cmaps; colorscale="batlow")
        push!(data_plot, arrowhead)
        push!(data_plot, line)
    end

    pl = (id="fig_cross",
        data=data_plot,
        # colorbar=Dict("orientation" => "v", "len" => 0.5),
        
        layout=(
            
            # width="320vw", height="320vh",
            xaxis=attr(
                title="Width (km)",
                tickfont_size=14,
                tickfont_color="rgb(100, 100, 100)",
                showgrid=false,
                # zeroline=false, 
                # automargin=true,
                # constrain="domain",
                scaleanchor="y", 
                scaleratio=1.0,
                showline=true, linewidth=2, linecolor="black", mirror=true,
            ),
            yaxis=attr(
                title="Depth (km)",
                # domain=[0,100],
                tickfont_size=14,
                tickfont_color="rgb(10, 10, 10)",
                showgrid=false,
                showline=true, linewidth=2, linecolor="black", mirror=true,
                # range=[-10,0],
                # zeroline=false,
                # scaleanchor="x", 
                # scaleratio=1.0,
                # constrain="domain",
                # constrain="range",
            ), margin=Dict([("l", 50), ("r", 50)])#), margin=Dict([("l", 350), ("r", 350)])
        ),
        config=(edits = (shapePosition=true,)), scaleratio=1.0

        
    )

    return pl
end

"""
    x, z, data = get_data(OutFile::String, tstep::Int64=0, field::String="phase")

This loads the timestep `tstep` from a LaMEM simulation with field `field`.
"""
function get_data(OutFile::String, tstep::Int64=0, field::String="phase")
    
    data,time = Read_LaMEM_timestep(OutFile, tstep)

    value = extract_data_fields(data, field)        # get field; can handle tensors & vectors as well


    fields= String.(keys(data.fields))
    fields_available = get_fields(fields)
    
    x = data.x.val[:,1,1]
    z = data.z.val[1,1,:]
    
    data2D = value[:,1,:]'

    return x, z, data2D, time[1], fields_available
end

"""
Returns the trigger callback (simplifies code).
"""
function get_trigger()

    tr = callback_context().triggered;
    trigger = []
    if !isempty(tr)
        trigger = callback_context().triggered[1]
        trigger = trigger[1]
    end
    return trigger
end

"""
Add-ons to names for vector & tensors (used in dropdown menu).
"""
function vector_tensor()
    vector = [ "_$a" for a in ["x","y","z"]]
    tensor = [ "_$(b)$(a)" for a in ["x","y","z"], b in ["x","y","z"] ][:]
    scalar = [""]
    return scalar, vector, tensor
end

"""
This extracts a LaMEM datafield and in case it is a tensor or scalar (and has _x, _z or so at the end).
"""
function extract_data_fields(data, field)

    _, vector, tensor = vector_tensor()
    if hasfield(typeof(data.fields),Symbol(field))  # scalar
        value = data.fields[Symbol(field)]  
    else                                            # vector/tensor
        extension = split(field,"_")[end]
        n         = length(extension)
        name      = field[1:end-n-1]
      
        if n==1
            id = findall(vector.=="_"*extension)[1]
        else
            id = findall(tensor.=="_"*extension)[1]
        end
        value     = data.fields[Symbol(name)][id,:,:,:] 
    end
    return value
end

"""
Returns a list with fields. In case the LaMEM field is a vector field, it adds _x, _y etc; im case of tensor, _xx, _xy etc.
"""
function get_fields(fields)

    scalar, vector, tensor = vector_tensor()

    fields_available= []
    for f in fields
        if  f=="velocity"
            add = vector
        elseif f=="strain_rate" || f=="stress"
            add = tensor
        else
            add = scalar
        end
        for a in add
            push!(fields_available, f*a)
        end
    end
    return fields_available
end

"""
Functions building up to quiver plot
"""
function extract_velocity(OutFile, cur_t)

    data, _ = Read_LaMEM_timestep(OutFile, cur_t)
    Vx     = data.fields.velocity[1,:,1,:] 
    Vz     = data.fields.velocity[3,:,1,:] 
    x_vel = data.x.val[:,1,1]
    z_vel = data.z.val[1,1,:]

    return Vx, Vz, x_vel, z_vel
end

"""
Interpolate velocities.
"""
function interpolate_velocities(x, z, Vx, Vz)

    # interpolate velocities to a quarter of original grid density
    itp_Vx = interpolate((x, z), Vx, Gridded(Linear()))
    itp_Vz = interpolate((x, z), Vz, Gridded(Linear()))

    interpolation_coords_x = LinRange(x[1], x[end], 15)
    interpolation_coords_z = LinRange(z[1], z[end], 15)

    Vx_interpolated = zeros(length(interpolation_coords_x) * length(interpolation_coords_z))
    Vz_interpolated = zeros(length(interpolation_coords_x) * length(interpolation_coords_z))

    itp_coords_x = zeros(length(interpolation_coords_x) * length(interpolation_coords_z))
    itp_coords_z = zeros(length(interpolation_coords_x) * length(interpolation_coords_z))

    itp_coords_x = repeat(interpolation_coords_x, outer=length(interpolation_coords_z))
    itp_coords_z = repeat(interpolation_coords_z, inner=length(interpolation_coords_x))

    for i in eachindex(itp_coords_x)
        Vx_interpolated[i] = itp_Vx(itp_coords_x[i], itp_coords_z[i])
        Vz_interpolated[i] = itp_Vz(itp_coords_x[i], itp_coords_z[i])
    end

    return Vx_interpolated, Vz_interpolated, itp_coords_x, itp_coords_z
end

"""
Calculate angle between two vectors.
"""
function calculate_angle(Vx_interpolated, Vz_interpolated)
    angle = zeros(size(Vx_interpolated))
    north = [1, 0]
    for i in eachindex(angle)
        angle[i] = asind((north[1] * Vx_interpolated[i] + north[2] * Vz_interpolated[i]) / (sqrt(north[1]^2 + north[2]^2) * sqrt(Vx_interpolated[i]^2 + Vz_interpolated[i]^2)))
        if isnan(angle[i]) == true
            angle[i] = 180.0
        end
        if angle[i] < 90 && angle[i] > -90 && Vz_interpolated[i] < 0
            angle[i] = 180.0 - angle[i]
        end
    end
    return angle
end

"""
Calculate quiver.
"""
function calculate_quiver(OutFile, cur_t, cmaps; colorscale="batlow")

    Vx, Vz, x, z = extract_velocity(OutFile, cur_t)
    Vx_interpolated, Vy_interpolated, interpolation_coords_x, interpolation_coords_z = interpolate_velocities(x, z, Vx, Vz)
    angle = calculate_angle(Vx_interpolated, Vy_interpolated)
    magnitude = sqrt.(Vx_interpolated .^ 2 .+ Vy_interpolated .^ 2)
    
    arrow_head = scatter(
        x=interpolation_coords_x,
        y=interpolation_coords_z,
        mode="markers",
        colorscale=cmaps[Symbol(colorscale)],
        marker=attr(size=15, color=magnitude, angle=angle, symbol="triangle-up"),
        colorbar=attr(title="Velocity", thickness=5, x=1.4),
    )

    line = scatter(
        x=interpolation_coords_x,
        y=interpolation_coords_z,
        mode="markers",
        colorscale=cmaps[Symbol(colorscale)],
        marker=attr(size=10, color=magnitude, angle=angle, symbol="line-ns", line=attr(width=2, color=magnitude)),
    )
    return arrow_head, line
end

"""
This reads colormaps and transfers them into plotly format. The colormaps are supposed to be provided in ascii text format 
"""
function read_colormaps(; dir_colormaps="../src/assets/colormaps/" , scaling=256)
    # Read all colormaps
    colormaps = NamedTuple();
    for map in readdir(dir_colormaps)
        data = readdlm(dir_colormaps*map)
        name_str = map[1:end-4]

        if contains(name_str,"reverse")
            reverse=true
            data = data[end:-1:1,:]
        else
            reverse=false
        end

        name = Symbol(name_str)

        # apply scaling
        data_rgb = Int64.(round.(data*scaling))

        # Create the format that plotly wants:
        n = size(data,1)
        fac = range(0,1,n)
        data_col = [ [fac[i], "rgb($(data_rgb[i,1]),$(data_rgb[i,2]),$(data_rgb[i,3]))"] for i=1:n]

        col = NamedTuple{(name,)}((data_col,))
        colormaps = merge(colormaps, col)
    end

    return colormaps
end

"""
Returns a row containing the title of the page.
"""
function make_title(title_app::String)
    item = dbc_row(html_h1(title_app), style=Dict("margin-top" => 0, "textAlign" => "center"))
    return item 
end 

"""
Returns a row containing the main plot.
"""
function make_plot()
    # w = 
    # h = 
    item = dbc_row([
        dcc_graph(id="figure_main",
            figure=create_main_figure(OutFile, 0),
            #animate   = false,
            # responsive=true,
            #clickData = true,
            #config = PlotConfig(displayModeBar=false, scrollZoom = false),
            style=attr(width="80vw", height="80vh"),
            # style=attr(width="80vw"),
        )
    ])
    return item
end

"""
Returns a column containing a screenshot button.
"""
function make_screenshot_button()
    item = dbc_col([
            dbc_button("Save figure", id="button-save-fig", color="secondary", size="sg", class_name="col-4")
            ], class_name="d-grid gap-2 d-md-flex justify-content-md-center")
    return item
end

"""
Returns a column containing all the media control buttons.
"""
function make_media_buttons()
    item = dbc_col([
        dbc_button(
            [
                html_i(className="bi bi-skip-backward-fill"),
            ],
            id="button-start", outline=true, color="primary", size="sg", class_name="d-flex align-items-center"),
        dbc_button(
            [
                html_i(className="bi bi-skip-start-fill"),
            ],
        id="button-back", outline=true, color="primary", size="sg", class_name="d-flex align-items-center"),
        dbc_button(
            [
                html_i(className="bi bi-play-fill"),
            ],
            id="button-play", outline=true, color="primary", size="sg", class_name="d-flex align-items-center"
        ),
        dbc_button(
            [
                html_i(className="bi bi-skip-end-fill"),
            ],
            id="button-forward", outline=true, color="primary", size="sg", class_name="d-flex align-items-center"),
        dbc_button(
            [
                html_i(className="bi bi-skip-forward-fill"),
            ], 
            id="button-last", outline=true, color="primary", size="sg", class_name="d-flex align-items-center"),
        ], class_name="d-grid gap-2 d-md-flex justify-content-md-center")
    return item
end

"""
Retunrs an empty column.
"""
function make_empty_col()
    return dbc_col([])
end

"""
Retunrs an empty row.
"""
function make_empty_row()
    return dbc_row([])
end

"""
Returns a row containing the media buttons, each one in a column.
"""
function make_plot_controls()
    item = dbc_row([
        # make_screenshot_button(),
        make_empty_col(),
        make_media_buttons(),
        make_empty_col(),
    ])
    return item
end

"""
Return a row with the id of the current user session.
"""
function make_id_label()
    item = dbc_row([dbc_label("", id="label-id", color="secondary")])
    return item
end

"""
Returns a row containing a card with time information of the simulation.
"""
function make_time_card()
    item = dbc_row([
        html_p(),
        dbc_card([
                dbc_label(" Time: 0 Myrs", id="label-time"),
                dbc_label(" Timestep: 0", id="label-timestep"
                )],
            color="secondary",
            class_name="mx-auto col-11",
            outline=true),
        html_p()])
    return item
end

"""
Retunrs a row containing a label, a tooltip and a filling box.
"""
function make_accordion_item(label::String="param", idx::String="id", msg::String="Message", value::Float64=1.0, min::Float64=1.0e-10, max::Float64=10_000.0)
    item = dbc_row([ # domain width
        dbc_col([
            dbc_label(label, id=idx*"_label", size="md"),
            dbc_tooltip(msg, target=idx*"_label")
        ]),
        dbc_col(dbc_input(id=idx, placeholder=string(value), value=value, type="number", min=min, size="md"))
    ])
    return item
end

"""
Retunrs a row containing a label, a tooltip and a filling box.
"""
function make_accordion_item(label::String="param", idx::String="id", msg::String="Message", value::Int64=2, min::Int64=2, max::Int64=10_000)
    item = dbc_row([ # domain width
        dbc_col([
            dbc_label(label, id=idx*"_label", size="md"),
            dbc_tooltip(msg, target=idx*"_label")
        ]),
        dbc_col(dbc_input(id=idx, placeholder=string(value), value=value, type="number", min=min, size="md"))
    ])
    return item
end

"""
Returns an accordion menu containing the simulation parameters.
"""
function make_simulation_parameters()
    return dbc_accordionitem(title="Simulation Parameters", [
        make_accordion_item("Width (km):", "domain_width", "Width of the domain, given in kilometers.", 10.0, 1.0e-10),
        dbc_row(html_p()),
        make_accordion_item("Depth of the interface (km):", "depth", "Depth of the interface, given in kilometers.", -2.5, -50.0),
        dbc_row(html_p()),
        make_accordion_item("nx:", "nel_x", "Number of elements in the x-direction. Must be an integer greater than 2.", 32, 2),
        dbc_row(html_p()),
        make_accordion_item("nz:", "nel_z", "Number of elements in the z-direction. Must be an integer greater than 2.", 16, 2),
        dbc_row(html_p()),
        make_accordion_item("nt:", "n_timesteps", "Maximum number of timesteps. Must be an integer greater than 1.", 50, 1),
        dbc_row(html_p()),
        dbc_row([
            dbc_checklist(options=["FreeSurf"],
                    id="switch-FreeSurf",
                    switch=true,
            )
        ]),
        dbc_row(html_p()),
        dbc_row([
            dbc_checklist(options=["Layers"],
                    id="switch-Layers",
                    switch=true,
            )
        ])
    ])
end

"""
Returns an accordion menu containing the rheological parameters.
"""
function make_rheological_parameters()
    return dbc_accordionitem(title="Rheological Parameters", [
        make_accordion_item("η_up(log₁₀(Pa⋅s)):", "viscosity_upper", "Logarithm of the viscosity of the upper layers.", 21.0, 16.0, 23.0),
        dbc_row(html_p()),
        make_accordion_item("η_lo(log₁₀(Pa⋅s)):", "viscosity_lower", "Logarithm of the viscosity of the lower layer", 20.0, 16.0, 23.0),
        dbc_row(html_p()),
        make_accordion_item("ρ_up:", "density_upper", "Density of the upper layers.", 2800.0, 2.0, 5000.0),
        dbc_row(html_p()),
        make_accordion_item("ρ_lo:", "density_lower", "Density of the lower layer.", 2200.0, 2.0, 5000.0),
    ])
end

"""
Returns an accordion menu containing the plotting parameters.
"""
function make_plotting_parameters()
    item = dbc_accordionitem(title="Plotting Parameters", [
        dbc_row([
            dbc_label("Select field to plot: ", size="md"),
            dcc_dropdown(id="plot_field", options = ["phase"], value="phase", className="col-12")
        ]),
        dbc_row(html_p()),
        dbc_row([ # color map
            dbc_col([
                dbc_label("Colormap:", id="cmap", size="md"),
                dbc_tooltip(target="cmap", "Choose the colormap of the plot")
            ]),
            dbc_col(dcc_dropdown(id="color_map_option", options = String.(keys(cmaps)), value=String.(keys(cmaps))[1]))
        ]), 
        dbc_row(html_p()),
        dbc_row(html_hr()),
        dbc_row([
            dbc_checklist(options=["Overlap plot with contour:"],
                    id="switch-contour",
                    switch=true,
            ),
            dbc_row(html_p()),
            dbc_col(dcc_dropdown(id="contour_option" ,options = ["phase"], value="phase", disabled=true))
        ]),
        dbc_row(html_p()),
        dbc_row(html_hr()),
        dbc_row([
            dbc_checklist(options=["Overlap velocity"],
                    id="switch-velocity",
                    switch=true,
            )
        ]),
    ])
    return item
end

"""
Return a row containing the menu with the simulation, rheological and plotting parameters.
"""
function make_menu()
    item = dbc_row([
        dbc_accordion(always_open=true, [
            make_simulation_parameters(),
            make_rheological_parameters(),
            make_plotting_parameters(),
        ]),
    ])
    return item
end

"""
Returns a row containing the RUN button.
"""
function make_run_button()
    item = dbc_row([
        html_p(),
        dbc_button("RUN", id="button-run", size="lg", class_name="col-11 mx-auto"),
        html_p()])
    return item
end

"""
Create a new directory named by session-id
"""
function make_new_directory(session_id)
    dirname = String(session_id)
    if isdir("simulations")
        if isdir("simulations/" * dirname) == false
            mkdir("simulations/" * dirname)
        end
    else
        mkdir("simulations")
        mkdir("simulations/" * dirname)
    end
    user_dir = "simulations/" * dirname
    return user_dir
end

"""
Creates a setup with noisy temperature and one phase
"""
function CreateSetup(ParamFile, layered_overburden=false, Hi=-5.0, ampl_noise=0.1, ; args)
    Grid        =   ReadLaMEM_InputFile(ParamFile, args=args)
    Phases      =   zeros(Int64, size(Grid.X));      
    Temp        =   zeros(Float64,size(Grid.X));  
    

    if layered_overburden
        H_layer = 0.25;
        for z_low = minimum(Grid.Z):2*H_layer:maximum(Grid.Z)
            print(z_low)
            # z_low = -z_low
            iz = findall( (Grid.Z[1,1,:] .> z_low) .&  (Grid.Z[1,1,:] .<= (z_low+H_layer) )) 
            Phases[:,:,iz] .= 1;
        end 
    end
   
    z_int       =   ones(Grid.nump_x)*Hi + rand(Grid.nump_x)*ampl_noise
    print(z_int)
    # z_int       =   -z_int
    for ix=1:Grid.nump_x, iy=1:Grid.nump_y
        iz = findall(Grid.Z[ix,iy,:] .< z_int[ix] )
        Phases[ix,iy,iz] .= 2;
    end

    # print(z_int)

    Model3D     =   CartData(Grid, (Phases=Phases,Temp=Temp))   # Create LaMEM model
    Write_Paraview(Model3D,"LaMEM_ModelSetup", verbose=false)   # Save model to paraview   (load with opening LaMEM_ModelSetup.vts in paraview)  

    Save_LaMEMMarkersParallel(Model3D, directory="./markers", verbose=false)   # save markers on one core

    return nothing
end