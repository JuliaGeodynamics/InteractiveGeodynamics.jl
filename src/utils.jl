using GLMakie 

function primary_resolution()
    monitor = GLMakie.GLFW.GetPrimaryMonitor()
    videomode = GLMakie.MonitorProperties(monitor).videomode
    return (videomode.width, videomode.height)
end


"""
    nel_x,nel_z = retrieve_resolution(ParamFile, gui)

Read the resolution from the GUI and the parameter file  
"""
function retrieve_resolution(ParamFile, gui)

    nel_x_file = GeophysicalModelGenerator.ParseValue_LaMEM_InputFile(ParamFile,"nel_x", Int64);
    nel_z_file = GeophysicalModelGenerator.ParseValue_LaMEM_InputFile(ParamFile,"nel_z", Int64);
    nel_z      = parse(Int64,gui.nel_z.displayed_string[])
    nel_x = nel_x_file
    #nel_z      = round(Int64,nel_z_file/nel_x_file*nel_x)

    return nel_x, nel_z
end


"""
    values = get_values_textboxes(tb::NTuple)

Returns values as floats from textboxes
"""
function get_values_textboxes(tb::NTuple)

    values=()
    for textb in tb

        val = parse(Float64,textb.displayed_string[])
        values = (values...,val)

    end

    return values
end

