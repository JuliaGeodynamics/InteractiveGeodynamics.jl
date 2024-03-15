using DelimitedFiles


"""
Returns an accordion menu containing the rheological parameters.
"""
function make_rheological_parameters()
    return dbc_accordionitem(title="Rheological Parameters", [
        make_accordion_item("log₁₀(η_slab [Pa⋅s]):", "viscosity_slab", "Logarithm of the viscosity of the slab.", 23.3, 16.0, 25.0),
        dbc_row(html_p()),
        make_accordion_item("(log₁₀(η_mantle [Pa⋅s]):", "viscosity_mantle", "Logarithm of the viscosity of the mantle", 21.0, 16.0, 23.0),
        dbc_row(html_p()),
        make_accordion_item("log₁₀(η_crust [Pa⋅s]):", "viscosity_crust", "Logarithm of the viscosity of the crust", 21.0, 16.0, 23.0),
        dbc_row(html_p()),
        make_accordion_item("σ_yield_crust [Pas]:", "yield_stress_crust", "Yield stress of the crust",1000, 1, 1000.0),
    ])
end

"""
Returns an accordion menu containing the simulation parameters.
"""
function make_simulation_parameters()
    return dbc_accordionitem(title="Simulation Parameters", [
        make_accordion_item("Slab Thickness (km):", "slab_thickness", "Full slab thickness given in kilometers.", 80.0, 1.0e-10),
        dbc_row(html_p()),
        make_accordion_item("Crust Thickness (km):", "crust_thickness", "Crust thickness given in kilometers.", 15.0, 1.0e-10),
        dbc_row(html_p()),
        #make_accordion_item("nx:", "nel_x", "Number of elements in the x-direction. Must be an integer greater than 2.", 64, 2),
        #dbc_row(html_p()),
        make_accordion_item("nz:", "nel_z", "Number of elements in the z-direction. Must be an integer greater than 2.  nx=4*nz", 64, 2),
        dbc_row(html_p()),
        
        make_accordion_item("nt:", "n_timesteps", "Maximum number of timesteps. Must be an integer greater than 1.", 50, 1),
        dbc_row(html_p()),
        dbc_row([
            dbc_checklist(options=["activate free surface"],
                    id="switch-FreeSurf",
                    switch=true,
            )
        ]),
      #  dbc_row(html_p()),
      #  dbc_row([
      #      dbc_checklist(options=["Layers"],
      #              id="switch-Layers",
      #              switch=true,
      #      )
      #  ])
    ])
end

#=
"""
Creates a setup with noisy temperature and one phase
"""
function CreateSetup(ParamFile, layered_overburden=false, Hi=-5.0, ampl_noise=0.1, ; args)
    Grid        =   read_LaMEM_inputfile(ParamFile, args=args)
    Phases      =   zeros(Int64, size(Grid.X));      
    Temp        =   zeros(Float64,size(Grid.X));  
    

    if layered_overburden
        H_layer = 0.25;
        for z_low = minimum(Grid.Z):2*H_layer:maximum(Grid.Z)
            # print(z_low)
            # z_low = -z_low
            iz =  (Grid.Z[1,1,:] .> z_low) .&  (Grid.Z[1,1,:] .<= (z_low+H_layer) ) 
            Phases[:,:,iz] .= 1;
        end 
    end
   
    z_int = [Hi + rand()*ampl_noise for _ in 1:Grid.nump_x]
    # print(z_int)
    # z_int       =   -z_int
    for ix=1:Grid.nump_x, iy=1:Grid.nump_y
        iz = Grid.Z[ix,iy,:] .< z_int[ix] 
        Phases[ix,iy,iz] .= 2;
    end

    # print(z_int)

    Model3D     =   CartData(Grid, (Phases=Phases,Temp=Temp))   # Create LaMEM model
    write_paraview(Model3D,"LaMEM_ModelSetup", verbose=false)   # Save model to paraview   (load with opening LaMEM_ModelSetup.vts in paraview)  

    save_LaMEM_markers_parallel(Model3D, directory="./markers", verbose=false)   # save markers on one core

    return nothing
end
=#