using Dash, DashBootstrapComponents
using PlotlyJS
using LaMEM
using UUIDs

GUI_version = "0.1.0"

# this is the main figure window
function create_main_figure(x=1:10,y=1:10,data=rand(10,10); colorscale="Viridis")
            pl = (  id = "fig_cross",
            data = [heatmap(x = x, 
                            y = y, 
                            z = data,
                            colorscale   = colorscale,
                            colorbar= attr(thickness=5),
                            #zmin=zmin, zmax=zmax
                            )
                    ],                            
            colorbar=Dict("orientation"=>"v", "len"=>0.5,"title"=>"elevat"),
            layout = (  title = "Cross-section",
                        xaxis=attr(
                            title="Distance in x-Direction [km]",
                            tickfont_size= 14,
                            tickfont_color="rgb(100, 100, 100)"
                        ),
                        yaxis=attr(
                            title="Depth [km]",
                            tickfont_size= 14,
                            tickfont_color="rgb(10, 10, 10)"
                        ),
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
    value = data.fields[Symbol(field)]
    
    x = data.x.val[:,1,1]
    z = data.z.val[1,1,:]
    
    data2D = value[:,1,:]'

    return x,z,data2D
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
                    figure = create_main_figure(),
                    #animate   = false,
                    #responsive=false,
                    #clickData = true,
                    #config = PlotConfig(displayModeBar=false, scrollZoom = false),
                style = attr(width="80vw", height="80vh",padding_left="0vw",)
                )),
                dbc_row([
                    dbc_col([]),
                    dbc_col([
                        dbc_button("<<", id="button-start", outline=true, color="primary", size="sg", class_name="me-md-1 col-2"),
                        dbc_button("<", id="button-back", outline=true, color="primary", size="sg", class_name="me-md-1 col-1"),
                        dbc_button("Play/Pause", id="button-play", outline=true, color="primary", size="sg", class_name="me-md-1 col-3"),
                        dbc_button(">", id="button-forward", outline=true, color="primary", size="sg", class_name="me-md-1 col-1"),
                        dbc_button(">>", id="button-last", outline=true, color="primary", size="sg", class_name="me-md-1 col-2"),
                        ], class_name="d-grid gap-2 d-md-flex justify-content-md-center"), 
                    dbc_col([
                        dbc_dropdownmenu(
                            id="plot_field",
                            label="Plot field",
                            children=[
                                dbc_dropdownmenuitem("Phase", id="phase_item"),
                                dbc_dropdownmenuitem("Temperature", id="temperature_item"),
                                dbc_dropdownmenuitem("Viscosity", id="viscosity_item"),
                            ], color="secondary"),
                    ], class_name="d-grid gap-2 d-md-flex justify-content-md-end"),
                ]),
                dbc_col(dbc_label("", id="label-id"))
            ]),
            dbc_col([ # input column
                dbc_row([ # information card
                    dbc_card([
                        dbc_label(" Time: 0 Myrs", id="label-time"), 
                        dbc_label(" Timestep: 0", id="label-timestep",
                        )], 
                    color="secondary", 
                    class_name="d-grid gap-2 col-11 mx-auto",
                    outline=true)
                ]),
                dbc_row(html_p()),
                dbc_accordion(always_open=true, [
                    dbc_accordionitem(title="Simulation Parameters", [
                        dbc_row([ # domain width
                            dbc_col([
                                dbc_label("Lₓ (km): ", id="domain_width_label", size="sm"),
                                dbc_tooltip("Width of the domain, given in kilometers.", target="domain_width_label")
                            ]),
                            dbc_col(dbc_input(id="domain_width", placeholder="1.0", value=1.0, type="number", min=1.0e-10, size="sm"))
                        ]),
                        dbc_row(html_p()),
                        dbc_row([ # n elements in x-direction
                            dbc_col([
                                dbc_label("nx: ", id="nel_x_label", size="sm"),
                                dbc_tooltip(target="nel_x_label", "Number of elements in the x-direction. Must be an integer greater than 2.")
                            ]),
                            dbc_col(dbc_input(id="nel_x", placeholder="32", value=32, type="number", min=2, size="sm"))
                        ]),
                        dbc_row(html_p()),
                        dbc_row([ # n elements in z-direction
                            dbc_col([
                                dbc_label("nz: ", id="nel_z_label", size="sm"),
                                dbc_tooltip(target="nel_z_label", "Number of elements in the z-direction. Must be an integer greater than 2.")
                            ]),
                            dbc_col(dbc_input(id="nel_z", placeholder="32", value=32, type="number", min=2, size="sm"))
                        ]),
                        dbc_row(html_p()),
                        dbc_row([ # n of timesteps
                            dbc_col([
                                dbc_label("nt: ", id="n_timesteps_label", size="sm"),
                                dbc_tooltip(target="n_timesteps_label", "Maximum number of timesteps. Must be an integer greater than 1.")
                            ]),
                            dbc_col(dbc_input(id="n_timesteps", placeholder="10", value=10, type="number", min=1, size="sm"))
                        ]),
                    ]),
                    dbc_accordionitem(title="Rheological Parameters", [
                        # dbc_row(html_p()),
                        # dbc_row(html_hr()),
                        dbc_row([ # density of the sphere
                            dbc_col([
                                dbc_label("ρₛ (kg/m³): ", id="density_sphere_label", size="sm"),
                                dbc_tooltip(target="density_sphere_label", "Density of the sphere in kg/m³ (0 < ρₛ ≤ 10_000.0).")
                            ]),
                            dbc_col(dbc_input(id="density_sphere", placeholder="3400", value=3400, type="number", min=1.0e-10, size="sm"))
                        ]),
                        dbc_row(html_p()),
                        # dbc_row(html_hr()),
                        dbc_row([ # density of the matrix
                            dbc_col([
                                dbc_label("ρₘ (kg/m³): ", id="density_matrix_label", size="sm"),
                                dbc_tooltip(target="density_matrix_label", "Density of the matrix in kg/m³ (0 < ρₛ ≤ 10_000.0).")
                            ]),
                            dbc_col(dbc_input(id="density_matrix", placeholder="3000", value=3000, type="number", min=1.0e-10, size="sm"))
                        ]),
                        dbc_row(html_p()),
                        # dbc_row(html_hr()),
                        dbc_row([ # radius of the sphere
                            dbc_col([
                                dbc_label("rₛ (km): ", id="radius_sphere_label", size="sm"),
                                dbc_tooltip(target="radius_sphere_label", "Radius of the sphere in kilometers (0 < rₛ ≤ Lₓ).")
                            ]),
                            dbc_col(dbc_input(id="radius_sphere", placeholder="0.1", value=0.1, type="number", min=1.0e-10, size="sm"))
                        ]),
                        dbc_row(html_p()),
                        dbc_row([ # viscosity
                            dbc_col([
                                dbc_label("ηₘ (log(Pa⋅s))", id="viscosity_label", size="sm"),
                                dbc_tooltip(target="viscosity_label", "Logarithm of the viscosity of the matrix (15 < ηₘ ≤ 25).")
                            ]),
                            dbc_col(dbc_input(id="viscosity", placeholder="20.0", value=20, type="number", min=15, max=25, size="sm"))
                        ]), 
                        ])
                ]),
                # dbc_row(html_p()),
                # dbc_row([
                #     dbc_col(dbc_dropdownmenu(
                #         label="Plot type",
                #         children=[
                #             dbc_dropdownmenuitem("Viscosity"),
                #             dbc_dropdownmenuitem("Temperature"),
                #             dbc_dropdownmenuitem("Velocity"),
                #         ],
                #     )),
                #     dbc_col(dbc_button("Play", id="button-play", size="lg", class_name="d-grid gap-2 col-6 mx-auto"))
                # ]),
                dbc_row(html_p()),
                dbc_row(dbc_button("RUN", id="button-run", size="lg", class_name="d-grid gap-2 col-11 mx-auto"))
                
            ]) 
        ]),

        # Store a unique number of our session in the webpage
        dcc_store(id="session-id", data=""),
        
        # Store info related to the simulation and current timestep
        dcc_store(id="current_timestep", data="0"),
        dcc_store(id="last_timestep", data="0"),
        dcc_store(id="update_fig", data="0"),

        # Start an interval that updates the number every second
        dcc_interval(id="session-interval", interval=200, n_intervals=0, disabled=true)

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
    State("domain_width", "value"),
    State("nel_x", "value"),
    State("nel_z", "value"),
    State("n_timesteps", "value"),
    State("density_sphere", "value"),
    State("density_matrix", "value"),
    State("radius_sphere", "value"),
    State("viscosity", "value"),
    State("last_timestep","data"),

    prevent_initial_call=true
) do    n_run, active_run,
        domain_width, nel_x, nel_z, n_timesteps, 
        sphere_density, matrix_density, sphere_radius, viscosity, 
        last_timestep

    @show n_run, nel_x, nel_z, n_timesteps, sphere_density, matrix_density, sphere_radius, domain_width, viscosity

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
        println("running lamem")
        button_run_disable = true
        button_color = "danger"
    else
        println("finished lamem")
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
    Input("update_fig","data"),
    Input("current_timestep","data"),
    Input("button-run", "n_clicks"),
    State("last_timestep","data"),
    State("session-id", "data"),
    prevent_initial_call=true
) do update_fig, current_timestep,  n_run, last_timestep, session_id
    @show update_fig, current_timestep

    trigger = get_trigger()
    @show trigger

    # Get info about timesteps
    cur_t = parse(Int, current_timestep)                    # current timestep
    last_t = parse(Int, last_timestep)                      # last timestep available on disk
    fig_cross = []
    if trigger == "current_timestep.data" || 
        trigger == "update_fig.data"
        if isfile(OutFile*".pvd")
            Timestep, _, Time = Read_LaMEM_simulation(OutFile)      # all timesteps
            id = findall(Timestep .== cur_t)[1]
            time = Time[id]
            @show cur_t, last_t, id, Time[id]

                
            # Load data 
            field = "phase"
            x,y,data = get_data(OutFile, cur_t, "phase")

            # - TBD - 

            if cur_t < last_t
                cur_t = Timestep[id+1]      # update current timestep
            end

             # update the plot
            fig_cross = create_main_figure(x,y,data)
            
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

   

    return label_timestep, label_time, current_timestep, fig_cross
end



#=
# check every few milliseconds if the last timestep changed
callback!(app,
    Output("label-timestep", "children"),
    Input("last_timestep", "data"),
    Input("current_timestep","data"),
    State("session-id", "data"),
    prevent_initial_call=true
) do n_inter, current_timestep, session_id
    @show n_inter, current_timestep

    # Read LaMEM *.pvd file
    Timestep, _, Time = Read_LaMEM_simulation(OutFile)

    # Update the labels and data stored in webpage about the last timestep
    last_time = "$(Timestep[end])"
    label_timestep = "Timestep: $last_time"
    label_time="Time: $(Time[end]) Myrs"
    
    # create the figure

    return label_timestep, label_time, last_time
end



#=
#=
callback!(app,
    Output("session-interval", "n_intervals"),
    Input("current_timestep-interval", "data"),
    prevent_initial_call=true
) do current_timestep_plot
    @show "triggered current_timestep_plot", current_timestep_plot


    # Create new figure based on LaMEM output
    data = 1
    return data
end
=#
=#
=#

run_server(app, debug=false)
