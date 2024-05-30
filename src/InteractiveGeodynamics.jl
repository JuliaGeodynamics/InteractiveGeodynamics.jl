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

# folding app
include("./Folding/Folding_Dash.jl")
using .FoldingTools
export folding

"""
    sill_intrusion_1D
GUI to intrude magma-filles sills into the crust using a 1D thermal model.
It requires you to load `GLMakie`.
"""
function sill_intrusion_1D end
export sill_intrusion_1D


end # module InteractiveGeodynamics
