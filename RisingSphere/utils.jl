# this loads scientific colormaps 
# Colormaps should be given in text format in the direc
using DelimitedFiles

# dir_colormaps = "../src/assets/colormaps/"

"""
This reads colormaps and transfers them into plotly format. The colormaps are supposed to be provided in ascii text format 
"""
function read_colormaps(; dir_colormaps="../src/assets/colormaps/" , scaling=256)
    println(dir_colormaps)
    # Read all colormaps
    colormaps = NamedTuple();
    for map in readdir(dir_colormaps)
        data = readdlm(dir_colormaps*map)
        name_str = map[1:end-4]

        if contains(name_str,"reverse")
            reverse=true
            data = data[end:-1:1,:]
        else
            reverse=false
        end

        name = Symbol(name_str)

        # apply scaling
        data_rgb = Int64.(round.(data*scaling))

        # Create the format that plotly wants:
        n = size(data,1)
        fac = range(0,1,n)
        data_col = [ [fac[i], "rgb($(data_rgb[i,1]),$(data_rgb[i,2]),$(data_rgb[i,3]))"] for i=1:n]

        col = NamedTuple{(name,)}((data_col,))
        colormaps = merge(colormaps, col)
    end

    return colormaps
end

function make_accordion_item(label::String, idx::String, msg::String, value::Float64, min::Float64=1.0e-10, max::Float64=10_000.0)
    item = dbc_row([ # domain width
        dbc_col([
            dbc_label(label, id=idx*"_label", size="md"),
            dbc_tooltip(msg, target=idx*"_label")
        ]),
        dbc_col(dbc_input(id=idx, placeholder=string(value), value=value, type="number", min=min, size="md"))
    ])
    return item
end

function make_accordion_item(label::String, idx::String, msg::String, value::Int64, min::Int64=2, max::Int64=10_000)
    item = dbc_row([ # domain width
        dbc_col([
            dbc_label(label, id=idx*"_label", size="md"),
            dbc_tooltip(msg, target=idx*"_label")
        ]),
        dbc_col(dbc_input(id=idx, placeholder=string(value), value=value, type="number", min=min, size="md"))
    ])
    return item
end

cc = read_colormaps()