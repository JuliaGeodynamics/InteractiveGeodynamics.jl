module InteractiveGeodynamicsGLMakieExt

import InteractiveGeodynamics:  sill_intrusion_1D

# We do not check `isdefined(Base, :get_extension)` as recommended since
# Julia v1.9.0 does not load package extensions when their dependency is
# loaded from the main environment.
if VERSION >= v"1.9.1"
    using GLMakie
else
    using ..GLMakie
end
  
include("../src/ThermalIntrusion_1D/ThermalCode_1D_GLMakie.jl")


end # module

