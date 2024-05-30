using GeoParams
using ForwardDiff, SparseArrays, SparseDiffTools, LinearAlgebra, Interpolations

av(x) = (x[2:end]+x[1:end-1])/2


"""
    init_model(;nz=101, L=40e3, Geotherm=0, Ttop=400.0, Tbot=0.0, Δt=1e3*SecYear, MatParam=nothing)

Create initial model setup
"""
function init_model(;nz=101, L=40e3, Geotherm=0, Ttop=400.0, Tbot=0.0, Δt=1e3*SecYear, MatParam=nothing)
    if isnothing(MatParam)
        MatParam     = (SetMaterialParams(Name="RockMelt", Phase=0, 
                            Density         = ConstantDensity(ρ=2700kg/m^3),                            # used in the parameterisation of Whittington 
                            LatentHeat      = ConstantLatentHeat(Q_L=2.55e5J/kg),
                            RadioactiveHeat = ExpDepthDependentRadioactiveHeat(H_0=0e-7Watt/m^3),
                            Conductivity    = T_Conductivity_Whittington(),                             #  T-dependent k
                            HeatCapacity    = T_HeatCapacity_Whittington(),                             # T-dependent cp
                            Melting         = MeltingParam_Assimilation()                               # Quadratic parameterization as in Tierney et al.
                            ),
                    )
    end

    # Numerics
    Told        =   zeros(nz)
    T           =   zeros(nz)
    ρ           =   zeros(nz)
    Cp          =   zeros(nz)
    dϕdT        =   zeros(nz)
    ϕ           =   zeros(nz)
    Hl          =   zeros(nz)    
    k           =   zeros(nz-1)  
    dz          =   L/(nz-1)
    z           =   -L:dz:0
    T           =   -Geotherm/1e3.*Vector(z) .+ Ttop

    Phases      =   fill(0,nz)
    Phases_c    =   fill(0,nz-1)

    Params      =   (; Δt, k, ρ, Cp, dϕdT, ϕ, Hl, Told, Phases, Phases_c, MatParam, z)
    N           =   (nz,)
    BC          =   (; Ttop, Tbot)
    Δ           =   (dz,)

    return Params, BC, N, Δ, T, z
end

"""
    Res!(F::AbstractArray, T::AbstractArray, Δ, N, BC)
"""
function Res!(F::AbstractVector{_T}, T::AbstractVector{_T}, Δ::NTuple, N::NTuple, BC::NamedTuple, Params::NamedTuple, MatParam) where _T<:Number

    dz     = Δ[1]       # grid spacing
    nz     = N[1]       # grid size

    # Update material properties
    args        = (T = Params.Told .+273.15,  )
    args_c      = (T = av(Params.Told) .+273.15, )
    compute_conductivity!(Params.k, MatParam, Params.Phases_c, args_c)
    compute_heatcapacity!(Params.Cp, MatParam, Params.Phases, args)
    compute_density!(Params.ρ, MatParam, Params.Phases, args)
    compute_dϕdT!(Params.dϕdT, MatParam, Params.Phases, args) 
    compute_meltfraction!(Params.ϕ, MatParam, Params.Phases, args) 
    compute_latent_heat!(Params.Hl, Params.MatParam, Params.Phases, args)   

    I          = 2:nz-1
    #  ρ(Cp + Hₗ∂ϕ/∂T) ∂T/∂t = ∂/∂z(k ∂T/∂z) 
    F[2:end-1] = Params.ρ[I].*(Params.Cp[I]  + Params.Hl[I].*Params.dϕdT[I]).*(T[I]-Params.Told[I])/Params.Δt  -   diff(Params.k .* diff(T)/dz)/dz;

    F[1]  = T[1]  - BC.Tbot
    F[nz] = T[nz] - BC.Ttop
    
    return F
end
Res_closed! = (F,T) -> Res!(F, T, Δ, N, BC, Params, MatParam)   

