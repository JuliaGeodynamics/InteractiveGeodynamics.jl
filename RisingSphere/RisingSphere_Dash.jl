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
    dbc_container(className = "mxy-auto", fluid=true, [
        dbc_col(html_h1(title_app), style = Dict("margin-top" => 0, "textAlign" => "center")),
        
        dbc_row([
                dbc_col([dbc_col(create_main_figure()),
                        dbc_col(dbc_label("", id="label-id"))]),      # main figure window

                # right side menu
                dbc_col([   dbc_card([dbc_col(dbc_label("Time: 0Myrs", id="label-time")),
                                      dbc_col(dbc_label("Timestep: 0", id="label-timestep"))]),

                            dbc_card(dbc_label("Parameters", id="Parameters", size="lg")),
                            
                            dbc_card([
                                    dbc_col(dbc_label("Density of Sphere", id="density_sphere_label")),
                                    dbc_col(dbc_input(id="sphere_density", placeholder="Insert the sphere density", type="number"))]),
                            dbc_card([
                                    dbc_col(dbc_label("Density of Matrix", id="density_matrix_label")),
                                    dbc_col(dbc_input(id="matrix_density", placeholder="Insert the matrix density", type="number"))]),
                            dbc_card([
                                    dbc_col(dbc_label("Radius of Sphere", id="sphere_radius_label")),
                                    dbc_col(dbc_input(id="sphere_radius", placeholder="Insert the radius of the sphere", type="number"))]),
                            dbc_card([
                                    dbc_col(dbc_label("Width of Domain", id="domain_width_label")),
                                    dbc_col(dbc_input(id="domain_width", placeholder="Insert the width of the domain", type="number"))]),
                            dbc_card([
                                    dbc_col(dbc_label("nel_x", id="nel_x_label")),
                                    dbc_col(dbc_input(id="input_nel_x", placeholder="Insert the # of elements", type="number")),
                                    dbc_col(dbc_label("nel_z", id="nel_z_label")),
                                    dbc_col(dbc_input(id="input_nel_z", placeholder="Insert the # of elements", type="number")),
                                    dbc_col(dbc_label("nt", id="nt_label")),
                                    dbc_col(dbc_input(id="input_nt", placeholder="Insert the # of timesteps", type="number"))]),
                            


                            dbc_col(dbc_button("RUN", id="button-run", size="lg")),
                                    ],

                            
                            width=2)
                        

        
        ]),

        # Store a unique number of our session in the webpage
        dcc_store(id="session-id", data =  ""),     

        # Start an interval that updates the number every second
        dcc_interval(id="session-interval", interval=1000, n_intervals=0, disabled=true)
        
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
    State("sphere_density", "value"),
    State("matrix_density", "value"),
    State("sphere_radius", "value"),
    State("domain_width", "value"),
    State("input_nel_x", "value"),
    State("input_nel_z", "value"),
    State("input_nt", "value"),
    prevent_initial_call=true
) do n_run, input_density, input_matrix, input_radius, input_width, input_nel_x, input_nel_z, input_nt
    @show n_run, input_density, input_matrix, input_radius, input_width, input_nel_x, input_nel_z, input_nt

    #run_code(ParamFile; wait = true)

    args = "-nstep_max $(input_nt) -radius[0] $input_radius -rho[0] $input_matrix -rho[1] $input_density  -nel_x $input_nel_x -nel_z $input_nel_z -coord_x $(-input_width/2),$(input_width/2) -coord_z $(-input_width/2),$(input_width/2)"
    run_lamem(ParamFile, 1, args, wait=false)

    disable_interval = false
    return disable_interval
end


# Check if disk changed
callback!(app,
    Output("session-interval", "n_intervals"),
    Output("label-timestep", "children"),
    Output("label-time", "children"),
    Input("session-interval", "n_intervals"),
    prevent_initial_call=true
) do n_inter
    @show n_inter

    # Read lamem output

    Timestep, label_timestep, label_time, Vz = read_simulation(OutFile, true)

    # Create new figure


    return n_inter, label_timestep, label_time
end






run_server(app, debug=false)
