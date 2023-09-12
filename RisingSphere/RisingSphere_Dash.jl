using Dash, DashBootstrapComponents
using PlotlyJS, UUIDs


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


title_app = "Rising Sphere example"


#app = dash(external_stylesheets=[dbc_themes.CYBORG])
app = dash(external_stylesheets = [dbc_themes.BOOTSTRAP], prevent_initial_callbacks=false)
app.title = title_app

# Main code layout
app.layout = html_div() do
    dbc_container(className = "mxy-auto", fluid=true, [
        dbc_col(html_h1(title_app), style = Dict("margin-top" => 0, "textAlign" => "center")),
        
        dbc_row([
                dbc_col([dbc_col(create_main_figure()),
                        dbc_col(dbc_label("", id="label-id"))])      # main figure window

                # right side menu
                dbc_col([   dbc_card([dbc_col(dbc_label("Time: 0Myrs", id="label-time")),
                                      dbc_col(dbc_label("Timestep: 0", id="label-timestep"))]),

                            dbc_col(dbc_button("RUN", id="button-run", size="lg"))]
                            ,width=2)
                        
        
        ]),

        # Store a unique number of our session in the webpage
        dcc_store(id="session-id", data =  "")     


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

# Save state
callback!(app,
    Output("label-timestep", "children"), 
    Input("button-run", "n_clicks"),
    prevent_initial_call=true
) do n_run
    @show n_run



    str = "$n_run"
    
    return str
end







run_server(app, debug=false)
