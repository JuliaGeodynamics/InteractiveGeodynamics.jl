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
        style = attr(width="70vw", height="70vh",padding_left="0vw",)
        )
    return fig
end


title_app = "Rising Sphere example"
ParamFile = "RisingSphere.dat"


#app = dash(external_stylesheets=[dbc_themes.CYBORG])
app = dash(external_stylesheets = [dbc_themes.BOOTSTRAP], prevent_initial_callbacks=false)
app.title = title_app

# Main code layout
app.layout = html_div() do
    dbc_container(className="mxy-auto", fluid=true, [
        dbc_row(html_h1(title_app), style=Dict("margin-top" => 0, "textAlign" => "center")), # title row
        dbc_row([ # data row
            dbc_col([ # graph column
                dbc_col(create_main_figure()),
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
                dbc_row([ # domain width
                    dbc_col(dbc_label("Domain width (km): ", id="domain_width_label")),
                    dbc_col(dbc_input(id="domain_width", placeholder="1.0", value=1.0, type="number", min=1.0e-10))
                ]),
                dbc_row(html_p()),
                dbc_row(html_hr()),
                dbc_row([ # n elements in x-direction
                    dbc_col(dbc_label("# of elements in the x-direction: ", id="nel_x_label")),
                    dbc_col(dbc_input(id="nel_x", placeholder="16", value=16, type="number", min=2))
                ]),
                dbc_row(html_p()),
                dbc_row(html_hr()),
                dbc_row([ # n elements in z-direction
                    dbc_col(dbc_label("# of elements in the z-direction: ", id="nel_z_label")),
                    dbc_col(dbc_input(id="nel_z", placeholder="16", value=16, type="number", min=2))
                ]),
                dbc_row(html_p()),
                dbc_row(html_hr()),
                dbc_row([ # n of timesteps
                    dbc_col(dbc_label("# of timesteps: ", id="n_timesteps_label")),
                    dbc_col(dbc_input(id="n_timesteps", placeholder="10", value=10, type="number", min=1))
                ]),
                dbc_row(html_p()),
                dbc_row(html_hr()),
                dbc_row([ # density of the sphere
                    dbc_col(dbc_label("Density of the sphere (kg/m³): ", id="density_sphere_label")),
                    dbc_col(dbc_input(id="density_sphere", placeholder="3400", value=3400, type="number", min=1.0e-10))
                ]),
                dbc_row(html_p()),
                dbc_row(html_hr()),
                dbc_row([ # density of the matrix
                    dbc_col(dbc_label("Density of the matrix (kg/m³): ", id="density_matrix_label")),
                    dbc_col(dbc_input(id="density_matrix", placeholder="3000", value=3000, type="number", min=1.0e-10))
                ]),
                dbc_row(html_p()),
                dbc_row(html_hr()),
                dbc_row([ # radius of the sphere
                    dbc_col(dbc_label("Radius of the sphere (km): ", id="radius_sphere_label")),
                    dbc_col(dbc_input(id="radius_sphere", placeholder="0.1", value=0.1, type="number", min=1.0e-10))
                ]),
                dbc_row(html_p()),
                dbc_row(html_hr()),
                dbc_row(dbc_button("RUN", id="button-run", size="lg", class_name="d-grid gap-2 col-12 mx-auto"))
                
            ]) 
        ]),

        # Store a unique number of our session in the webpage
        dcc_store(id="session-id", data=""),
        dcc_store(id="current_timestep", data="0"),

        # Start an interval that updates the number every second
        dcc_interval(id="session-interval", interval=1000, n_intervals=0, disabled=true)])

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
    Output("label-timestep", "children"),
    Output("session-interval","disabled"),
    Input("button-run", "n_clicks"),
    State("domain_width", "value"),
    State("nel_x", "value"),
    State("nel_z", "value"),
    State("n_timesteps", "value"),
    State("density_sphere", "value"),
    State("density_matrix", "value"),
    State("radius_sphere", "value"),
    prevent_initial_call=true
) do n_run, domain_width, nel_x, nel_z, n_timesteps, density_sphere, density_matrix, radius_sphere
    @show n_run, domain_width, nel_x, nel_z, n_timesteps, density_sphere, density_matrix, radius_sphere
    str = "Timestep: $n_run"


    disable_interval = false
    return str, disable_interval
end


# Check if disk changed; if yes 
callback!(app,
    Output("session-interval", "n_intervals"),
    Input("session-interval", "n_intervals"),
    State("session-id","data"),
    State("current_timestep","data"),
    prevent_initial_call=true
) do n_inter, session_id, current_timestep_plot
    @show n_inter, session_id, current_timestep_plot

    # Read lamem output in the appropriate directory
    
    # Create new figure based on LaMEM output

    return n_inter
end






run_server(app, debug=false)
