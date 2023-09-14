using Dash, DashBootstrapComponents
using PlotlyJS
using LaMEM
using UUIDs
using Interpolations

GUI_version = "0.1.0"

include("utils.jl")
cmaps = read_colormaps()

# this is the main figure window
function create_main_figure(OutFile, cur_t,x=1:10,y=1:10,data=rand(10,10), 
                            x_con=1:10,y_con=1:10,data_con=rand(10,10), cmaps=read_colormaps()
                            ; 
                            colorscale="batlow", field="phase", add_contours = true, add_velocity=false, contour_field="phase")
    data_plot = [heatmap(x = x, 
                    y = y, 
                    z = data,
                    colorscale   = cmaps[Symbol(colorscale)],
                    colorbar= attr(thickness=5, title=field),
                    #zmin=zmin, zmax=zmax
                    )
                ]
    if add_contours == true
        push!(data_plot, (
            contour(x = x_con, 
            y = y_con, 
            z = data_con,
            colorscale   = cmaps[Symbol(colorscale)],
            contours_coloring="lines",
            line_width = 2,
            colorbar= attr(thickness=5, title=contour_field, x=1.2, yanchor = 0.5),
            #zmin=zmin, zmax=zmax
            )))
    end

    if add_velocity == true
        arrowhead, line = calculate_quiver(OutFile, cur_t, cmaps; colorscale = "batlow")
        push!(data_plot, arrowhead)
        push!(data_plot, line)
    end
    

    pl = (  id = "fig_cross",
                data = data_plot,
        colorbar=Dict("orientation"=>"v", "len"=>0.5),
        layout = (  
                        xaxis=attr(
                        title="Width",
                        tickfont_size= 14,
                        tickfont_color="rgb(100, 100, 100)",
                        automargin=true, 
                        
                    ),
                    yaxis=attr(
                        title="Depth",
                        tickfont_size= 14,
                        tickfont_color="rgb(10, 10, 10)",
                        scaleanchor="x", scaleratio=1
                    ), margin = Dict([("l",350),("r",350)])
                    ),
        config = (edits    = (shapePosition =  true,)),  
    )
    return pl
end




"""
 x,z,data = get_data(OutFile::String, tstep::Int64=0, field::String="phase")
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

#returns the trigger callback (simplifies code)
function get_trigger()

    tr = callback_context().triggered;
    trigger = []
    if !isempty(tr)
        trigger = callback_context().triggered[1]
        trigger = trigger[1]
    end
    return trigger
end


#add-ons to names for vector & tensors (used in dropdown menu)
function vector_tensor()
    vector = [ "_$a" for a in ["x","y","z"]]
    tensor = [ "_$(b)$(a)" for a in ["x","y","z"], b in ["x","y","z"] ][:]
    scalar = [""]
    return scalar, vector, tensor
end


"""

This extracts a LaMEM datafield and in case it is a tensor or scalar (and has _x, _z or so at the end), 
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

# returns a list with fields. in case the LaMEM field is a vector field, it adds _x, _y etc; im case of tensor, _xx,_xy etyc
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


# functions building up to quiver plot

function extract_velocity(OutFile, cur_t)

    data, _ = Read_LaMEM_timestep(OutFile, cur_t)
    Vx     = data.fields.velocity[1,:,1,:] 
    Vz     = data.fields.velocity[3,:,1,:] 
    x_vel = data.x.val[:,1,1]
    z_vel = data.z.val[1,1,:]

    return Vx, Vz, x_vel, z_vel
end


function interpolate_velocities(x, z, Vx, Vz)

    # interpolate velocities to a quarter of original grid density
    itp_Vx = interpolate((x,z), Vx, Gridded(Linear()))
    itp_Vz = interpolate((x,z), Vz, Gridded(Linear()))

    interpolation_coords_x = LinRange(x[1], x[end], 8)
    interpolation_coords_z = LinRange(z[1], z[end], 8)

    Vx_interpolated = itp_Vx.(interpolation_coords_x, interpolation_coords_z)
    Vz_interpolated = itp_Vz.(interpolation_coords_x, interpolation_coords_z)

    return Vx_interpolated, Vz_interpolated, interpolation_coords_x, interpolation_coords_z
end

function calculate_angle(Vx_interpolated, Vz_interpolated)
    angle = zeros(size(Vx_interpolated))
    north = [1 0]
        for i in CartesianIndices(angle)
            angle[i] = acos((north[1] * Vx_interpolated[i] + north[2]* Vz_interpolated[i]) / (sqrt(north[1]^2 + north[2]^2)*sqrt(Vx_interpolated[i]^2 + Vz_interpolated[i]^2)))
        end
    return angle
end

