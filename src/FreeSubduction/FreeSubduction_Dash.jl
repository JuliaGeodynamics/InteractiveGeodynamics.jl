module FreeSubductionTools

using Dash, DashBootstrapComponents
using PlotlyJS
using LaMEM
using UUIDs
using Interpolations
using GeophysicalModelGenerator
using HTTP

export subduction

pkg_dir = Base.pkgdir(FreeSubductionTools)
@show pkg_dir

include(joinpath(pkg_dir,"src/dash_tools.jl"))
include(joinpath(pkg_dir,"src/FreeSubduction/dash_functions_FreeSubduction.jl"))
include(joinpath(pkg_dir,"src/FreeSubduction/Setup.jl"))
 
"""
subduction(;  host = HTTP.Sockets.localhost, port=8050, wait=false, width="80vw", height="45vh")

This starts a free subduction GUI

Optional parameters
===
- `host`   : IP address
- `port`   : port number
- `wait`   : if true, you will see the LaMEM output and figure windows are only shown after the simulation is finished
- `width`  : relative width of main figure
- `height` : relative height of main figure

"""
function subduction(; host = HTTP.Sockets.localhost, port=8050, wait=false, width="80vw", height="50vh")
    pkg_dir = Base.pkgdir(FreeSubductionTools)
    
    GUI_version = "0.1.3"
    cmaps = read_colormaps(dir_colormaps=joinpath(pkg_dir,"src/assets/colormaps/"))

    title_app = "Free Subduction"
  #  ParamFile = "RTI.dat"
    OutFile = "FreeSubduction"
    
    #app = dash(external_stylesheets=[dbc_themes.CYBORG])
    app = dash(external_stylesheets = [dbc_themes.BOOTSTRAP, dbc_icons.BOOTSTRAP], prevent_initial_callbacks=false)
    app.title = title_app

    # Main code layout
    app.layout = html_div() do
        dbc_container(className="mxy-auto", fluid=true, [
            make_title(title_app),
            dbc_row([
                dbc_col([
                    make_plot("",cmaps, width=width, height=height),    # show graph
                    make_plot_controls(),   # show media buttons
                    make_id_label(),        # show user id
                ]),
                dbc_col([
                    make_time_card(),       # show simulation time info
                    make_menu(cmaps),       # show menu with simulation parameters, rheological parameters, and plotting parameters
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
        Dash.Output("session-id", "data"),
        Dash.Output("label-id", "children"),
        Input("session-id", "data")
    ) do session_id

        session_id = UUIDs.uuid4()
        str = "id=$(session_id), v=$(GUI_version)"
        return String("$(session_id)"), str
    end

    # Call run button
    callback!(app,
        Dash.Output("session-interval", "disabled"),
        Input("button-run", "n_clicks"),
        Input("button-run", "disabled"),
        Input("button-play", "n_clicks"), 
        State("slab_thickness", "value"),
        State("crust_thickness", "value"),
        State("nel_z", "value"),
        State("n_timesteps", "value"),
        State("switch-FreeSurf", "value"),
        State("last_timestep", "data"),
        State("plot_field", "value"),
        State("session-id", "data"), 
        State("viscosity_slab", "value"),
        State("viscosity_mantle", "value"),
        State("viscosity_crust", "value"),
        State("yield_stress_crust", "value"),
        prevent_initial_call=true
    ) do n_run, active_run, n_play,
        slab_thickness, crust_thickness, nel_z, n_timesteps,
        free_surf,
        last_timestep, plot_field, session_id,
        η_slab,η_mantle,η_crust,yield_stress_crust
        

        # print(layers)
        # print(open_top)

        trigger = get_trigger()
        disable_interval = true
        if trigger == "button-run.n_clicks"
            cur_dir = pwd()
            base_dir = joinpath(pkgdir(FreeSubductionTools),"src","FreeSubduction")

            η_slab   = 10.0^η_slab
            η_mantle = 10.0^η_mantle
            η_crust  = 10.0^η_crust

            # We clicked the run button
            user_dir = simulation_directory(session_id, clean=true)
            cd(user_dir)

            @show free_surf 
            if free_surf === nothing || free_surf == []
                free_surface = true
            else
                free_surface = false
            end
          

            # Create the setup
            model = create_model_setup(nz=nel_z, SlabThickness=slab_thickness, CrustThickness = crust_thickness, eta_slab=η_slab, eta_mantle=η_mantle, eta_crust=η_crust,
                            C_crust = yield_stress_crust,
                            OutFile=OutFile, nstep_max=n_timesteps,
                            free_surface=free_surface)
    
            #run_lamem(pfile, 1, args, wait=false)
            run_lamem(model, 1, wait=wait)
            cd(cur_dir)        # return to main directory

            disable_interval = false

        elseif trigger == "button-run.disabled"
            last_t = parse(Int, last_timestep)
            if active_run == true || last_t < n_timesteps
                disable_interval = false
            end

        elseif trigger == "button-play.n_clicks"
            last_t = parse(Int, last_timestep)
            # @show last_t
            disable_interval = false
        end
        
        return disable_interval
    end

    # deactivate the button 
    callback!(app,
        Dash.Output("button-run", "disabled"),
        Dash.Output("button-run", "color"),
        Input("button-run", "n_clicks"),
        Input("session-interval", "n_intervals"),
        State("last_timestep", "data"),
        State("current_timestep", "data"),
        prevent_initial_call=true
    ) do n_run, n_inter, last_timestep, current_timestep

        cur_t = parse(Int, current_timestep)    # current timestep
        last_t = parse(Int, last_timestep)      # last timestep available on disk
        if cur_t < last_t
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
        Dash.Output("last_timestep", "data"),
        Dash.Output("update_fig", "data"),
        Input("session-interval", "n_intervals"),
        Input("button-run", "n_clicks"),
        State("current_timestep", "data"),
        State("update_fig", "data"),
        State("session-id", "data"),
        prevent_initial_call=true
    ) do n_inter, n_run, current_timestep, update_fig, session_id
        trigger = get_trigger()
        user_dir = simulation_directory(session_id, clean=false)
        if trigger == "session-interval.n_intervals"
            if has_pvd_file(OutFile, user_dir)
                # Read LaMEM *.pvd file
                Timestep, _, Time = read_LaMEM_simulation(OutFile, user_dir)

                # Update the labels and data stored in webpage about the last timestep
                last_time = "$(Timestep[end])"

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
        Dash.Output("label-timestep", "children"),
        Dash.Output("label-time", "children"),
        Dash.Output("current_timestep", "data"),
        Dash.Output("figure_main", "figure"),
        Dash.Output("plot_field", "options"),
        Dash.Output("contour_option", "options"),
        Input("update_fig", "data"),
        Input("current_timestep", "data"),
        Input("button-run", "n_clicks"),
        Input("button-start", "n_clicks"),
        Input("button-last", "n_clicks"),
        Input("button-forward", "n_clicks"),
        Input("button-back", "n_clicks"),
        Input("button-play", "n_clicks"),
        State("last_timestep", "data"),
        State("session-id", "data"),
        State("plot_field", "value"),
        State("switch-contour", "value"),
        State("contour_option", "value"),
        State("switch-velocity", "value"),
        State("color_map_option", "value"),
        prevent_initial_call=true
    ) do update_fig, current_timestep, n_run, n_start, n_last, n_back, n_forward, n_play, last_timestep, session_id,
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

            user_dir = simulation_directory(session_id, clean=false)
            if has_pvd_file(OutFile, user_dir)
                Timestep, _, Time = read_LaMEM_simulation(OutFile, user_dir)      # all timesteps
                id = findall(Timestep .== cur_t)[1]
                if trigger == "button-start.n_clicks" || trigger == "button-play.n_clicks"
                    cur_t = 0
                    id = 1
                elseif trigger == "button-last.n_clicks"
                    cur_t = Timestep[end]
                    id = length(Timestep)
                elseif (trigger == "button-forward.n_clicks") && (id < length(Timestep))
                    cur_t = Timestep[id+1]
                    id = id + 1
                elseif (trigger == "button-back.n_clicks") && (id > 1)
                    cur_t = Timestep[id-1]
                    id = id - 1
                end

                # Load data 
                x, y, data, time, fields_available = get_data(OutFile, cur_t, plot_field, user_dir)
                add_contours = active_switch(switch_contour)
                if add_contours
                    x_con, y_con, data_con, _, _ = get_data(OutFile, cur_t, contour_field, user_dir)
                else
                    x_con, y_con, data_con = x, y, data
                end

                # update the plot
                add_velocity = active_switch(switch_velocity)
                
                fig_cross = create_main_figure(OutFile, cur_t, x, y, data, x_con, y_con, data_con;
                    add_contours=add_contours, contour_field=contour_field,
                    add_velocity=add_velocity,
                    colorscale=color_map_option,
                    session_id=session_id,
                    field=plot_field, cmaps=cmaps)

                if trigger == "current_timestep.data" || trigger == "update_fig.data" || trigger == "button-play.n_clicks"
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
        label_time = "Time: $time Myrs"
        current_timestep = "$cur_t"

        # @show current_timestep
        println("Timestep ", current_timestep)
        return label_timestep, label_time, current_timestep, fig_cross, fields_available, fields_available
    end

    # 
    callback!(app,
        Dash.Output("contour_option", "disabled"),
        Input("switch-contour", "value")) do switch_contour
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

    run_server(app, host, port, debug=false)

end

end
