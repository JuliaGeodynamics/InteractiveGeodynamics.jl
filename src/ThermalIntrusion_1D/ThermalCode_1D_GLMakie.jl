# GUI for GLMakie
using GLMakie
GLMakie.activate!()
GLMakie.closeall() # close any open screen

include("ThermalCode_1D.jl")

# Few helpers: 
add_textbox(fig, label, value) = [Label(fig, label), Textbox(fig, stored_string = string(value), validator = typeof(value))]
add_togglebox(fig, label, active) = [Label(fig, label), Toggle(fig, active=active)]
get_valuebox(box::Vector) = parse(box[2].validator.val, box[2].stored_string.val)


fig = Figure(size=(900,900))

time_val = Observable(0.0)

ax1 =  Axis(fig[1, 1], xlabel="Temperature [ᵒC]", ylabel="Depth [km]")
ax2 =  Axis(fig[1, 2], xlabel="Melt fraction ϕ", title = @lift("t = $(round($time_val, digits = 2)) kyrs"))
ax3 =  Axis(fig[2, 1:2], xlabel="Time [kyrs]", ylabel="Maximum Temperature [ᵒC]",ytickcolor=:red,ylabelcolor=:red,yticklabelcolor=:red)
ax4 =  Axis(fig[2, 1:2], ylabel="Maximum melt fraction ϕ",ytickcolor=:blue,ylabelcolor=:blue,yticklabelcolor=:blue,  yaxisposition = :right)

linkxaxes!(ax3, ax4)

fig[1:2, 3] = grid = GridLayout(tellwidth = false)


grid[1, 1:2] = but          = Button(fig, label = "  RUN SIMULATION  ", buttoncolor = :lightgreen)

Box(grid[2:4, 1:2], color = :lightgrey, cornerradius = 10)
grid[2, 1:2] = Δz_box       = add_textbox(fig,"Grid spacing Δz [m]:",40)
grid[3, 1:2] = nt_box       = add_textbox(fig,"# timesteps nt:",150)
grid[4, 1:2] = Δt_yrs_box   = add_textbox(fig,"timestep Δt [yrs]:",100.0)

Box(grid[5:7, 1:2], color = :lightblue, cornerradius = 10)
grid[5, 1:2] = H_box        = add_textbox(fig,"Crustal thickness [km]:",40.0)
grid[6, 1:2] = Ttop_box     = add_textbox(fig,"Ttop [ᵒC]:",0.0)
grid[7, 1:2] = γ_box        = add_textbox(fig,"Geotherm [ᵒC/km]:",20.0)

Box(grid[8:12, 1:2], color = :lightyellow, cornerradius = 10)
grid[8, 1:2] = Tsill_box    = add_textbox(fig,"Sill Temperature [ᵒC]:",1200.0)
grid[9, 1:2] = Sill_thick_box = add_textbox(fig,"Sill thickness [m]:",1000.0)
grid[10, 1:2] = Sill_interval_box = add_textbox(fig,"Sill injection interval [yrs]:",1000.0)
grid[11, 1:2] = Sill_interval_top_box = add_textbox(fig,"Top sill injection [km]:",10.0)
grid[12, 1:2] = Sill_interval_bot_box = add_textbox(fig,"Bottom sill injection [km]:",20.0)

Box(grid[13:15, 1:2], color = (:red,0.3), cornerradius = 10 )
grid[13, 1:2] = Ql_box = add_textbox(fig,"Latent heat [kJ/kg]:",255.0)
grid[14, 1:2] = menu_conduct = Menu(fig, options = ["T-dependent conductivity", "Constant conductivity 3 W/m/K"], default = "Constant conductivity 3 W/m/K")
grid[15, 1:2] = menu_melting = Menu(fig, options = ["MeltingParam_Assimilation", "MeltingParam_Basalt", "MeltingParam_Rhyolite"], default = "MeltingParam_Basalt")



rowsize!(fig.layout, 2, Relative(1/4))