function calculate_quiver(OutFile, cur_t, cmaps; colorscale ="batlow")

    # x,z = extract_coordinates(data)
    Vx, Vz, x, z = extract_velocity(OutFile, cur_t)
    Vx_interpolated, Vy_interpolated, interpolation_coords_x, interpolation_coords_z = interpolate_velocities(x, z, Vx, Vz)
    angle = calculate_angle(Vx_interpolated, Vy_interpolated)
    magnitude = sqrt.(Vx_interpolated.^2 .+ Vy_interpolated.^2)

    arrow_head = scatter(
                    x = interpolation_coords_x, 
                    y = interpolation_coords_z, 
                    z = magnitude,
                    mode = "markers",
                    colorscale   = cmaps[Symbol(colorscale)],
                    marker = attr(size=10, color=magnitude, angle = angle, symbol = "arrow-up", line=attr(width=2, color=magnitude)),
                    #zmin=zmin, zmax=zmax
                   )
    line       = scatter(
                    x = interpolation_coords_x, 
                    y = interpolation_coords_z, 
                    z = magnitude,
                    mode = "markers",
                    colorscale   = cmaps[Symbol(colorscale)],
                    marker = attr(size=10, color=magnitude, angle = angle, symbol = "line-ns", line=attr(width=2, color=magnitude)),
                    #zmin=zmin, zmax=zmax
                    )
    return  arrow_head, line
end

title_app = "Rising Sphere example"
ParamFile = "RisingSphere.dat"
OutFile = "RiseSphere"

#app = dash(external_stylesheets=[dbc_themes.CYBORG])
app = dash(external_stylesheets = [dbc_themes.BOOTSTRAP], prevent_initial_callbacks=false)
app.title = title_app

# Main code layout
app.layout = html_div() do
    dbc_container(className="mxy-auto", fluid=true, [
        dbc_row(html_h1(title_app), style=Dict("margin-top" => 0, "textAlign" => "center")), # title row
        dbc_row([ # data row
            dbc_col([ # graph column
                dbc_col(dcc_graph(id = "figure_main",
                    figure = create_main_figure(OutFile, 0),
                    #animate   = false,
                    #responsive=false,
                    #clickData = true,
                    #config = PlotConfig(displayModeBar=false, scrollZoom = false),
                style = attr(width="80vw", height="80vh")
                ),),
                dbc_row([
                    dbc_col([
                        dbc_button("Save figure", id="button-save-fig", color="secondary", size="sg", class_name="col-4")
                    ], class_name="d-grid gap-2 d-md-flex justify-content-md-center"),
                    dbc_col([
                        dbc_button("<<", id="button-start", outline=true, color="primary", size="sg", class_name="me-md-1 col-2"),
                        dbc_button("<", id="button-back", outline=true, color="primary", size="sg", class_name="me-md-1 col-1"),
                        dbc_button("Play/Pause", id="button-play", outline=true, color="primary", size="sg", class_name="me-md-1 col-3"),
                        dbc_button(">", id="button-forward", outline=true, color="primary", size="sg", class_name="me-md-1 col-1"),
                        dbc_button(">>", id="button-last", outline=true, color="primary", size="sg", class_name="me-md-1 col-2"),
                        ], class_name="d-grid gap-2 d-md-flex justify-content-md-center"), 
                    dbc_col([]),
                ]),
                dbc_col(dbc_label("", id="label-id"))
            ]),
            dbc_col([ # input column
                dbc_row([ # information card
                    dbc_card([
                        dbc_label(" Time: 0 Myrs", id="label-time"), 
                        dbc_label(" Timestep: 0", id="label-timestep"
                        )], 
                    color="secondary", 
                    class_name="mx-auto col-11",
                    outline=true)
                ]),
                dbc_row(html_p()),
                dbc_accordion(always_open=true, [
                    dbc_accordionitem(title="Simulation Parameters", [
                        make_accordion_item("Lₓ (km):", "domain_width", "Width of the domain, given in kilometers.", 1.0, 1.0e-10),
                        dbc_row(html_p()),
                        make_accordion_item("nx:", "nel_x", "Number of elements in the x-direction. Must be an integer greater than 2.", 32, 2),
                        dbc_row(html_p()),
                        make_accordion_item("nz:", "nel_z", "Number of elements in the z-direction. Must be an integer greater than 2.", 32, 2),
                        dbc_row(html_p()),
                        make_accordion_item("nt:", "n_timesteps", "Maximum number of timesteps. Must be an integer greater than 1.", 30, 1),
                    ]),
                    dbc_accordionitem(title="Rheological Parameters", [
                        make_accordion_item("ρₛ (kg/m³):", "density_sphere", "Density of the sphere in kg/m³ (0 < ρₛ ≤ 10_000.0).", 3000.0, 1.0e-10),
                        dbc_row(html_p()),
                        make_accordion_item("ρₘ (kg/m³):", "density_matrix", "Density of the matrix in kg/m³ (0 < ρₛ ≤ 10_000.0).", 3400.0, 1.0e-10),
                        dbc_row(html_p()),
                        make_accordion_item("rₛ (km):", "radius_sphere", "Radius of the sphere in kilometers (0 < rₛ ≤ Lₓ).", 0.1, 1.0e-10),
                        dbc_row(html_p()),
                        make_accordion_item("ηₘ (log₁₀(Pa⋅s)):", "viscosity", "Logarithm of the viscosity of the matrix (15 < ηₘ ≤ 25).", 25.0, 15.0, 25.0),
                    ]),
                    dbc_accordionitem(title="Plotting Parameters", [
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
                    ]),
                ]),
                dbc_row(html_p()),
                dbc_row(dbc_button("RUN", id="button-run", size="lg", class_name="col-11 mx-auto"))
                
            ]) 
        ]),

        # Store a unique number of our session in the webpage
        dcc_store(id="session-id", data=""),
        
        # Store info related to the simulation and current timestep
        dcc_store(id="current_timestep", data="0"),
        dcc_store(id="last_timestep", data="0"),
        dcc_store(id="update_fig", data="0"),

        # Start an interval that updates the number every second
        dcc_interval(id="session-interval", interval=100, n_intervals=0, disabled=true)

    ])

