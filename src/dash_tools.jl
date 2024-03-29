#module Dash_tools

using DelimitedFiles
using Dash, DashBootstrapComponents
using PlotlyJS

#export create_main_figure, get_data, get_trigger, read_colormaps, active_switch, has_pvd_file,
#        make_title, make_plot, make_plot_controls, make_id_label, make_time_card, make_menu,
#        make_accordion_item, make_rheological_parameters

# various handy and reusable functions
"""
Creates the main figure plot.
"""
function create_main_figure(OutFile, cur_t, x=1:10, y=1:10, data=rand(10, 10),
                    x_con=1:10, y_con=1:10, data_con=rand(10, 10)
    ;
    colorscale="batlow", 
    field="phase", 
    add_contours=true, 
    add_velocity=false, 
    contour_field="phase",
    session_id="",
    cmaps=[])

    data_plot = [heatmap(x=x,
        y=y,
        z=data,
        colorscale=cmaps[Symbol(colorscale)],
        colorbar=attr(thickness=5, title=field, len=0.75),
        #zmin=zmin, zmax=zmax
    )
    ]
    if add_contours == true
        push!(data_plot, (
            contour(x=x_con,
            y=y_con,
            z=data_con,
            colorscale=cmaps[Symbol(colorscale)],
            contours_coloring="lines",
            line_width=2,
            colorbar=attr(thickness=5, title=contour_field, x=1.2, yanchor=0.5, len=0.75),
            #zmin=zmin, zmax=zmax
        )))
    end

    if add_velocity == true
        user_dir = simulation_directory(session_id, clean=false)

        arrowhead, line = calculate_quiver(OutFile, cur_t, cmaps; colorscale="batlow", Dir=user_dir)
        push!(data_plot, arrowhead)
        push!(data_plot, line)
    end

    layout_data = (xaxis=attr(
                        title="Width",
                        tickfont_size=14,
                        tickfont_color="rgb(100, 100, 100)",
                        scaleanchor="y", scaleratio=1,
                        autorange=false,  automargin="top",
                        range=[x[1],x[end]], 
                        showgrid=false,
                        zeroline=false
                        ),
                    yaxis=attr(
                        title="Depth",
                        tickfont_size=14,
                        tickfont_color="rgb(10, 10, 10)",
                        autorange=false, automargin="top",
                        autorangeoptions=attr(clipmax=0),
                        range=[minimum(y),maximum(y)], 
                        showgrid=false,
                        zeroline=false
                        ), 
                        margin=attr(autoexpand="true", pad=1),
                )

    # Specify size; since this does not always work you can set an autosize too (gives more white space)
    layout_data = merge(layout_data, (autosize=true,));

    # Create plot
    pl = (id="fig_cross",
        data=data_plot,
        colorbar=Dict("orientation" => "v", "len" => 0.5),
        layout=layout_data,
        config=(edits = (shapePosition=true,)),
    )
    return pl
end



"""
    x, z, data = get_data(OutFile::String, tstep::Int64=0, field::String="phase", Dir="")

This loads the timestep `tstep` from a LaMEM simulation with field `field`.
"""
function get_data(OutFile::String, tstep::Int64=0, field_units::String="phase", Dir="")
    
    field = strip_units(field_units)
    data,time = read_LaMEM_timestep(OutFile, tstep, Dir)
    
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
        value     = data.fields[Symbol(name)][id] 
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
function extract_velocity(OutFile, cur_t, Dir="")

    data, _ = read_LaMEM_timestep(OutFile, cur_t, Dir)
    Vx     = data.fields.velocity[1][:,1,:] 
    Vz     = data.fields.velocity[3][:,1,:] 
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
function calculate_quiver(OutFile, cur_t, cmaps; colorscale="batlow", Dir="")

    Vx, Vz, x, z = extract_velocity(OutFile, cur_t, Dir)
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
function read_colormaps(; dir_colormaps="" , scaling=256)
    #if isempty(dir_colormaps)
    #    dir_colormaps=joinpath(pkgdir(InteractiveGeodynamics),"src/assets/colormaps/")
    #end
    
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
function make_plot(OutFile="",cmaps=[]; width="80vw", height="80vh")
    item = dbc_row([
        dcc_graph(id="figure_main",
            figure=create_main_figure(OutFile, 0, cmaps=cmaps),
            #animate   = false,
            #responsive=false,
            #clickData = true,
            #config = PlotConfig(displayModeBar=false, scrollZoom = false),
            style=attr(width=width, height=height)
        )
    ])
    return item
end

