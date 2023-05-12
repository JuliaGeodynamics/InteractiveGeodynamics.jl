using LaMEM, Revise, FileWatching, Interpolations
using GLMakie
using GLMakie: to_native
using GLMakie.GLFW

using LaMEM
export LaMEM        # export all LaMEM routines


GLMakie.activate!()

include("./utils.jl")
include("./widgets.jl")

"""
    update_info(gui::NamedTuple, values::NamedTuple)

This updates the info window on the GUI. If you wish, you can overwrite this in your custom routine.
Parameters:
-  `gui`: NamedTuple with various labels on the GUI
-  `values`: NamedTuple with update data that can be used
"""
function update_info(gui::NamedTuple, values::NamedTuple)
    pad_space = 15
    gui.time.displayed_string[] = rpad(string(round(values.time[1]; digits=3)),pad_space)
    gui.timestep.displayed_string[] = rpad(string(values.t_step),pad_space)

    return nothing
end


"""
    Read_data_field(ifield, data, component=1)
Reads a certain datafield from the LaMEM data structure (and optionally, a component if it is a vector or tensor field)
"""
function Read_data_field(ifield, data, component=1)
    # Read the field
    data_field = data.fields[ifield]
    if length(size(data_field))==3
        data_field = data_field[:,1,:]
    elseif length(size(data_field))>3
        if component <= size(data_field,1)
            data_field = data_field[component,:,1,:]
        end
    else
        error("unknown size of data field")
    end

    return data_field
end

"""
    update_plot_info(OutFile, gui::NamedTuple, t_step::Int64; last=false)

This updates the main plot within the GUI
"""
function update_plot_info(OutFile, gui::NamedTuple, t_step::Int64; last=false)
        
    t_step,_ = update_plot_info_basic(OutFile, gui, t_step; last=last)
    
    return t_step, gui
end


# Basic code
function update_plot_info_basic(OutFile, gui::NamedTuple, t_step::Int64; last=false)
        
    # Load LaMEM result
    if last
        Timestep, _, _ = Read_LaMEM_simulation(OutFile)
        t_step = Timestep[end]
    end

    data, time = Read_LaMEM_timestep(OutFile, t_step, last=last);
    
    # update info window
    values = (t_step=t_step, time=time);
    update_info(gui, values)

    # Read the field from the LaMEM dataset
    ifield    = gui.menu.i_selected[]
    component =  parse(Int,gui.menu_comp.stored_string[])
    data_field = Read_data_field(ifield, data, component)
    
    # set label of colorbar
    gui.cb.label= Read_LaMEM_fieldnames(OutFile)[ifield]

    lim = Float64.(extrema(data_field))
    try # this deals with a bug that sometimes occurs
        gui.cb.limits = lim
    catch
        gui.cb.limits = lim .+ (-1e-3,1e-3)
    end

    # plot the field that is selected in the dropdown menu
    gui.hm[1] = data.x.val[:,1,1];
    gui.hm[2] = data.z.val[1,1,:];
    gui.hm[3] = data_field  

    aspect_ratio =  (data.x.val[end]- data.x.val[1]) / (data.z.val[end]- data.z.val[1])
   # ax.aspect = aspect_ratio
  #  gui.cb.height[] = Relative(1/aspect_ratio*0.9)

    # plot velocity arrows if requested
    if gui.velocity_toggle.active[]
        num_z = 20;
        num_x = round(Int64,num_z*aspect_ratio);

        x,z = data.x.val[:,1,1], data.z.val[1,1,:];
        Vx,Vz = data.fields.velocity[1,:,1,:], data.fields.velocity[3,:,1,:];

        x_low = range(x[1], x[end], num_x);
        z_low = range(z[1], z[end], num_z)
        Vx_itp = linear_interpolation((x,z), Vx; extrapolation_bc=Throw())
        Vz_itp = linear_interpolation((x,z), Vz; extrapolation_bc=Throw())
        pt_arrow = [];
        vel_arrow = []
        for x in x_low, z in z_low
            push!(pt_arrow, Point2f(x,z))
            push!(vel_arrow, Vec2f(Vx_itp(x, z),Vz_itp(x, z)))
        end
        gui.pt_arrow[]= pt_arrow
        gui.vel_arrow[]= vel_arrow

        xlims!(ax,x[1],x[end])
        ylims!(ax,z[1],z[end])

        gui.arrows.visible[]=true

    else
        gui.arrows.visible[]=false

    end
    
    display(fig)
    sleep(1/60)

    return t_step, data
