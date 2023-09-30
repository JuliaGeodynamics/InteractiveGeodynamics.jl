module InteractiveGeodynamics


# Rising sphere app
include("./RisingSphere/RisingSphere_Dash.jl")
using .RisingSphereTools
export RisingSphere

# RayleighTaylor app
include("./RayleighTaylorInstability/RTI_Dash.jl")
using .RTITools
export RayleighTaylor

# Convection app
include("./RayleighBenardConvection/Convection_Dash.jl")
using .ConvectionTools
export Convection


end # module InteractiveGeodynamics
