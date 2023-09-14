using Dash, DashBootstrapComponents
using PlotlyJS
using LaMEM
using UUIDs
using Interpolations

GUI_version = "0.1.0"

include("utils.jl")
cmaps = read_colormaps()

# create a new directory named by session-id
# function make_new_directory(session_id)
#     cur_dir = pwd()
#     if isdir("simulations")
#         cd("simulations")
#     else
#         mkdir("simulations")
#         cd("simulations")
#     end
#     dirname = String(session_id)
#     mkdir(dirname)
#     cd(cur_dir)
#     return dirname
# end
# still need to save timestep file in the simulations/session_id file

title_app = "Rising Sphere example"
ParamFile = "RisingSphere.dat"
OutFile = "RiseSphere"

#app = dash(external_stylesheets=[dbc_themes.CYBORG])
app = dash(external_stylesheets = [dbc_themes.BOOTSTRAP], prevent_initial_callbacks=false)
app.title = title_app

# Main code layout
app.layout = html_div() do
    dbc_container(className="mxy-auto", fluid=true, [
        make_title(title_app),
        dbc_row([
            dbc_col([
                make_plot(),            # show graph
                make_plot_controls(),   # show media buttons
                make_id_label(),        # show user id
            ]),
            dbc_col([
                make_time_card(),       # show simulation time info
                make_menu(),            # show menu with simulation parameters, rheological parameters, and plotting parameters
                make_run_button()       # show the run simulation button
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
callback!(app, 
    Output("session-id", "data"),
    Output("label-id", "children"),
    Input("session-id", "data")
) do session_id

    session_id = UUIDs.uuid4()
    str = "id=$(session_id), v=$(GUI_version)"

    # make_new_directory(session_id)

    return String("$(session_id)"), str
end


# Call run button
callback!(app,
    Output("session-interval", "disabled"),
    Input("button-run", "n_clicks"),
    Input("button-run", "disabled"),
    Input("button-play", "n_clicks"), State("domain_width", "value"),
    State("nel_x", "value"),
    State("nel_z", "value"),
    State("n_timesteps", "value"),
    State("density_sphere", "value"),
    State("density_matrix", "value"),
    State("radius_sphere", "value"),
    State("viscosity", "value"),
    State("last_timestep", "data"),
    State("plot_field", "value"),
    prevent_initial_call=true
) do n_run, active_run, n_play,
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

    elseif trigger == "button-run.disabled"
        last_t = parse(Int, last_timestep)
        if active_run == true || last_t < n_timesteps
            disable_interval = false
        end

    elseif trigger == "button-play.n_clicks"
        last_t = parse(Int, last_timestep)
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
