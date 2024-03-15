module InteractiveGeodynamics


# Rising sphere app
include("./RisingSphere/RisingSphere_Dash.jl")
using .RisingSphereTools
export rising_sphere

# rayleigh_taylor app
include("./RayleighTaylorInstability/RTI_Dash.jl")
using .RTITools
export rayleigh_taylor

# convection app
include("./RayleighBenardConvection/Convection_Dash.jl")
using .ConvectionTools
export convection

# free subduction app
include("./FreeSubduction/FreeSubduction_Dash.jl")
using .FreeSubductionTools
export subduction


end # module InteractiveGeodynamics
