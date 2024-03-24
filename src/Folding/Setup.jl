# Main setup

using GeophysicalModelGenerator, LaMEM

"""
Creates a polygon with a layer
"""
function create_layer(model::Model; nx=50, A0_sin=1e-5, A0_rand=1e-4, z_cen = 0.0, H0=1e-2)
    
    x = Vector(range(extrema(model.Grid.Grid.x_vec)..., length=nx))
    W =  model.Grid.Grid.W

    poly_x = [x; x[end:-1:1]]
    poly_z = [-H0/2 .+ A0_sin*cos.(2π*x/W); H0/2 .+ A0_sin*cos.(2π*x[end:-1:1]/W)];

    poly_z .+= rand(2*nx)*A0_rand   # add random noise
    poly_z .+= z_cen                # shift

    # close polygon
    push!(poly_x, poly_x[1])
    push!(poly_z, poly_z[1])
    
    return poly_x, poly_z
end

"""

"""
function create_model_setup(; nx=64, nz=64,  W=0.2, H=0.2, Number_layers=1, H0=1e-2, A0_rand=1e-3, A0_sin=0, Spacing = 5e-2, eta_matrix=1e20, eta_fold=1e22,
    OutFile="Folding", nstep_max=100, DirectPenalty=1e4, dt_max=0.25, ε=1e-15)

    model = Model(  # Define the grid
                    Grid(nel=(nx,nz), x=[-W/2, W/2], z=[-H/2 , H/2]),

                    # No slip lower boundary; the rest is free slip
                    BoundaryConditions(exx_strain_rates=[-ε]),

                    SolutionParams(eta_ref=eta_matrix),
                    
                    # We use a multigrid solver with 4 levels:
                    Solver(SolverType="direct", DirectSolver="mumps",DirectPenalty=DirectPenalty,
                                PETSc_options=[ "-snes_ksp_ew",
                                                "-snes_ksp_ew_rtolmax 1e-4",
                                ]),

                    # Output filename
                    LaMEM.Output(out_file_name=OutFile),

                    # Timestepping etc
                    Time(nstep_max=nstep_max, nstep_out=5, time_end=100, dt_min=1e-8),

                    # Scaling:
                    Scaling(GEO_units(length=1km, stress=1e9Pa) )
                )
  
                
    # Add fold(s)

    # compute center of folds
    z_bot = 0 - (H0+Spacing)*floor((Number_layers+1))/2 + (H0+Spacing)
    z_top = 0 + (H0+Spacing)*floor((Number_layers+1))/2 - (H0+Spacing)
    z_center = Vector(z_bot:(H0+Spacing):z_top)

    Phases = model.Grid.Phases[:,1,:]
    for z_cen in z_center
        poly_x, poly_z = create_layer(model, A0_sin=A0_sin, A0_rand=A0_rand, z_cen=z_cen, H0=H0)    # fold polygon
    
        # Determine points that are inside the fold
        INSIDE=zeros(Bool, size(model.Grid.Grid)[1], size(model.Grid.Grid)[3]);
        X = model.Grid.Grid.X[:,1,:]
        Z = model.Grid.Grid.Z[:,1,:]
        inpolygon!(INSIDE, poly_x, poly_z, X, Z; fast=false)
    
        Phases[INSIDE] .= 1;
    end

    for i = 1:size(model.Grid.Grid)[2]
        model.Grid.Phases[:,i,:] = Phases
    end

    # Add rheology
    @info "Adding rheology" eta_matrix, eta_fold
    matrix = Phase(Name="matrix", ID=0, eta=eta_matrix,   rho=2700)
    fold   = Phase(Name="fold",   ID=1, eta=eta_fold,     rho=2700)

    add_phase!(model, matrix, fold)

    return model
end