end


"""
    fig, ax, gui = Create_Basic_LaMEM_GUI(OutFile, ParamFile; resolution = nothing, fontsize=30, colormap=:viridis, size_total=(1:20, 1:7), size_ax=(1:20, 1:4))

Creates a basic LaMEM GUI that has a "run" and "play" button and the option to change the max. number of timesteps.

Input arguments:
- `OutFile`: the LaMEM output files (without pvd extension)
- `ParamFile`: the LaMEM input file (incluidng `*.dat`)

Optional arguments:
- `resolution`: resolution of the screen. by default this is set to `nothing` which produces a small figure tat require resizing
- `fontsize`: fontsize 
- `colormap`: colormap used
- `width`: width of last row
- `size_total`: total size of the GUI - bottons etc. will be put @ the end
- `size_ax`: size of the axis

Output arguments:
- `fig`: the main figure window
- `ax`: the main axis
- `gui`: A named tuple with all GUI elements


"""
function Create_Basic_LaMEM_GUI(OutFile, ParamFile; resolution = nothing, fontsize=nothing, colormap=:viridis, width=160, size_total=(1:18, 1:7), size_ax=(1,1))

    # Generate general layout
    if isnothing(resolution) & isnothing(fontsize)
        fig = Figure()        # default figure size (requires resizing)
    elseif isnothing(resolution) & !isnothing(fontsize)
        fig = Figure(fontsize=fontsize) 

    elseif !isnothing(resolution) & isnothing(fontsize)
        fig = Figure(resolution=resolution) 

    else

        fig = Figure( resolution=resolution, fontsize=fontsize)
    end
    
    # main figure
#    ax = Axis(fig[size_ax...], xlabel="Width [km]", ylabel="Depth [km]", aspect = 1)
    #ax = Axis(fig[2,1][size_ax...], xlabel="Width [km]", ylabel="Depth [km]", aspect = 1)
    ax = Axis(fig[2,1][size_ax...], xlabel="Width [km]", ylabel="Depth [km]")
    

    menu_file = Menu(fig[1, 1][1,1], options = ["File","Save animation", "Save plot", "Close window"], default = "File", selection_cell_color_inactive = GLMakie.RGB(1,1,1))
    rowsize!(fig.layout, 1, 30)

    # info window
    #lb_time,_ = Textbox_with_label_left(fig[1, size_total[2][end-1:end]], "time [Myr]: ", 0.0, bordercolor_hover=:white, bordercolor=:white, boxcolor_hover=:white, width=width)
    #lb_timestep,_ = Textbox_with_label_left(fig[2, size_total[2][end-1:end]], "timestep: ", 0, bordercolor_hover=:white, bordercolor=:white, boxcolor_hover=:white, width=width)
    lb_time,_ = Textbox_with_label_left(fig[2,2][1,1:2], "time [Myr]: ", 0.0, bordercolor_hover=:white, bordercolor=:white, boxcolor_hover=:white, width=width)
    lb_timestep,_ = Textbox_with_label_left(fig[2,2][2,1:2], "timestep: ", 0, bordercolor_hover=:white, bordercolor=:white, boxcolor_hover=:white, width=width)
    
    # retrieve maximum # of timestep
    nstep_max = keyword_LaMEM_inputfile(ParamFile,"nstep_max", Int64);