end



# This creates an initial session id that is unique for this session
# it will run on first start 
callback!(app,  Output("session-id", "data"),
                Output("label-id","children"),
                Input("session-id", "data")
                ) do session_id
    
    session_id = UUIDs.uuid4()
    str = "id=$(session_id), v=$(GUI_version)"
    
    return String("$(session_id)"), str
end


# Call run button
callback!(app,
    Output("session-interval","disabled"),
    Input("button-run", "n_clicks"),
    Input("button-run", "disabled"),
    Input("button-play", "n_clicks"),
    
    State("domain_width", "value"),
    State("nel_x", "value"),
    State("nel_z", "value"),
    State("n_timesteps", "value"),
    State("density_sphere", "value"),
    State("density_matrix", "value"),
    State("radius_sphere", "value"),
    State("viscosity", "value"),
    State("last_timestep","data"),
    State("plot_field","value"),
    prevent_initial_call=true
) do    n_run, active_run, n_play,
        domain_width, nel_x, nel_z, n_timesteps, 
        sphere_density, matrix_density, sphere_radius, viscosity, 
        last_timestep, plot_field

    trigger = get_trigger()
    disable_interval = true
    if trigger == "button-run.n_clicks"
        # We clicked the run button
        args = "-nstep_max $(n_timesteps) -radius[0] $sphere_radius -rho[0] $matrix_density -rho[1] $sphere_density  -nel_x $nel_x -nel_z $nel_z -coord_x $(-domain_width/2),$(domain_width/2) -coord_z $(-domain_width/2),$(domain_width/2)"
        
        clean_directory()   # removes all existing LaMEM files
        run_lamem(ParamFile, 1, args, wait=false)
        disable_interval = false

    elseif  trigger == "button-run.disabled"
        last_t = parse(Int,last_timestep )
        if active_run==true || last_t<n_timesteps
            disable_interval = false
        end

    elseif trigger == "button-play.n_clicks"
        last_t = parse(Int,last_timestep )
        @show last_t
        disable_interval = false
    end    

    return disable_interval
end


# deactivate the button 
callback!(app,
    Output("button-run","disabled"),
    Output("button-run","color"),
    Input("button-run", "n_clicks"),
    Input("session-interval", "n_intervals"),
    State("last_timestep","data"),
    State("current_timestep","data"),
    prevent_initial_call=true
) do n_run, n_inter, last_timestep, current_timestep

    cur_t = parse(Int, current_timestep)    # current timestep
    last_t = parse(Int, last_timestep)      # last timestep available on disk
    if cur_t<last_t 
        button_run_disable = true
        button_color = "danger"
    else
        button_run_disable = false
        button_color = "primary"
    end

    return button_run_disable, button_color
end


