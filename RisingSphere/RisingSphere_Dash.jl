using Dash, DashBootstrapComponents
using PlotlyJS
using LaMEM
using UUIDs

GUI_version = "0.1.0"

# this is the main figure window
function create_main_figure()
            pl = (  id = "fig_cross",
            data = [heatmap(x = [i for i in 1:10], 
                            y = [i for i in 1:10], 
                            z = randn(10,10),
                            colorscale   = "Viridis",
                            colorbar=attr(thickness=15),
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

function read_simulation(OutFile, last = true)

    if last
        Timestep, _, _ = Read_LaMEM_simulation(OutFile)
        t_step = Timestep[end]
    end

    data, time = Read_LaMEM_timestep(OutFile, t_step, last=last);
    vel  =  data.fields.velocity; #velocity
    Vz   =  vel[3,:,:,:] # Vz

    return Timestep,  t_step, time, Vz 
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
                dbc_col(dbc_label("", id="label-id"))
            ]),
            dbc_col([ # input column
                dbc_row([ # information card
                    dbc_card([
                        dbc_label(" Time: 0 Myrs", id="label-time"), 
                        dbc_label(" Timestep: 0", id="label-timestep"
                        )], 
                    color="secondary", 
                    outline=true)
                ]),
                dbc_row(html_p()),
                dbc_accordion(always_open=true, [
                    dbc_accordionitem(title="Simulation Parameters", [
                        dbc_row([ # domain width
                            dbc_col(dbc_label("Domain width (km): ", id="domain_width_label", size="sm")),
                            dbc_col(dbc_input(id="domain_width", placeholder="1.0", value=1.0, type="number", min=1.0e-10, size="sm"))
                        ]),
                        dbc_row([ # n elements in x-direction
                            dbc_col(dbc_label("# of elements in the x-direction: ", id="nel_x_label", size="sm")),
                            dbc_col(dbc_input(id="nel_x", placeholder="32", value=32, type="number", min=2, size="sm"))
                        ]),
                        dbc_row([ # n elements in z-direction
                            dbc_col(dbc_label("# of elements in the z-direction: ", id="nel_z_label", size="sm")),
                            dbc_col(dbc_input(id="nel_z", placeholder="32", value=32, type="number", min=2, size="sm"))
                        ]),
                        dbc_row(html_p()),
                        dbc_row([ # n of timesteps
                            dbc_col(dbc_label("# of timesteps: ", id="n_timesteps_label", size="sm")),
                            dbc_col(dbc_input(id="n_timesteps", placeholder="10", value=10, type="number", min=1, size="sm"))
                        ]),
                    ]),
                    dbc_accordionitem(title="Rheological Parameters", [
                        # dbc_row(html_p()),
                        # dbc_row(html_hr()),
                        dbc_row([ # density of the sphere
                            dbc_col(dbc_label("Density of the sphere (kg/m³): ", id="density_sphere_label", size="sm")),
                            dbc_col(dbc_input(id="density_sphere", placeholder="3400", value=3400, type="number", min=1.0e-10, size="sm"))
                        ]),
                        dbc_row(html_p()),
                        # dbc_row(html_hr()),
                        dbc_row([ # density of the matrix
                            dbc_col(dbc_label("Density of the matrix (kg/m³): ", id="density_matrix_label", size="sm")),
                            dbc_col(dbc_input(id="density_matrix", placeholder="3000", value=3000, type="number", min=1.0e-10, size="sm"))
                        ]),
                        dbc_row(html_p()),
                        # dbc_row(html_hr()),
                        dbc_row([ # radius of the sphere
                            dbc_col(dbc_label("Radius of the sphere (km): ", id="radius_sphere_label", size="sm")),
                            dbc_col(dbc_input(id="radius_sphere", placeholder="0.1", value=0.1, type="number", min=1.0e-10, size="sm"))
                        ]),
                        dbc_row(html_p()),
                        dbc_row([ # viscosity
                            dbc_col(dbc_label("Viscosity (log(Pa⋅s))", id="viscosity_label", size="sm")),
                            dbc_col(dbc_input(id="viscosity", placeholder="20.0", value=20, type="number", min=15, max=25, size="sm"))
                        ]), 
                        ])
                ]),
                dbc_row(html_p()),
                dbc_row(dbc_button("RUN", id="button-run", size="lg", class_name="d-grid gap-2 col-12 mx-auto"))
                
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
) do    n_run,
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
        println("started new run")
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

    if trigger == "current_timestep.data" || 
        trigger == "update_fig.data"
        if isfile(OutFile*".pvd")
            Timestep, _, Time = Read_LaMEM_simulation(OutFile)      # all timesteps
            id = findall(Timestep .== cur_t)[1]
            time = Time[id]
            @show cur_t, last_t, id, Time[id]

                
            # create the figure
            # - TBD - 

            if cur_t < last_t
                cur_t = Timestep[id+1]      # update current timestep
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

    # update the plot
    fig_cross = create_main_figure()

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
