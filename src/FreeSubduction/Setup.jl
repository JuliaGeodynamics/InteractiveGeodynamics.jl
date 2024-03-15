# Main setup

using GeophysicalModelGenerator, LaMEM


function create_model_setup(; nz=64, SlabThickness=80, eta_slab=2e23, eta_mantle=1e21, eta_crust=1e21, C_crust=10, OutFile="FreeSubduction", nstep_max=30)
    model = Model(  # Define the grid
                    Grid(nel=(nz*4,nz), x=[-1200, 1200], z=[-660 ,0]),

                    # No slip lower boundary; the rest is free slip
                    BoundaryConditions(noslip = [0, 0, 0, 0, 1, 0]),

                    # We use a multigrid solver with 4 levels:
                    Solver(SolverType="direct", MGLevels=4, DirectSolver="mumps"),

                    # Output filename
                    LaMEM.Output(out_file_name=OutFile),

                    # Timestepping etc
                    Time(nstep_max=nstep_max, nstep_out=5, time_end=100, dt_min=1e-5),

                    # Scaling:
                    Scaling(GEO_units(length=1km, stress=1e9Pa) )
                )

    crust = 20;                
    lith = LithosphericPhases(Layers=[crust,SlabThickness-crust], Phases=[1,2]);
    
    # Add geometry
    add_box!(model, xlim=(-900,200), zlim=(-SlabThickness,0), phase=lith)
    
    # Add curved trench
    trench = Trench(Start=(200.0,-100.0), End=(200.0,100.0), Thickness=SlabThickness, θ_max=45.0, Length=300, Lb=200);
    add_slab!(model, trench, phase=lith);

    # Add rheology
    @info "Adding rheology" eta_mantle, eta_crust, eta_slab, C_crust
    mantle = Phase(Name="mantle",ID=0, eta=eta_mantle,   rho=3200)
    crust  = Phase(Name="crust", ID=1, eta=eta_crust,    rho=3280, ch=C_crust)
    slab   = Phase(Name="slab",  ID=2, eta=eta_slab,     rho=3280)
    add_phase!(model, mantle, slab, crust)

    return model
end