# Check if *.pvd file on disk changed and a new timestep is available
callback!(app,
    Output("last_timestep", "data"),
    Output("update_fig","data"),
    Input("session-interval", "n_intervals"),
    Input("button-run", "n_clicks"),
    State("current_timestep","data"),    
    State("update_fig","data"),
    State("session-id", "data"),
    prevent_initial_call=true
) do n_inter, n_run, current_timestep, update_fig, session_id
    trigger = get_trigger()
    if trigger == "session-interval.n_intervals"
        if isfile(OutFile*".pvd")
            # Read LaMEM *.pvd file
            Timestep, _, Time = Read_LaMEM_simulation(OutFile)

            # Update the labels and data stored in webpage about the last timestep
            last_time  = "$(Timestep[end])"
            
            update_fig = "$(parse(Int,update_fig)+1)"
        else
            last_time = "0"
            update_fig = "0"
        end
    elseif trigger == "button-run.n_clicks"

        last_time = "0"
        update_fig = "0"
    end

    return last_time, update_fig
end


# Update the figure if the signal is given to do so
callback!(app,
    Output("label-timestep", "children"),
    Output("label-time", "children"),
    Output("current_timestep","data"),
    Output("figure_main", "figure"),
    Output("plot_field","options"),
    Output("contour_option", "options"),
    Input("update_fig","data"),
    Input("current_timestep","data"),
    Input("button-run", "n_clicks"),
    Input("button-start", "n_clicks"),
    Input("button-last", "n_clicks"),
    Input("button-forward", "n_clicks"),
    Input("button-back", "n_clicks"),
    Input("button-play", "n_clicks"),
    State("last_timestep","data"),
    State("session-id", "data"),
    State("plot_field","value"),
    State("switch-contour","value"),
    State("contour_option","value"),
    State("switch-velocity","value"),
    State("color_map_option", "value"),
    prevent_initial_call=true
) do update_fig, current_timestep,  n_run, n_start, n_last, n_back, n_forward, n_play, last_timestep, session_id, 
    plot_field, switch_contour, contour_field, switch_velocity, color_map_option

    trigger = get_trigger()

    # Get info about timesteps
    cur_t = parse(Int, current_timestep)                    # current timestep
    last_t = parse(Int, last_timestep)                      # last timestep available on disk
    fig_cross = []
    fields_available = ["phase"]
    if trigger == "current_timestep.data" || 
        trigger == "update_fig.data" ||
        trigger == "button-start.n_clicks" ||
        trigger == "button-last.n_clicks" ||
        trigger == "button-back.n_clicks" ||
        trigger == "button-forward.n_clicks" ||
        trigger == "button-play.n_clicks"

        if isfile(OutFile*".pvd")
            Timestep, _, Time = Read_LaMEM_simulation(OutFile)      # all timesteps
            id = findall(Timestep .== cur_t)[1]
            if trigger == "button-start.n_clicks" || trigger == "button-play.n_clicks"
                cur_t = 0
                id = 1
            elseif trigger == "button-last.n_clicks"
                cur_t = Timestep[end]
                id = length(Timestep)
            elseif (trigger == "button-forward.n_clicks") && (id<length(Timestep))
                cur_t = Timestep[id+1]
                id = id+1
            elseif (trigger == "button-back.n_clicks") && (id>1)
                cur_t = Timestep[id-1]
                id = id-1
            end

            # Load data 
            x,y,data, time, fields_available = get_data(OutFile, cur_t, plot_field)
            if !isnothing(switch_contour)
                add_contours = true
                x_con,y_con,data_con, _, _ = get_data(OutFile, cur_t, contour_field)
            else
                x_con, y_con, data_con = x,y,data
                add_contours = false
            end    
            # update the plot
            
            if isnothing(switch_velocity)
                add_velocity = false
            else
                add_velocity = true
            end


            fig_cross = create_main_figure(OutFile, cur_t,x,y,data, x_con, y_con, data_con, field=plot_field, cmaps; 
                            add_contours = add_contours, contour_field = contour_field,
                            add_velocity = add_velocity,
                            colorscale   = color_map_option)

            if trigger == "current_timestep.data" ||  trigger == "update_fig.data" ||  trigger == "button-play.n_clicks"
                if cur_t < last_t 
                    cur_t = Timestep[id+1]      # update current timestep
                end
            end

        else
            time = 0
        end

    elseif trigger == "button-run.n_clicks"
        cur_t = 0
        time = 0.0
    end

    # update the labels
    label_timestep = "Timestep: $cur_t"
    label_time="Time: $time Myrs"
    current_timestep = "$cur_t"
    
    @show current_timestep
    return label_timestep, label_time, current_timestep, fig_cross, fields_available, fields_available
end

# 
callback!(app,
    Output("contour_option", "disabled"),
    Input("switch-contour", "value")) do  switch_contour
    if !isnothing(switch_contour)
        if isempty(switch_contour)
            disable_contours = true    
        else
            disable_contours = false    
        end
    else
        disable_contours = true    
    end
    return disable_contours    
end



run_server(app, debug=false)
