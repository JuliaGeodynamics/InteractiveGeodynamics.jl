using GLMakie
using GeophysicalModelGenerator

Makie.inline!(true)


include("../src/widgets.jl")
include("../src/Basic_LaMEM_GUI.jl")

clean_directory()

# Define the simulation name & the output files: 
ParamFile  = "RTI.dat"
OutFile    = "RTI"
resolution = primary_resolution()
width =  round(Int,resolution[1]/11);

if Sys.isapple()
    resolution = (1900,1400)
    fontsize   = 30
else
 #   resolution = (1200,800)
    fontsize   = 10

end
#width=160;
resolution=nothing
#fontsize=nothing

# Create Basic GUI
fig, ax, gui = Create_Basic_LaMEM_GUI(OutFile, ParamFile, resolution=resolution, fontsize=fontsize, width=width);
ax.title =  "Rayleigh Taylor Instability"

# Add textboxes:
rho_up,_ = Textbox_with_label_left(fig[2,2][5, 1:2], L"ρ_{\mathrm{upper}} \mathrm{  [kg/m³]}", "2800", width=width);
rho_lo,_ = Textbox_with_label_left(fig[2,2][6, 1:2], L"ρ_{\mathrm{lower}} \mathrm{  [kg/m³]}", "2200", width=width);
Hi,_ = Textbox_with_label_left(fig[2,2][7, 1:2], L"H_{\mathrm{interface}} \mathrm{  [km]}", "-3.5", width=width);
Width,_ = Textbox_with_label_left(fig[2,2][8, 1:2], L"\mathrm{Width [km]}", "10", width=width);

# Add sliders:
eta_up_sl, _, _ = Slider_with_text_above(fig[2,2][9:10,1:2], L"\log_{10}(\eta_{\mathrm{upper}} \mathrm{  [Pas]})", 18:.1:22, 20);
eta_lo_sl, _, _ = Slider_with_text_above(fig[2,2][11:12,1:2], L"\log_{10}(\eta_{\mathrm{lower}} \mathrm{  [Pas]})", 18:.1:22, 18);

# Toggle
FreeSurf,_ = Toggle_with_label_left(fig[2,2][13, 1:2], L"\mathrm{FastErosionUpperBoundary}", false);
Layers,_ = Toggle_with_label_left(fig[2,2][14, 1:2], L"\mathrm{LayeredOverburden}", true);


# Create setup
function CreateSetup(ParamFile, layered_overburden=false, Hi=-5.0, ampl_noise=0.1, ; args)
    Grid        =   ReadLaMEM_InputFile(ParamFile, args=args)
    Phases      =   zeros(Int64, size(Grid.X));      
    Temp        =   zeros(Float64,size(Grid.X));     

    if layered_overburden
        H_layer = 0.25;
        for z_low = minimum(Grid.Z):2*H_layer:maximum(Grid.Z)
            iz = findall( (Grid.Z[1,1,:] .> z_low) .&  (Grid.Z[1,1,:] .<= (z_low+H_layer) )) 
            Phases[:,:,iz] .= 1;
        end 
    end
   
    z_int       =   ones(Grid.nump_x)*Hi + rand(Grid.nump_x)*ampl_noise
    for ix=1:Grid.nump_x, iy=1:Grid.nump_y
        iz = findall(Grid.Z[ix,iy,:] .< z_int[ix] )
        Phases[ix,iy,iz] .= 2;
    end

    Model3D     =   CartData(Grid, (Phases=Phases,Temp=Temp))   # Create LaMEM model
    Write_Paraview(Model3D,"LaMEM_ModelSetup", verbose=false)   # Save model to paraview   (load with opening LaMEM_ModelSetup.vts in paraview)  

    Save_LaMEMMarkersParallel(Model3D, directory="./markers", verbose=false)   # save markers on one core

    return nothing
end

# Run the LaMEM simulation (modify some parameters if you want) 
function run_code(ParamFile, gui; wait=true)

    nel_x,nel_z = retrieve_resolution(ParamFile, gui)
    
    Hi_value =  parse(Float64,Hi.displayed_string[])
    W        =  parse(Float64,Width.displayed_string[])

    η_up =  10.0^eta_up_sl.value[]
    η_lo =  10.0^eta_lo_sl.value[]
    ρ_up =  parse(Float64,rho_up.displayed_string[])
    ρ_lo =  parse(Float64,rho_lo.displayed_string[])
    FreeSurf.active[] ?   open_top = 1 :   open_top = 0
    Layers.active[] ?    layers = true :   layers = false

    
    # Retrieve some parameters from the GUI
    nstep_max_val = parse(Int64,gui.nstep_max_tb.displayed_string[])
    
    # command-line arguments
    args = "-nstep_max $(nstep_max_val) -eta[0] $η_up -eta[1] $η_up -eta[2] $η_lo -rho[0] $ρ_up -rho[1] $ρ_up -rho[2] $ρ_lo -open_top_bound $open_top -nel_x $nel_x -nel_z $nel_z -coord_x $(-W/2),$(W/2) "

    # Create the setup
    CreateSetup(ParamFile, layers, Hi_value, args=args)
    @info "created marker setup"

    # Run LaMEM with these parameters
    run_lamem(ParamFile, 1, args, wait=wait)
end

#screen = display(GLMakie.Screen(), fig)
#gui = (gui..., screen=screen)


#SaveAnimation_GUI(;fontsize=30)