function LineSearch(func::Function, F, x, δx;  α = [0.01 0.05 0.1 0.25 0.5 0.75 1.0])
    Fnorm = zero(α)
    N     = length(x)
    for i in eachindex(α)
        func(F, x .+ α[i].*δx)
        Fnorm[i] = norm(F)/N
    end
    _, i_opt = findmin(Fnorm)
    return α[i_opt], Fnorm[i_opt]
end


"""
    Usol = nonlinear_solution(Fup::Vector, U::Vector{<:AbstractArray}, J, colors; tol=1e-8, maxit=100)

Computes a nonlinear solution using a Newton method with line search.
`U` needs to be a vector of abstract arrays, which contains the initial guess of every field 
`J` is the sparse jacobian matrix, and `colors` the coloring matrix, usually computed with `matrix_colors(J)`
"""
function nonlinear_solution(Fup::Vector, T::Vector, J, colors; tol=1e-8, maxit=100, verbose=true,
                            Δ, N, BC, Params, MatParam)
    
    Res_closed! = (F,T) -> Res!(F, T, Δ, N, BC, Params, MatParam)  
   
    r   = zero(Fup)
    err = 1e3; it=0;
    while err>tol && it<maxit
        Res_closed!(r,T)     # compute residual

        forwarddiff_color_jacobian!(J, Res_closed!, T, colorvec = colors) # compute jacobian in an in-place manner
       
        dT      =   J\-r    # solve linear system:
        α, err  =   LineSearch(Res_closed!, r, T, dT); # optimal step size
        T       +=   α*dT   # update solution
        it      +=1;
        if verbose; println("   Nonlinear iteration $it: error = $err, α=$α"); end
    end

    converged=false

    return T, converged, it
end


function time_stepping(T, nt, Params, N, Δ, BC, MatParam; verbose=false, OutDir="test", OutFile="Thermal1D", PlotData=nothing)
    
    # create a function with only 1 input parameter
    CurDir = pwd()
    if !isnothing(OutDir)
        cd(OutDir)
    end
    # Initial sparsity pattern of matrix
    nz          = N[1]
    J1          = Tridiagonal(ones(nz-1), ones(nz), ones(nz-1))
    J1[1,2]=0; J1[2,1]=0; J1[nz-1,nz]=0; J1[nz,nz-1]=0
    Jac         =   sparse(Float64.(abs.(J1).>0))
    colors      =   matrix_colors(Jac) 

    io = open("$OutFile.pvd", "w")
    
    time_yrs = 0.0
   
    #Tline = Observable(Point2f.(T, Params.z/1e3))
 


#    lines!(PlotData.ax1, Tline, color = :green)
    PlotData.ax1.title="time=$(time_yrs)"

    F = zero(T)
    time = 0.0
    SecYear = 3600*24*365.25
    for it in 1:nt
        
        T,  converged, its = nonlinear_solution(F, T, Jac, colors, verbose=verbose, Δ=Δ, N=N, BC=BC, Params=Params, MatParam=MatParam)
        Params.Told .= T
        @show extrema(T), extrema(Params.ϕ)

        time += Params.Δt
        time_yrs = time/SecYear

        # save file to disk
        if mod(it,1)==0  & !isnothing(OutDir)
            jldsave("test_$(it+10000).jld2"; Params.z, T, Params.ϕ, time)
            writedlm(io, [it, time]) # update timestep in pvd file (really just a trick for the GUI)
        end
        if isnothing(OutDir)
            empty!(PlotData.ax1)
            lines!(PlotData.ax1, T, Params.z/1e3, color=:red)
            PlotData.ax1.title = "$time_yrs years"
            display(PlotData.fig)
        end 


        
        @show time_yrs
    end
    if !isnothing(OutDir)
        close(io)
    end
    cd(CurDir)

    return T, Params.ϕ, time
end

crack_perp_displacement(z, d; r=5e3) = d.*(1.0 .- abs.(z)./(sqrt.(r^2 .+ z.^2)))