#    nstep_max_tb,_ = Textbox_with_label_left(fig[3, size_total[2][end-1:end]], "max. # timesteps: ", nstep_max, width=width);
    nstep_max_tb,_ = Textbox_with_label_left(fig[2,2][3,1:2], "max. # timesteps: ", nstep_max, width=width);

    # Grid resolution
    nel_z = keyword_LaMEM_inputfile(ParamFile,"nel_z", Int64);
    #nel_z_tb,_ = Textbox_with_label_left(fig[4, size_total[2][end-1:end]], "# gridpoints [z]: ", nel_z, width=width);
    nel_z_tb,_ = Textbox_with_label_left(fig[2,2][4,1:2], "# gridpoints [z]: ", nel_z, width=width);
    
    # Add buttons
    #fig[size_total[1][end-1], size_total[2][end   ]] = buttonplay = Button(fig, label = " ", width=Relative(1/1)) #GridLayout(tellwidth = false)
    #fig[size_total[1][end-1], size_total[2][end-1 ]] = buttonrun  = Button(fig, label = "Run", width=Relative(1/1)) #GridLayout(tellwidth = false)
    fig[2,2][size_total[1][end-1], 1]  = buttonrun  = Button(fig, label = "Run", width=Relative(1/1)) #GridLayout(tellwidth = false)
    fig[2,2][size_total[1][end-1], 2] = buttonplay = Button(fig, label = " ", width=Relative(1/1)) #GridLayout(tellwidth = false)

    # Add velocity toggle
    velocity_toggle,_ = Toggle_with_label_left(fig[2,2][size_total[1][end-3], 1:2], "Show velocity", false);

    # add Menu with fields to show:
    menu = Menu(fig[2,2][size_total[1][end-2], 1], options = ["phase","temperature"], default = "phase")
    if !isfile(OutFile*".pvd")
        # Create empty input file (as we are monitoring this)
        io = open(OutFile*".pvd", "w"); println(io, " "); close(io)
    else
        # input file exists (previous sim); read it
        update_fields_menu(OutFile, menu)       
        buttonplay.label="Play"
    end
    menu_comp = Textbox(fig[2,2][size_total[1][end-2], 2], placeholder = "1", stored_string="1")

    # Create initial heatmap
    dat = rand(11, 11)
    hm = heatmap!(ax, Vector(0.0:20.0),Vector(0.0:10.0),dat, colormap=colormap)
    #cb = Colorbar(fig[1:20, 5],  colormap=colormap, height = Relative(3/4), limits = (-1.0, 1.0)) # colorbar
    #cb = Colorbar(fig[1:20, 5],  colormap=colormap, height = Relative(3/4), limits = (-1.0, 1.0), vertical=false) # colorbar
    #cb = Colorbar(fig[size_total[1][end], size_ax[2]],  colormap=colormap, limits = (-1.0, 1.0), vertical=false) # colorbar
    cb = Colorbar(fig[2,1][size_ax[1]+1,size_ax[2]],  colormap=colormap, width = Relative(1/2), limits = (-1.0, 1.0), vertical=false) # colorbar
    #cb = Colorbar(fig[2,1][2,1],  hm,  width = Relative(1/2), vertical=false) # colorbar
    
    
    hm[3][] = zeros(11,11)

    # add arrows
    pt_arrow = Observable( [Makie.Point2f0(0,0)])
    vel_arrow = Observable([Makie.Vec2f0(0,0)])
    arr = arrows!(ax,pt_arrow, vel_arrow, color=:gray50, lengthscale = 2.0)

    # Store all GUI elements in a NamedTuple
    gui = ( timestep=lb_timestep, time=lb_time, hm=hm, cb=cb, menu_comp=menu_comp, menu=menu,
            nstep_max_tb=nstep_max_tb, buttonplay=buttonplay, buttonrun=buttonrun, velocity_toggle=velocity_toggle, 
            pt_arrow=pt_arrow, vel_arrow=vel_arrow, arrows=arr, menu_file=menu_file, nel_z=nel_z_tb); 
    
    # Read LaMEM results & update the plots
    function start_anim(OutFile, gui, hm, ax, fig)
        gui.buttonplay.label=" "
        t_step=0
        it = 0
        nstep_max = parse(Int,gui.nstep_max_tb.stored_string[])

        while t_step<nstep_max
            watch_file(OutFile*".pvd");
            revise()
           

            if (it==0) && (length(gui.menu.options[])==2)
                update_fields_menu(OutFile, gui.menu)   
            end
            it += 1
            
            # Update the plots etc.
            sleep(0.5)
            t_step, gui = update_plot_info(OutFile, gui, t_step, last=true)

            println("Timestep $t_step")
        end
        buttonplay.label="Play"
        buttonanim.label="Save animation"
        
        println("Simulation finished")

    end

    # Run LaMEM
    on(buttonrun.clicks) do n
        @info "Running LaMEM simulation"

        # Start the LaMEM simulation:
        run_code(ParamFile, gui; wait=false)  # run LaMEM in background

        # Update the plot & info windows
        @async start_anim(OutFile, gui, hm, ax, fig)

    end

    # Play animation
    on(buttonplay.clicks) do n
        Timestep, _, _ = Read_LaMEM_simulation(OutFile) # read all timesteps
        @async for it in Timestep
            gui.buttonplay.label="Play"
            # Update the plots etc.
            _,gui = update_plot_info(OutFile, gui, it, last=false)
        end
    end

    screen = display(GLMakie.Screen(),fig)
    glfw_window_main = to_native(screen)
    gui = (gui..., screen=screen)

    on(menu_file.selection) do select
        @info select
        if select=="Close window"
            GLFW.SetWindowShouldClose(glfw_window_main, true) 

        elseif select=="Save plot"
            plot_name, res = SavePlot_GUI(;fontsize=30, resolution=resolution)

            if !isnothing(plot_name)
                @show plot_name
                gui.menu_file.is_open=false
                save(plot_name, fig, resolution=res)
                display(fig)
            end
            
        elseif select=="Save animation"
            # open GUI that has animation parametere
            anim_data = SaveAnimation_GUI(;fontsize=30)

            Timestep, _, _ = Read_LaMEM_simulation(OutFile) # read all timesteps
            if !isnothing(anim_data)
                record(ax.scene, anim_data.Name, Timestep; framerate = anim_data.fps) do it
                    println("Creating animation; frame=$it")
                    _,gui =update_plot_info(OutFile, gui, it, last=false)
                end
            end
            
        else

        end
        gui.menu_file.i_selected=1

    end

    return fig, ax, gui 
