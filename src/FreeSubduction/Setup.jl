# Main setup

using GeophysicalModelGenerator, LaMEM


function create_model_setup(; nz=64, SlabThickness=80, CrustThickness=15, eta_slab=2e23, eta_mantle=1e21, eta_crust=1e21, 
    C_crust=10, OutFile="FreeSubduction", nstep_max=100, DirectPenalty=1e4, free_surface=false, dt_max=0.25)

    if free_surface
        Air = 40
        open_top_bound = 1
    else
        Air = 0
        open_top_bound = 0
    end

    model = Model(  # Define the grid
                    Grid(nel=(nz*4,nz), x=[-1200, 1200], z=[-660 ,Air]),

                    # No slip lower boundary; the rest is free slip
                    BoundaryConditions(noslip = [0, 0, 0, 0, 1, 0], open_top_bound=open_top_bound),

                    SolutionParams(eta_ref=eta_mantle),
                    
                    # We use a multigrid solver with 4 levels:
                    Solver(SolverType="direct", DirectPenalty=DirectPenalty,
                                PETSc_options=[ "-js_ksp_monitor",
                                                "-snes_ksp_ew",
                                                "-snes_ksp_ew_rtolmax 1e-4",
                                ]),
                    # Free FreeSurface
                    FreeSurface(surf_use=open_top_bound),

                    # Output filename
                    LaMEM.Output(out_file_name=OutFile),

                    # Timestepping etc
                    Time(nstep_max=nstep_max, nstep_out=5, time_end=100, dt_min=1e-8, dt_max=dt_max),

                    # Scaling:
                    Scaling(GEO_units(length=1km, stress=1e9Pa) )
                )

    lith = LithosphericPhases(Layers=[CrustThickness,SlabThickness-CrustThickness], Phases=[2,3]);
    
    # Add mantle
    add_layer!(model, zlim=(-1000.0,0), phase=ConstantPhase(1))
    
    # Add geometry
    add_box!(model, xlim=(-900,200), zlim=(-SlabThickness,0), phase=lith)
    
    # Add curved trench
    trench = Trench(Start=(200.0,-100.0), End=(200.0,100.0), Thickness=SlabThickness, θ_max=45.0, Length=300, Lb=200);
    add_slab!(model, trench, phase=lith);

    # add stripes
    add_stripes!(model,stripAxes=(1,0,1), stripeWidth=20, stripeSpacing=40, phase=ConstantPhase(3), stripePhase=ConstantPhase(4))

    # Add rheology
    @info "Adding rheology" eta_mantle, eta_crust, eta_slab
    air    = Phase(Name="Air",          ID=0, eta=eta_mantle/10, rho=10)
    mantle = Phase(Name="mantle",       ID=1, eta=eta_mantle,    rho=3200)
    crust  = Phase(Name="crust",        ID=2, eta=eta_crust,     rho=3280)
    slab   = Phase(Name="slab",         ID=3, eta=eta_slab,      rho=3280)
    slab2  = Phase(Name="slab_stripe",  ID=4, eta=eta_slab,      rho=3280)
    

    add_phase!(model, air, mantle, slab, slab2, crust)

    return model
end