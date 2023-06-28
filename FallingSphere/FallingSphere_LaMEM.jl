using GLMakie
using GeophysicalModelGenerator

Makie.inline!(true)


include("../src/widgets.jl")
include("../src/Basic_LaMEM_GUI.jl")

clean_directory()

# Define the simulation name & the output files: 
ParamFile  = "FallingSphere.dat"
OutFile    = "FallSphere"
resolution = primary_resolution()
width =  round(Int,resolution[1]/11);

if Sys.isapple()
    resolution = (1900,1400)
    fontsize   = 30
    height_widgets = Auto();
elseif Sys.iswindows()
    fontsize   = 10
    height_widgets = 25;
    resolution=(1300,900)

else
 #   resolution = (1200,800)
    fontsize   = 10
    height_widgets = Auto();
    resolution=nothing

end

# Create Basic GUI
fig, ax, gui = Create_Basic_LaMEM_GUI(OutFile, ParamFile, resolution=resolution, fontsize=fontsize, width=width, height=height_widgets, show_velocity_toggle=false);
ax.title =  "Rising Sphere Setup"
gui.txt_time.text[]="maximum z velocity [cm/yr]: "


# Add textboxes:
rho_m,_ = Textbox_with_label_left(fig[2,2][5, 1:2], L"ρ_{\mathrm{matrix}} \mathrm{  [kg/m³]}", "3000", width=width, height=height_widgets);
rho_s,_ = Textbox_with_label_left(fig[2,2][6, 1:2], L"ρ_{\mathrm{sphere}} \mathrm{  [kg/m³]}", "2800", width=width, height=height_widgets);
R,_ = Textbox_with_label_left(fig[2,2][7, 1:2], L"\mathrm{Radius [km]}", "0.1", width=width, height=height_widgets);
Width,_ = Textbox_with_label_left(fig[2,2][8, 1:2], L"\mathrm{Width [km]}", "2", width=width, height=height_widgets);

# Add sliders:
eta_m_sl, _, _ = Slider_with_text_above(fig[2,2][9:10,1:2], L"\log_{10}(\eta_{\mathrm{matrix}} \mathrm{  [Pas]})", 16:.1:20, 18, height=height_widgets);
eta_s_sl, _, _ = Slider_with_text_above(fig[2,2][11:12,1:2], L"\log_{10}(\eta_{\mathrm{sphere}} \mathrm{  [Pas]})", 19:.1:25, 22, height=height_widgets);

# Toggle
vel_sl, _, _ = Slider_with_text_above(fig[2,2][14:15,1:2], "Arrow length", 0.1:1:50, 10, height=height_widgets);

#FreeSurf,_ = Toggle_with_label_left(fig[2,2][13, 1:2], L"\mathrm{FastErosionUpperBoundary}", false, height=height_widgets);
#Layers,_ = Toggle_with_label_left(fig[2,2][14, 1:2], L"\mathrm{LayeredOverburden}", true, height=height_widgets);


function update_info(gui::NamedTuple, values::NamedTuple)
    pad_space = 15
    gui.time.displayed_string[] = rpad(string(round(values.maxVz[1]; digits=6)),pad_space)
    gui.timestep.displayed_string[] = rpad(string(values.t_step),pad_space)

    return nothing
end

# Basic code

function update_plot_info_basic(OutFile, gui::NamedTuple, t_step::Int64; last=false)
        
    # Load LaMEM result
    if last
        Timestep, _, _ = Read_LaMEM_simulation(OutFile)
        t_step = Timestep[end]
    end

    data, time = Read_LaMEM_timestep(OutFile, t_step, last=last);

    vel  =  data.fields.velocity; #velocity
    Vz   =  vel[3,:,:,:] # Vz

    # update info window
    values = (t_step=t_step, time=time, maxVz=maximum(Vz));
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

    # plot velocity arrows if requested
    num_z = 50;
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

    # scale length of arrow
    gui.arrows.visible[]=true
    gui.arrows.lengthscale= vel_sl.value[]
    
    display(fig)
    sleep(1/60)

    return t_step, data
end

# Run the LaMEM simulation (modify some parameters if you want) 
function run_code(ParamFile, gui; wait=true)

    nel_x,nel_z = retrieve_resolution(ParamFile, gui)
    
    Hi_value =  parse(Float64,Hi.displayed_string[])
    W        =  parse(Float64,Width.displayed_string[])

    η_m =  10.0^eta_m_sl.value[]
    η_s =  10.0^eta_s_sl.value[]
    ρ_m  =  parse(Float64,rho_m.displayed_string[])
    ρ_s  =  parse(Float64,rho_s.displayed_string[])
   # FreeSurf.active[] ?   open_top = 1 :   open_top = 0
   # Layers.active[] ?    layers = true :   layers = false

    # Retrieve some parameters from the GUI
    nstep_max_val = parse(Int64,gui.nstep_max_tb.displayed_string[])
    
    # command-line arguments
    args = "-nstep_max $(nstep_max_val) -eta[0] $η_m -eta[1] $η_s -rho[0] $ρ_m -rho[1] $ρ_s  -nel_x $nel_x -nel_z $nel_z -coord_x $(-W/2),$(W/2) -coord_z $(-W/2),$(W/2)"
    @show args

    # Create the setup
    #CreateSetup(ParamFile, layers, Hi_value, args=args)
    @info "created marker setup"

    # Run LaMEM with these parameters
    @show args
    run_lamem(ParamFile, 1, args, wait=wait)
end

#screen = display(GLMakie.Screen(), fig)
#gui = (gui..., screen=screen)


#SaveAnimation_GUI(;fontsize=30)
