using Dash, DashBootstrapComponents
using PlotlyJS
using LaMEM
using UUIDs

GUI_version = "0.1.0"

# this is the main figure window
function create_main_figure()
    fig =  dcc_graph(
        id = "example-graph-1",
        figure = (
            data = [
                (x = ["giraffes", "orangutans", "monkeys"], y = [20, 14, 23], type = "bar", name = "SF"),
                (x = ["giraffes", "orangutans", "monkeys"], y = [12, 18, 29], type = "bar", name = "Montreal"),
            ],
            layout = (title = "Dash Data Visualization", barmode="group")
        ),
        #animate   = false,
        #responsive=false,
        #clickData = true,
        #config = PlotConfig(displayModeBar=false, scrollZoom = false),
        style = attr(width="80vw", height="80vh",padding_left="0vw",)
        )
    return fig
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


title_app = "Rising Sphere example"
ParamFile = "RisingSphere.dat"
OutFile = "RiseSphere"

#app = dash(external_stylesheets=[dbc_themes.CYBORG])
app = dash(external_stylesheets = [dbc_themes.BOOTSTRAP], prevent_initial_callbacks=false)
app.title = title_app

# Main code layout
app.layout = html_div() do
    dbc_container(className="mxy-auto", fluid=true, [
        dbc_col(html_h1(title_app), style=Dict("margin-top" => 0, "textAlign" => "center")), dbc_row([
            dbc_col([dbc_col(create_main_figure()),
                dbc_col(dbc_label("", id="label-id"))]),      # main figure window

            # right side menu
            dbc_col([dbc_card([dbc_label(" Time: 0 Myrs", id="label-time"),
                            dbc_label(" Timestep: 0", id="label-timestep")], color="secondary", outline=true),
                    dbc_card(dbc_label("Parameters", id="Parameters", size="lg"), color="white", outline=true),
                    dbc_card([
                            dbc_label("# of elements in the x-direction: ", id="nel_x_label"),
                            dbc_input(id="nel_x", placeholder="Insert the # of elements in the x-direction", type="number", min=2),
                        ], color="white", outline=true),
                    dbc_card([
                            dbc_label("# of elements in the z-direction: ", id="nel_z_label"),
                            dbc_input(id="nel_z", placeholder="Insert the # of elements in the z-direction", type="number", min=2),
                        ], color="white", outline=true),
                    dbc_card([
                            dbc_label("# of timesteps: ", id="n_timesteps_label"),
                            dbc_input(id="n_timesteps", placeholder="Insert the # of timesteps", type="number", min=1),
                        ], color="white", outline=true),
                    dbc_card([
                            dbc_label("Density of Sphere: ", id="density_sphere_label"),
                            dbc_input(id="sphere_density", placeholder="Insert the sphere density", type="number", min=1
                            )], color="white", outline=true),
                    dbc_card([
                            dbc_label("Density of Matrix: ", id="density_matrix_label"),
                            dbc_input(id="matrix_density", placeholder="Insert the matrix density", type="number", min=1)
                        ], color="white", outline=true),
                    dbc_card([
                            dbc_label("Radius of Sphere: ", id="sphere_radius_label"),
                            dbc_input(id="sphere_radius", placeholder="Insert the radius of the sphere", type="number")
                        ], color="white", outline=true),
                    dbc_card([
                            dbc_label("Width of Domain: ", id="domain_width_label"),
                            dbc_input(id="domain_width", placeholder="Insert the width of the domain", type="number"),
   
                            


                        ], color="white", outline=true),
                    dbc_col(dbc_button("RUN", id="button-run", size="lg", class_name="d-grid gap-2 col-12 mx-auto"))
                ],
                width=2)]),

        # Store a unique number of our session in the webpage
        dcc_store(id="session-id", data=""),
        dcc_store(id="current_timestep", data="0"),

        # Start an interval that updates the number every second
        dcc_interval(id="session-interval", interval=100, n_intervals=0, disabled=true)
        
        # Store the time steps that have been executed
        # dcc_store(id="all-current-timesteps", Timestep)

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
    State("nel_x", "value"),
    State("nel_z", "value"),
    State("n_timesteps", "value"),
    State("sphere_density", "value"),
    State("matrix_density", "value"),
    State("sphere_radius", "value"),
    State("domain_width", "value"),
    prevent_initial_call=true
) do n_run,  nel_x, nel_z, n_timesteps, sphere_density, matrix_density, sphere_radius, domain_width
    @show n_run, nel_x, nel_z, n_timesteps, sphere_density, matrix_density, sphere_radius, domain_width

    args = "-nstep_max $(n_timesteps) -radius[0] $sphere_radius -rho[0] $matrix_density -rho[1] $sphere_density  -nel_x $nel_x -nel_z $nel_z -coord_x $(-domain_width/2),$(domain_width/2) -coord_z $(-domain_width/2),$(domain_width/2)"
    run_lamem(ParamFile, 1, args, wait=true)

    disable_interval = false
    return args
end


# Check if disk changed; if yes 
callback!(app,
    Output("session-interval", "n_intervals"),
    Output("label-timestep", "children"),
    Output("label-time", "children"),
    Input("session-interval", "n_intervals"),
    State("label-time","data"),
    State("label-timestep","data"),
    prevent_initial_call=true
) do n_inter, label_time, label_timestep
    @show n_inter, session_id, current_timestep_plot

    # Read lamem output

    Timestep, label_timestep, label_time, Vz = read_simulation(OutFile, true)

    # Create new figure


    return n_inter, label_timestep, label_time
end






run_server(app, debug=false)