"""
    Tadv = insert_sill!(T,z; Sill_thick=400, Sill_z0=-20e3, Sill_T=1200, SillType=:constant)

Adds a sill to the setup, using a 1D WENO5 advection scheme for a given temperature field `T` on a grid `z`.
Optional parameters are the sill thickness `Sill_thick`, the sill center `Sill_z0`, the sill temperature `Sill_T`. 
Advection is done by `SillType`, which can be `:constant` (where rocks above/below are moved with constant displacement 
or `:elastic`, where the displacement decreases with distance from the sill.
"""
function insert_sill(T,rocks, z; Sill_thick=400, Sill_z0=-20e3, Sill_T=1200, Sill_phase=1.0, SillType=:elastic)

    # find points above & below sill emplacement level
    z_shift = Vector(z) .-  Sill_z0;
    Displ   = zero(z_shift)
    
    # shift points above
    id_above = findall(z_shift.>0)
    id_below = findall(z_shift.<0)
    
    # Assume constant displacement - in elastic case this should decrease with distance from sill
    if SillType==:constant
        Displ[id_above]  .= Sill_thick
        Displ[id_below]  .= -Sill_thick
    elseif SillType==:elastic
        R = 5e3;
        Displ[id_above]  .=  crack_perp_displacement(z_shift[id_above], Sill_thick; r=R)
        Displ[id_below]  .= -crack_perp_displacement(z_shift[id_below], Sill_thick; r=R)
    end

    # use WENO5 to advect the temperature field
    T_adv = semilagrangian_advection(T, Displ, z)

    # set sill temperature
    ind = findall( abs.(z .- Sill_z0) .<= Sill_thick/2)
    T_adv[ind]  .= Sill_T

    # use WENO5 to advect the rock field
    rock_adv = semilagrangian_advection(rocks, Displ, z)
    rock_adv[ind]  .= Sill_phase
    rock_adv    = ceil.(rock_adv)

    return T_adv, rock_adv
end

"""
    Tadv = semilagrangian_advection(T, Displ, z)
Do semilagrangian_advection
"""
function semilagrangian_advection(T, Displ, z)

    z_new = z + Displ # advect grid
    interp_linear = linear_interpolation(z_new, T);
    T_adv = interp_linear.(z)

    return T_adv
end




#=
nz          = 101
L           = 40e3
Geotherm    = 0;  # K/km
Ttop        = 400.0
Tbot        = L/1e3*Geotherm
SecYear     = 3600*24*365.25
Δt          = 1e3*SecYear


MatParam     = (SetMaterialParams(Name="RockMelt", Phase=0, 
                                    Density         = ConstantDensity(ρ=2700kg/m^3),                            # used in the parameterisation of Whittington 
                                    LatentHeat      = ConstantLatentHeat(Q_L=2.55e5J/kg),
                                    RadioactiveHeat = ExpDepthDependentRadioactiveHeat(H_0=0e-7Watt/m^3),
                                    Conductivity    = T_Conductivity_Whittington(),                             #  T-dependent k
                                    HeatCapacity    = T_HeatCapacity_Whittington(),                             # T-dependent cp
                                    Melting         = MeltingParam_Assimilation()                               # Quadratic parameterization as in Tierney et al.
),)

# Params, BC, N, Δ, T, z = init_model(nz=nz, L=L, Geotherm=Geotherm, Ttop=Ttop, Tbot=Tbot, Δt=Δt, MatParam=MatParam)


#N_2 = floor(Int64,(nz-1)/2)
#T[N_2-3:N_2+3] .+= 500
#Params.Told .= T



nt = 2
T, ϕ, t =  time_stepping(T, nt, Params, N, Δ, BC, MatParam, verbose = false)



fig = make_subplots(
    rows=1, cols=2,
    column_widths=[0.6, 0.4],
    row_heights=[1.0],
    specs=[
        Spec(kind= "xy") Spec(kind="xy")
    ]
)


add_trace!(
    fig,
    scatter(x=T,y=z/1e3),
    row=1, col=1)

add_trace!(
    fig,
    scatter(x=ϕ,y=z/1e3),
    row=1, col=2)
    
fig
=#