"""
Returns a column containing all the media control buttons.
"""
function make_media_buttons()
    item = dbc_col([
        dbc_button("<<", id="button-start", outline=true, color="primary", size="sg", class_name="me-md-1 col-2"),
        dbc_button("<", id="button-back", outline=true, color="primary", size="sg", class_name="me-md-1 col-1"),
        dbc_button("Play/Pause", id="button-play", outline=true, color="primary", size="sg", class_name="me-md-1 col-3"),
        dbc_button(">", id="button-forward", outline=true, color="primary", size="sg", class_name="me-md-1 col-1"),
        dbc_button(">>", id="button-last", outline=true, color="primary", size="sg", class_name="me-md-1 col-2"),
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
        #make_screenshot_button(),
        make_empty_col(),
        make_media_buttons(),
        make_empty_col(),
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
Return a row with the id of the current user session.
"""
function make_id_label()
    item = dbc_row([dbc_label("", id="label-id")])
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
Returns a row containing a label, a tooltip and a filling box.
"""
function make_accordion_item(label::String="param", idx::String="id", msg::String="Message", value::_T=1*one(_T), low=nothing, high=nothing) where _T <: Number
    
    low  = _check_min(_T, low)
    high = _check_max(_T, high)

    item = dbc_row([ # domain width
        dbc_col([
            dbc_label(label, id=idx*"_label", size="md"),
            dbc_tooltip(msg, target=idx*"_label")
        ]),
        dbc_col(dbc_input(id=idx, placeholder=string(value), value=value, type="number", min=low, size="md"))
    ])
    return item
end


@inline _check_min(::Float64, ::Nothing) = 1e-10
@inline _check_min(::Int64, ::Nothing) = 2
@inline _check_min(::T, x) where T = x

@inline _check_max(::Float64, ::Nothing) = 10000
@inline _check_max(::Int64, ::Nothing) = 10_000
@inline _check_max(::T, x) where T = x


#=
"""
Returns a row containing a label, a tooltip and a filling box.
"""
function make_accordion_item(label::String="param", idx::String="id", msg::String="Message", value::Int64=2, mini::Int64=2, maxi::Int64=10_000)
    item = dbc_row([ # domain width
        dbc_col([
            dbc_label(label, id=idx*"_label", size="md"),
            dbc_tooltip(msg, target=idx*"_label")
        ]),
        dbc_col(dbc_input(id=idx, placeholder=string(value), value=value, type="number", min=mini, size="md"))
    ])
    return item
end
=#

"""
Returns an accordion menu containing the plotting parameters.
"""
function make_plotting_parameters(cmaps; show_field="phase")
    item = dbc_accordionitem(title="Plotting Parameters", [
        dbc_row([
            dbc_label("Select field to plot: ", size="md"),
            dcc_dropdown(id="plot_field", options = [show_field], value=show_field, className="col-12")
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
    make_menu(cmaps; show_field="phase")
Return a row containing the menu with the simulation, rheological and plotting parameters.
"""
function make_menu(cmaps; show_field="phase")
    
    if !isnothing(make_geometry_parameters())
        item = dbc_row([
            dbc_accordion(always_open=true, [
                make_simulation_parameters(),
                make_geometry_parameters(),
                make_rheological_parameters(),
                make_plotting_parameters(cmaps, show_field=show_field),
            ]),
        ])
    else
        item = dbc_row([
            dbc_accordion(always_open=true, [
                make_simulation_parameters(),
                make_rheological_parameters(),
                make_plotting_parameters(cmaps, show_field=show_field),
            ]),
        ])
    end


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
    simulation_directory(session_id; clean=true )
Create a new directory named by session-id and optionally cleans it
"""
function simulation_directory(session_id; clean=true)
    base_dir = pwd();
    dirname = String(session_id)
    if isdir("simulations")
        if isdir(joinpath("simulations" , dirname)) == false
            mkdir(joinpath("simulations" , dirname))
        end
    else
        mkdir("simulations")
        mkdir(joinpath("simulations" , dirname))
    end
    user_dir = joinpath("simulations" , dirname)

    if clean
        # clean directory
        cd(user_dir)
        clean_directory()   # removes all existing LaMEM files
        cd(base_dir)
    end

    return user_dir
end

has_pvd_file(OutFile, user_dir) = isfile(joinpath(user_dir, OutFile * ".pvd"))


"""
    active_switch = active_switch(switch)
Returns true if the switch is on
"""
function active_switch(switch)
    active_switch_val=false;
    if !isnothing(switch)
        if !isempty(switch)
            active_switch_val = true
        end
    end
    return active_switch_val
end

"""
    fields_available_units = fields_available_units
This adds units to the fields available in the LaMEM simulation
"""
function add_units(fields_available)
    fields_available_units = fields_available

    fields_available_units = replace(fields_available_units,   "visc_total"=>"visc_total [log₁₀(Pas)]", 
                                "visc_creep"=>"visc_creep [log₁₀(Pas)]",
                                "velocity_x"=>"velocity_x [cm/yr]",
                                "velocity_z"=>"velocity_z [cm/yr]",
                                "pressure"=>"pressure [MPa]",
                                "temperature"=>"temperature [°C]",
                                "j2_dev_stress"=>"j2_dev_stress [MPa]",
                                "j2_strain_rate"=>"j2_strain_rate [1/s]",
                                "density"=>"density [kg/m³]",
                                )

    return fields_available_units
end


function strip_units(fields_available_units)
    fields_available = fields_available_units

    fields_available =  replace(fields_available,   
                                "visc_total [log₁₀(Pas)]"=>"visc_total", 
                                "visc_creep [log₁₀(Pas)]"=>"visc_creep",
                                "velocity_x [cm/yr]"=>"velocity_x",
                                "velocity_z [cm/yr]"=>"velocity_z",
                                "pressure [MPa]"=>"pressure",
                                "temperature [°C]"=>"temperature",
                                "density [kg/m³]"=>"density",
                                "j2_dev_stress [MPa]"=>"j2_dev_stress",
                                "j2_strain_rate [1/s]"=>"j2_strain_rate",
                                )

    return fields_available
end

#end