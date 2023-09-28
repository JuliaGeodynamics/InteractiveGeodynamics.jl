module InteractiveGeodynamics

pkg_dir = Base.pkgdir(InteractiveGeodynamics)

# Rising sphere app
#include("../RisingSphere/RisingSphere_Dash.jl")

# Convection app
include("../RayleighBenardConvection/Convection_Dash.jl")
using .ConvectionTools
export Convection


end # module InteractiveGeodynamics
