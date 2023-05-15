# This contains a number of widgets to make it easier to setup a GUI for LaMEM
using GridLayoutBase

"""
    Slider_with_text_above(pos::GridPosition, text::String, val_range::StepRangeLen, start_val)
Create a slider with text above it, along with changing values. `pos` is the position of the slider + text above

Example
===
```julia
julia> eta_up_sl, _, _ = Slider_with_text_above(fig[6:7,6:7], "log₁₀(ηᵤₚₚₑᵣ [Pas])", 18:.1:22, 20)
```
"""
function Slider_with_text_above(pos::GridPosition, text, val_range::StepRangeLen, start_val; height=Auto())
    span_top_left  = GridLayoutBase.Span(pos.span.rows[1]:pos.span.rows[1], pos.span.cols[1]:pos.span.cols[1] );
    span_top_right = GridLayoutBase.Span(pos.span.rows[1]:pos.span.rows[1], pos.span.cols[2]:pos.span.cols[2] );
    span_bot       = GridLayoutBase.Span(pos.span.rows[2]:pos.span.rows[2], pos.span.cols );
    
    pos_tl = GridPosition(pos.layout, span_top_left,   pos.side)
    pos_tr = GridPosition(pos.layout, span_top_right,  pos.side)
    pos_bt = GridPosition(pos.layout, span_bot,  pos.side)

    text1  = Label(pos_tl, text, height=height)
    text2  = Label(pos_tr, "1", width=Relative(0.5), height=height)
    sl     = Slider(pos_bt, range = val_range,  startvalue = start_val, height=height)
    lift(sl.value) do x
        text2.text[] = "$x"
    end

    return sl, text1, text2
end


function Slider_with_text_above(pos::GridSubposition, text, val_range::StepRangeLen, start_val; height=Auto())
    pos_tl = GridSubposition(pos.parent, pos.rows[1], pos.cols[1],  pos.side)
    pos_tr = GridSubposition(pos.parent, pos.rows[1], pos.cols[2],  pos.side)
    pos_bt = GridSubposition(pos.parent, pos.rows[2], pos.cols   ,  pos.side)


    
    text1  = Label(pos_tl, text, height=height)
    text2  = Label(pos_tr, "1", width=Relative(0.5), height=height)
    sl     = Slider(pos_bt, range = val_range,  startvalue = start_val, height=height)
    lift(sl.value) do x
        text2.text[] = "$x"
    end

    return sl, text1, text2
end

"""
    Textbox_with_label_left(pos::GridPosition, text::String, start_val)
Creates a textbox with a label to the left. Here `pos` is the full position (label + textbox)
"""
function Textbox_with_label_left(pos::GridPosition, text, start_val; 
            boxcolor_hover=:grey90, 
            bordercolor=GLMakie.RGB{Float32}(0.8f0,0.8f0,0.8f0),
            bordercolor_hover=GLMakie.RGB{Float32}(0.68235296f0,0.7529412f0,0.9019608f0),
            textcolor_placeholder= :black,
            width =  GLMakie.Auto(true, 1.0f0),
            height = Auto()
            )
    span_left  = GridLayoutBase.Span(pos.span.rows, pos.span.cols[1]:pos.span.cols[1] );
    span_right = GridLayoutBase.Span(pos.span.rows, pos.span.cols[2]:pos.span.cols[2] );
    pos_l = GridPosition(pos.layout, span_left,  pos.side)
    pos_r = GridPosition(pos.layout, span_right,  pos.side)

    text   = Label(pos_l, text)
    tb     = Textbox(pos_r, placeholder = start_val, stored_string=string(start_val), 
                boxcolor_hover=boxcolor_hover, 
                bordercolor=bordercolor, 
                bordercolor_hover=bordercolor_hover,
                textcolor_placeholder=textcolor_placeholder,
                width=width, height=height)

    return tb, text
end