SecYear = 3600*24*365.25
# Start the simulation
on(but.clicks) do n
    # Retrieve data from GUI
    SecYear     = 3600*24*365.25
    Δz          = get_valuebox(Δz_box)
    H           = get_valuebox(H_box)
    nz          = floor(Int64, H*1e3/Δz)
    nt          = get_valuebox(nt_box)
    γ           = get_valuebox(γ_box)
    Tsill       = get_valuebox(Tsill_box)
    Ttop        = get_valuebox(Ttop_box)
    Δt          = get_valuebox(Δt_yrs_box)*SecYear
    Silltop     = get_valuebox(Sill_interval_top_box)
    Sillbot     = get_valuebox(Sill_interval_bot_box)
    Sillthick   = get_valuebox(Sill_thick_box)
    Sill_int_yr = get_valuebox(Sill_interval_box)
    Ql          = get_valuebox(Ql_box)*1e3


    conductivity = T_Conductivity_Whittington()
    heatcapacity = T_HeatCapacity_Whittington()
    if menu_conduct.selection[]=="Constant conductivity 3 W/m/K"
        conductivity = ConstantConductivity(k=3.0)
        heatcapacity = ConstantHeatCapacity()
    end

    melting = MeltingParam_Smooth3rdOrder()
    if menu_melting.selection[]=="MeltingParam_Assimilation"
        melting = MeltingParam_Assimilation()
    elseif menu_melting.selection[]=="MeltingParam_Rhyolite"
        melting = MeltingParam_Smooth3rdOrder(a=3043.0,b=−10552.0, c=12204.9,d=−4709.0)
    end
    

    MatParam     = (SetMaterialParams(Name="RockMelt", Phase=0, 
                                    Density         = ConstantDensity(ρ=2700kg/m^3),                            # used in the parameterisation of Whittington 
                                    LatentHeat      = ConstantLatentHeat(Q_L=Ql*J/kg),
                                    RadioactiveHeat = ExpDepthDependentRadioactiveHeat(H_0=0e-7Watt/m^3),
                                    Conductivity    = conductivity,                             #  T-dependent k
                                    HeatCapacity    = heatcapacity,                             # T-dependent cp
                                    Melting         = melting                                   # Quadratic parameterization as in Tierney et al.
    ),)

   

    @info "parameters" nz, H, γ, Tsill, Ttop, nz 
    Tbot = Ttop +   H*γ

    # setup model
    Params, BC, N, Δ, T, z = init_model(nz=nz, L=H*1e3, Geotherm=γ, Ttop=Ttop, Tbot=Tbot, Δt=Δt, MatParam=MatParam)
    
    rocks = zero(T) # will later contain locations with injected sills

    # add initial perturbation (if any)
    T_cen =  (Silltop + Sillbot)/2*1e3    

    ind = findall( abs.(z .+ T_cen) .< Sillthick/2)
    if !isempty(ind)
        T[ind] .= Tsill
    end
    Params.Told .= T

    # create initial plot
    PlotData = (;ax1, ax2, fig)
    println("Running simulation $n")
 
    # timestepping
    F = zero(T)
    time = 0.0
    timevec =Observable([0.0, 1.0])
    Tmaxvec =Observable([0.0, 1.0])
    
    Tplot = Observable(T)
    ϕplot = Observable(Params.ϕ)

    empty!(ax1)
    lines!(ax1, Tplot, z/1e3, color=:red)    
    ax1.limits=(minimum(T)-10, maximum(T)+10,extrema(z/1e3)...)    
    empty!(ax2)
    lines!(ax2, ϕplot, z/1e3, color=:blue)
    ax2.limits=(-1e-1,1+1e-1,extrema(z/1e3)...)    
    xlims!(ax3, 0, nt*Δt/SecYear/1e3)
    xlims!(ax4, 0, nt*Δt/SecYear/1e3)


    # Get initial sparsity pattern of matrix
    nz          = N[1]
    J1          = Tridiagonal(ones(nz-1), ones(nz), ones(nz-1))
    J1[1,2] =   0; J1[2,1]=0; J1[nz-1,nz]=0; J1[nz,nz-1]=0
    Jac         =   sparse(Float64.(abs.(J1).>0))
    colors      =   matrix_colors(Jac) 
    
    #T,  converged, its = nonlinear_solution(F, T, Jac, colors, verbose=false, Δ=Δ, N=N, BC=BC, Params=Params, MatParam=MatParam)

    time_vec = Float64[]
    Tmax_vec = Float64[]
    ϕmax_vec = Float64[]
    
    Sill_z0 = -20e3;
    println("Injecting sill @ z=$Sill_z0")

    T, rocks = insert_sill(T,rocks, z; 
                Sill_thick=Sillthick, Sill_z0=Sill_z0, Sill_T=Tsill)

    # perform timestepping
    @async for t = 1:nt
        #sleep(0.1)

        T,  converged, its = nonlinear_solution(F, T, Jac, colors, verbose=false, Δ=Δ, N=N, BC=BC, Params=Params, MatParam=MatParam)
       

        if mod(time/SecYear, Sill_int_yr)==0
            
            Sill_z0 = rand(-Sillbot*1e3:1:-Silltop*1e3)


            println("Injecting sill @ z=$Sill_z0")

            T, rocks = insert_sill(T,rocks, z; 
                        Sill_thick=Sillthick, Sill_z0=Sill_z0, Sill_T=Tsill)

        end

        Params.Told .= T

        time += Params.Δt
        time_kyrs = time/SecYear/1e3

        push!(time_vec, time_kyrs)
        push!(Tmax_vec, maximum(T))
        push!(ϕmax_vec, maximum(Params.ϕ))

        # save file to disk
        if mod(t,1)==0
            Tplot[] = T
            ϕplot[] = Params.ϕ
            time_val[] = time_kyrs

            empty!(ax2)
            rock_low  = Point2f.(zero(rocks), z/1e3)
            rock_high = Point2f.(rocks, z/1e3)

            band!(ax2, rock_low, rock_high, color=(:lightgrey,1.0))
            lines!(ax2, Params.ϕ, z/1e3, color=:blue)
            
            empty!(ax3)
            lines!(ax3, time_vec, Tmax_vec, color=:red)
            scatter!(ax3, time_vec[end], Tmax_vec[end], color=:red)
            ylims!(ax3, minimum(Tmax_vec)-10,maximum(Tmax_vec)+10)

            empty!(ax4)
            lines!(ax4, time_vec, ϕmax_vec, color=:blue)
            scatter!(ax4, time_vec[end], ϕmax_vec[end], color=:blue)
            ylims!(ax4, 0, 1.01)

            @show extrema(rocks)
            println("Timestep $t, $time_kyrs kyrs, nz=$(length(T))")
        end

    end
  
end

display(fig)
    




#=
using GLMakie

time = Observable(0.0)

xs = range(0, 7, length=40)

#ys_1 = @lift(sin.(xs .- $time))
#ys_2 = @lift(cos.(xs .- $time) .+ 3)

ys_1 = @lift(sin.(xs .- $time))
ys_2 = @lift(cos.(xs .- $time) .+ 3)


fig = Figure()
ax = Axis(fig[1, 1], title = @lift("t = $(round($time, digits = 1))") )

lines!(ax,xs, ys_1, color = :blue, linewidth = 4)
scatter!(ax,xs, ys_2, color = :red, markersize = 15)

framerate = 30
timestamps = range(0, 2, step=1/framerate)

for t=1:100
    time[] = t
    sleep(0.1)
end
=#