end

struct AnimationData
    fps::Int64
    Name::String
end



"""
    out = SaveAnimation_GUI(;fontsize=30)

This opens a GUI where you can specify animation info. Once you are done with it you either cancel the window (`out=nothing`), or save it 
"""
function SaveAnimation_GUI(;fontsize=30)

    fig_anim = Figure(fontsize=fontsize)

    fps_tb,_ = Textbox_with_label_left(fig_anim[1, 1:2], "Frames/second: ", 10)
    filename_tb,_ = Textbox_with_label_left(fig_anim[2, 1:2], "FileName: ", "Animation_1")
    Label(fig_anim[3, 1],text="FileType:")
    men_type = Menu(fig_anim[3, 2], options = ["mp4","gif"], default = "mp4")

    buttoncancel = Button(fig_anim[4, 1], label = "Cancel", width=Relative(1/1)) #GridLayout(tellwidth = false)
    buttonsave   = Button(fig_anim[4, 2], label = "Save", width=Relative(1/1)) #GridLayout(tellwidth = false)

    screen_anim = display(GLMakie.Screen(),fig_anim)
    glfw_window_anim = to_native(screen_anim)

    out = nothing
    on(buttoncancel.clicks) do n
        # close window, do nothing
        GLFW.SetWindowShouldClose(glfw_window_anim, true) 
    end

    on(buttonsave.clicks) do n
        ending = men_type.options[][men_type.i_selected[]]
        filename =  filename_tb.displayed_string[]*"."*ending
        fps =  parse(Int64,fps_tb.displayed_string[])
        
        anim_dat = AnimationData(fps, filename)
        out= anim_dat
        GLFW.SetWindowShouldClose(glfw_window_anim, true) 
    end
    
    wait(screen_anim)
    return out
end


"""
    out = SavePlot_GUI(;fontsize=30)

This opens a GUI where you can specify plot info. Once you are done with it you either cancel the window (`out=nothing`), or save it 
"""
function SavePlot_GUI(;fontsize=30, resolution=(1000,1000))

    fig_plot = Figure(fontsize=fontsize)

    res_string = String("$(resolution)")[2:end-1]
    @show res_string
    res_tb,_ = Textbox_with_label_left(fig_plot[1, 1:2], "Resolution (dpi): ", res_string)
    filename_tb,_ = Textbox_with_label_left(fig_plot[2, 1:2], "FileName: ", "Plot_1")
    Label(fig_plot[3, 1],text="FileType:")
    men_type = Menu(fig_plot[3, 2], options = ["png","jpeg","bmp"], default = "png")

    buttoncancel = Button(fig_plot[4, 1], label = "Cancel", width=Relative(1/1)) #GridLayout(tellwidth = false)
    buttonsave   = Button(fig_plot[4, 2], label = "Save", width=Relative(1/1)) #GridLayout(tellwidth = false)

    screen_plot = display(GLMakie.Screen(),fig_plot)
    glfw_window_plot = to_native(screen_plot)

    out = nothing
    on(buttoncancel.clicks) do n
        # close window, do nothing
        GLFW.SetWindowShouldClose(glfw_window_plot, true) 
    end

    on(buttonsave.clicks) do n
        ending = men_type.options[][men_type.i_selected[]]
        filename =  filename_tb.displayed_string[]*"."*ending
        resolution =  Tuple(parse.(Int,split(res_tb.stored_string[],",")))
        
        out = filename
        GLFW.SetWindowShouldClose(glfw_window_plot, true) 
    end
    
    wait(screen_plot)
    return out, resolution
end