function Textbox_with_label_left(pos::GridSubposition, text, start_val; 
    boxcolor_hover=:grey90, 
    bordercolor=GLMakie.RGB{Float32}(0.8f0,0.8f0,0.8f0),
    bordercolor_hover=GLMakie.RGB{Float32}(0.68235296f0,0.7529412f0,0.9019608f0),
    textcolor_placeholder= :black,
    width =  GLMakie.Auto(true, 1.0f0),
    height = Auto()
    )
    pos_l = GridSubposition(pos.parent, pos.rows[1], pos.cols[1],  pos.side)
    pos_r = GridSubposition(pos.parent, pos.rows[1], pos.cols[2],  pos.side)

    text   = Label(pos_l, text)
    tb     = Textbox(pos_r, placeholder = start_val, stored_string=string(start_val), 
            boxcolor_hover=boxcolor_hover, 
            bordercolor=bordercolor, 
            bordercolor_hover=bordercolor_hover,
            textcolor_placeholder=textcolor_placeholder,
            width=width, height=height)

    return tb, text
end


"""
    Toggle_with_label_left(pos::GridPosition, text::NTuple, active::Bool)
Creates a toggle with a label to the left. Here `pos` is the full position (label + textbox)
"""
function Toggle_with_label_left(pos::GridPosition, text_in, active::Bool; height=Auto())
    span_left  = GridLayoutBase.Span(pos.span.rows, pos.span.cols[1]:pos.span.cols[1] );
    span_right = GridLayoutBase.Span(pos.span.rows, pos.span.cols[2]:pos.span.cols[2] );
    pos_l = GridPosition(pos.layout, span_left,  pos.side)
    pos_r = GridPosition(pos.layout, span_right,  pos.side)

    text1  = Label(pos_l, text_in, height=height)
    tog    = Toggle(pos_r, active = active, height=height)
    
    return tog, text1
end

function Toggle_with_label_left(pos::GridSubposition, text_in, active::Bool; height=Auto())
    pos_l = GridSubposition(pos.parent, pos.rows[1], pos.cols[1],  pos.side)
    pos_r = GridSubposition(pos.parent, pos.rows[1], pos.cols[2],  pos.side)
  
    text1  = Label(pos_l, text_in, height=height)
    tog    = Toggle(pos_r, active = active, height=height)
    
    return tog, text1
end

"""
    Add_info_label(pos::GridPosition, text::String, start_val; width=100)
Creates label with a text label to the left and a numeric value (e.g. time) on the right. 
Here `pos` is the full position (label + textbox)
"""
function Add_info_label(pos::GridPosition, text, start_val; width=100, height=Auto())
    span_left  = GridLayoutBase.Span(pos.span.rows, pos.span.cols[1]:pos.span.cols[1] );
    span_right = GridLayoutBase.Span(pos.span.rows, pos.span.cols[2]:pos.span.cols[2] );
    pos_l = GridPosition(pos.layout, span_left,  pos.side)
    pos_r = GridPosition(pos.layout, span_right,  pos.side)

    text   =  Label(pos_l, text, justification = :right, width=width, height=height)
    tb     =  Label(pos_r, rpad(string(start_val),15), justification = :left, width=width, height=height)

    return tb, text
end


"""
    update_fields_menu(OutFile, menu)
Updates the dropdown menu
"""
function update_fields_menu(OutFile, menu)
    data,_ = Read_LaMEM_timestep(OutFile);  # read a filename
    names = string.(keys(data.fields));     # names
    menu.options[] = [names...]
    menu.i_selected[] = 1
    return Nothing
end



function keyword_LaMEM_inputfile(file,keyword,type)
    value = nothing
    for line in eachline(file)
        line_strip = lstrip(line)       # strip leading tabs/spaces

        # Strip comments
        ind        = findfirst("#", line)
        if isnothing(ind)
            # no comments
        else
            line_strip = line_strip[1:ind[1]-2];
        end
        line_strip = rstrip(line_strip)       # strip last tabs/spaces

        if startswith(line_strip, keyword)
            ind = findfirst("=", line_strip)
            if type==String
                value = split(line_strip)[3:end]
            else
                value = parse.(type,split(line_strip)[3:end])

                if length(value)==1
                    value=value[1];
                end
            end
        end
        
    end

    return value
end
