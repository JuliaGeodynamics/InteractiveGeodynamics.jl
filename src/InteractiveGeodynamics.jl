module InteractiveGeodynamics



#pkg_dir = Base.pkgdir(InteractiveGeodynamics)
#include(joinpath(pkg_dir,"src/dash_tools.jl"))

# Rising sphere app
include("../RisingSphere/RisingSphere_Dash.jl")
using .RisingSphereTools
export RisingSphere

# Convection app
include("../RayleighBenardConvection/Convection_Dash.jl")
using .ConvectionTools
export Convection


end # module InteractiveGeodynamics
