local lut = {}
local original_images = {}
local colorized_images = {}
local src_colors = {}
local dst_colors = {}

local CONFORM_METHOD_WEIGHTED_EUCLIDEAN = "Weighted Euclidean"
local CONFORM_METHOD_EUCLIDEAN = "Euclidean"
local CONFORM_METHOD_REDMEAN = "Redmean"
local CONFORM_METHOD_DELTA_E = "Delta E"
local ALL_CONFORM_METHODS = {
    CONFORM_METHOD_WEIGHTED_EUCLIDEAN,
    CONFORM_METHOD_EUCLIDEAN,
    CONFORM_METHOD_REDMEAN,
    CONFORM_METHOD_DELTA_E
}

local function set_to_array(set)
    local array = {}

    for k, _ in pairs(set) do
        array[#array + 1] = k
    end

    return array
end

local function round(value)
    return math.floor(value + 0.5)
end

local function remap(value, old_min, old_max, new_min, new_max)
    if old_min == old_max then
        return new_min
    end

    return (value - old_min) * (new_max - new_min) / (old_max - old_min) + new_min
end

local function srgb_to_linear(value)
    if value > 0.0405 then
        return ((value + 0.055) / 1.055) ^ 2.4
    else
        return value / 12.92
    end
end

local function linear_to_srgb(value)
    if value <= 0.0031308 then
        return 12.92 * value
    else
        return (1.055 * (value ^ (1 / 2.4))) - 0.055
    end
end

local function luminance_to_lightness(value)
    if value > 0.008856 then
        return value ^ (1 / 3)
    else
        return (7.787 * value) + (16 / 116)
    end
end

local function rgb_to_xyz(r, g, b)
    local var_r = r / 255
    local var_g = g / 255
    local var_b = b / 255

    var_r = srgb_to_linear(var_r)
    var_g = srgb_to_linear(var_g)
    var_b = srgb_to_linear(var_b)

    var_r = var_r * 100
    var_g = var_g * 100
    var_b = var_b * 100

    local x = (var_r * 0.4124) + (var_g * 0.3576) + (var_b * 0.1805)
    local y = (var_r * 0.2126) + (var_g * 0.7152) + (var_b * 0.0722)
    local z = (var_r * 0.0193) + (var_g * 0.1192) + (var_b * 0.9505)

    return x, y, z
end

local function xyz_to_lab(x, y, z)
    -- D65, CIE 1964 reference values
    local ref_x = 94.811
    local ref_y = 100
    local ref_z = 107.304

    local var_x = x / ref_x
    local var_y = y / ref_y
    local var_z = z / ref_z

    var_x = luminance_to_lightness(var_x)
    var_y = luminance_to_lightness(var_y)
    var_z = luminance_to_lightness(var_z)

    local l = (116 * var_y) - 16
    local a = 500 * (var_x - var_y)
    local b = 200 * (var_y - var_z)

    return l, a, b
end

local function rgb_to_lab(r, g, b)
    return xyz_to_lab(rgb_to_xyz(r, g, b))
end

local function color_to_grayscale(color)
    local rgb = Color(color)

    local r = rgb.red
    local g = rgb.green
    local b = rgb.blue

    r = r / 255
    g = g / 255
    b = b / 255

    -- Rec. 709
    local r_weight = 0.2126
    local g_weight = 0.7152
    local b_weight = 0.0722

    local luminance = (r * r_weight) + (g * g_weight) + (b * b_weight)
    luminance = round(luminance * 255)

    return Color(luminance, luminance, luminance).rgbaPixel
end

local function delta_e_distance(color1, color2)
    local rgb1 = Color(color1)
    local rgb2 = Color(color2)
    local l1, a1, b1 = rgb_to_lab(rgb1.red, rgb1.green, rgb1.blue)
    local l2, a2, b2 = rgb_to_lab(rgb2.red, rgb2.green, rgb2.blue)
    return math.sqrt((l1 - l2) ^ 2 + (a1 - a2) ^ 2 + (b1 - b2) ^ 2)
end

local function euclidean_distance(color1, color2, bit_depth)
    local rgb1 = Color(color1)
    local rgb2 = Color(color2)

    local r1 = rgb1.red
    local g1 = rgb1.green
    local b1 = rgb1.blue

    local r2 = rgb2.red
    local g2 = rgb2.green
    local b2 = rgb2.blue

    if bit_depth == 5 then
        r1 = r1 >> 3
        g1 = g1 >> 3
        b1 = b1 >> 3
        r2 = r2 >> 3
        g2 = g2 >> 3
        b2 = b2 >> 3
    end

    local rr = (r2 - r1) ^ 2
    local gg = (g2 - g1) ^ 2
    local bb = (b2 - b1) ^ 2

    return math.sqrt(rr + gg + bb)
end

local function weighted_euclidean_distance(color1, color2, bit_depth)
    local rgb1 = Color(color1)
    local rgb2 = Color(color2)

    local r1 = rgb1.red
    local g1 = rgb1.green
    local b1 = rgb1.blue

    local r2 = rgb2.red
    local g2 = rgb2.green
    local b2 = rgb2.blue

    if bit_depth == 5 then
        r1 = r1 >> 3
        g1 = g1 >> 3
        b1 = b1 >> 3
        r2 = r2 >> 3
        g2 = g2 >> 3
        b2 = b2 >> 3
    end

    local r_weight = 30
    local g_weight = 59
    local b_weight = 11

    local rr = ((r1 - r2) * r_weight) ^ 2
    local gg = ((g1 - g2) * g_weight) ^ 2
    local bb = ((b1 - b2) * b_weight) ^ 2

    return math.sqrt(rr + gg + bb)
end

local function redmean_distance(color1, color2, bit_depth)
    local rgb1 = Color(color1)
    local rgb2 = Color(color2)

    local r1 = rgb1.red
    local g1 = rgb1.green
    local b1 = rgb1.blue

    local r2 = rgb2.red
    local g2 = rgb2.green
    local b2 = rgb2.blue

    if bit_depth == 5 then
        r1 = r1 >> 3
        g1 = g1 >> 3
        b1 = b1 >> 3
        r2 = r2 >> 3
        g2 = g2 >> 3
        b2 = b2 >> 3
    end

    local r_mean = (r1 + r2) / 2
    local rr = (r2 - r1) ^ 2
    local gg = (g2 - g1) ^ 2
    local bb = (b2 - b1) ^ 2

    return ((2 + (r_mean / 256)) * rr) + (4 * gg) + ((2 + ((255 - r_mean) / 256)) * bb)
end

local function color_distance(color1, color2, conform_method, bit_depth)
    if conform_method == CONFORM_METHOD_WEIGHTED_EUCLIDEAN then
        return weighted_euclidean_distance(color1, color2, bit_depth)
    elseif conform_method == CONFORM_METHOD_EUCLIDEAN then
        return euclidean_distance(color1, color2, bit_depth)
    elseif conform_method == CONFORM_METHOD_REDMEAN then
        return redmean_distance(color1, color2, bit_depth)
    elseif conform_method == CONFORM_METHOD_DELTA_E then
        return delta_e_distance(color1, color2)
    else
        return 0
    end
end

local function color_has_opacity(color)
    if Color(color).alpha > 0 then
        return true
    else
        return false
    end
end

local function sort_by_lightness(a, b)
    local l1 = Color(color_to_grayscale(a)).lightness
    local l2 = Color(color_to_grayscale(b)).lightness
    return l1 < l2
end

local function sort_by_hue(a, b)
    local rgb1 = Color(a)
    local rgb2 = Color(b)
    return rgb1.hsvHue < rgb2.hsvHue
end

local function is_pixel_selected(pixel, image)
    local selection = app.sprite.selection
    local x = pixel.x + image.cel.bounds.x
    local y = pixel.y + image.cel.bounds.y
    return selection:contains(x, y)
end

local function image_selection_rect(image)
    local selection = app.sprite.selection
    if selection.isEmpty then
        return Rectangle()
    else
        return Rectangle(
            selection.bounds.x - image.cel.bounds.x,
            selection.bounds.y - image.cel.bounds.y,
            selection.bounds.width,
            selection.bounds.height
        )
    end
end

local function get_all_sprite_colors()
    local colors = {}

    for _, image in ipairs(app.range.editableImages) do
        for pixel in image:pixels() do
            if color_has_opacity(pixel()) then
                colors[pixel()] = true
            end
        end
    end

    return colors
end

local function get_selected_sprite_colors()
    local colors = {}

    for _, image in ipairs(app.range.editableImages) do
        for pixel in image:pixels(image_selection_rect(image)) do
            if is_pixel_selected(pixel, image) then
                if color_has_opacity(pixel()) then
                    colors[pixel()] = true
                end
            end
        end
    end

    return colors
end


local function get_src_colors()
    local colors = {}

    if app.sprite.selection.isEmpty then
        colors = get_all_sprite_colors()
    else
        colors = get_selected_sprite_colors()
    end

    colors = set_to_array(colors)

    return colors
end

local function get_all_palette_colors()
    local palette = app.sprite.palettes[1]
    local colors = {}

    for i = 0, #palette - 1 do
        local color = palette:getColor(i).rgbaPixel
        if color_has_opacity(color) then
            colors[color] = true
        end
    end

    return colors
end

local function get_selected_palette_colors()
    local palette = app.sprite.palettes[1]
    local colors = {}

    for _, palette_index in ipairs(app.range.colors) do
        local color = palette:getColor(palette_index).rgbaPixel
        if color_has_opacity(color) then
            colors[color] = true
        end
    end

    return colors
end

local function get_dst_colors()
    local colors = {}

    if #app.range.colors == 0 then
        colors = get_all_palette_colors()
    else
        colors = get_selected_palette_colors()
    end

    colors = set_to_array(colors)

    return colors
end

local function build_colorize_lut(gamma)
    local colorize_lut = {}

    table.sort(src_colors, sort_by_lightness)
    table.sort(dst_colors, sort_by_lightness)

    local g = gamma
    if gamma > 0 then
        g = remap(gamma, 0, 100, 1, 9.99)
    else
        g = remap(gamma, 0, -100, 1, 0.01)
    end

    local function apply_gamma_curve_to_index(index)
        local normalized_index = remap(index, 1, #src_colors, 0, 1)
        if gamma ~= 0 then
            normalized_index = normalized_index ^ (1 / g)
        end
        local new_index = math.floor(remap(normalized_index, 0, 1, 1, #dst_colors))
        return new_index
    end

    for i, src_color in ipairs(src_colors) do
        local dst_index = apply_gamma_curve_to_index(i)
        local dst_color = dst_colors[dst_index]
        colorize_lut[src_color] = dst_color
    end

    return colorize_lut
end

local function build_conform_lut(conform_method, bit_depth)
    local conform_lut = {}

    table.sort(src_colors, sort_by_hue)
    table.sort(dst_colors, sort_by_hue)

    for _, src_color in ipairs(src_colors) do
        local closest_color = dst_colors[1]
        local closest_distance = color_distance(src_color, closest_color, conform_method, bit_depth)
        for _, dst_color in ipairs(dst_colors) do
            local distance = color_distance(src_color, dst_color, conform_method, bit_depth)
            if distance < closest_distance then
                closest_color = dst_color
                closest_distance = distance
            end
        end
        conform_lut[src_color] = closest_color
    end

    return conform_lut
end

local function build_grayscale_lut()
    local grayscale_lut = {}

    table.sort(src_colors, sort_by_lightness)
    table.sort(dst_colors, sort_by_lightness)

    for _, src_color in ipairs(src_colors) do
        grayscale_lut[src_color] = color_to_grayscale(src_color)
    end

    return grayscale_lut
end

local function colorize_all_pixels(image)
    local colorized_image = image:clone()

    for pixel in image:pixels() do
        local old_color = pixel()
        local new_color = lut[old_color]
        if color_has_opacity(old_color) then
            colorized_image:drawPixel(pixel.x, pixel.y, new_color)
        end
    end

    return colorized_image
end

local function colorize_selected_pixels(image)
    local colorized_image = image:clone()

    for pixel in image:pixels(image_selection_rect(image)) do
        if is_pixel_selected(pixel, image) then
            local old_color = pixel()
            local new_color = lut[old_color]
            if color_has_opacity(old_color) then
                colorized_image:drawPixel(pixel.x, pixel.y, new_color)
            end
        end
    end

    return colorized_image
end

local function colorize_image(image)
    if app.sprite.selection.isEmpty then
        return colorize_all_pixels(image)
    else
        return colorize_selected_pixels(image)
    end
end

local function replace_image(old_image, new_image)
    old_image:drawImage(new_image, Point(), 255, BlendMode.SRC)
end

local function get_original_images()
    local images = {}

    for _, image in ipairs(app.range.editableImages) do
        images[#images + 1] = image:clone()
    end

    return images
end

local function get_colorized_images()
    local images = {}

    for _, image in ipairs(app.range.editableImages) do
        images[#images + 1] = colorize_image(image)
    end

    return images
end

local function revert_preview()
    for i, image in ipairs(app.range.editableImages) do
        replace_image(image, original_images[i])
    end

    app.refresh()
end

local function apply_preview()
    for i, image in ipairs(app.range.editableImages) do
        replace_image(image, colorized_images[i])
    end

    app.refresh()
end

local function show_dialog()
    local dlg = Dialog { title = "Colorize", onclose = function() revert_preview() end }

    -- Timer hack to create an function that runs immediately after the dialog is shown in wait mode
    local function on_show_dialog()
        dlg:repaint() -- Force canvases to redraw
    end

    local on_show_dialog_timer
    on_show_dialog_timer = Timer {
        interval = 0,
        ontick = function()
            on_show_dialog()
            on_show_dialog_timer:stop()
        end }

    -- Callbacks
    local function update_lut()
        revert_preview()

        local bit_depth = 8
        if dlg.data.bit_depth_5 then
            bit_depth = 5
        end

        if dlg.data.mode_colorize then
            lut = build_colorize_lut(dlg.data.gamma)
        elseif dlg.data.mode_conform then
            lut = build_conform_lut(dlg.data.conform_method, bit_depth)
        elseif dlg.data.mode_grayscale then
            lut = build_grayscale_lut()
        end

        colorized_images = get_colorized_images()

        -- Draw preview
        if dlg.data.preview then
            apply_preview()
        end
    end

    local function update_widgets()
        local bounds = dlg.bounds

        if dlg.data.advanced then
            if dlg.data.mode_colorize then
                dlg:modify { id = "gamma", visible = true }
                dlg:modify { id = "conform_method", visible = false }
                dlg:modify { id = "bit_depth_8", visible = false }
                dlg:modify { id = "bit_depth_5", visible = false }
            elseif dlg.data.mode_conform then
                dlg:modify { id = "gamma", visible = false }
                dlg:modify { id = "conform_method", visible = true }
                dlg:modify { id = "bit_depth_8", visible = true }
                dlg:modify { id = "bit_depth_5", visible = true }
                if dlg.data.conform_method == CONFORM_METHOD_DELTA_E then
                    dlg:modify { id = "bit_depth_8", enabled = false }
                    dlg:modify { id = "bit_depth_5", enabled = false }
                else
                    dlg:modify { id = "bit_depth_8", enabled = true }
                    dlg:modify { id = "bit_depth_5", enabled = true }
                end
            elseif dlg.data.mode_grayscale then
                dlg:modify { id = "gamma", visible = false }
                dlg:modify { id = "conform_method", visible = false }
                dlg:modify { id = "bit_depth_8", visible = false }
                dlg:modify { id = "bit_depth_5", visible = false }
            end
        else
            dlg:modify { id = "gamma", visible = false }
            dlg:modify { id = "conform_method", visible = false }
            dlg:modify { id = "bit_depth_8", visible = false }
            dlg:modify { id = "bit_depth_5", visible = false }
        end

        dlg.bounds = Rectangle(bounds.x, bounds.y, bounds.width, dlg.bounds.height)
        app.refresh()
    end

    local function update_preview()
        if dlg.data.preview then
            apply_preview()
        else
            revert_preview()
        end
    end

    local function on_canvas_paint(ev)
        local gc = ev.context -- GraphicsContext

        -- Draw background
        if #src_colors == 1 then
            gc.color = src_colors[1]
            gc:fillRect(Rectangle(0, 0, gc.width, gc.height))
        elseif #src_colors > 1 then
            gc.color = src_colors[1]
            gc:fillRect(Rectangle(0, 0, gc.width, gc.height))
            gc.color = src_colors[#src_colors]
            gc:fillRect(Rectangle(math.ceil(gc.width / 2), 0, math.floor(gc.width / 2), gc.height))
        end

        -- Draw color swatches
        local x = 0
        local y = 0
        local w = math.max(math.floor(gc.width / #src_colors), 1)
        local h = math.floor(gc.height / 2)
        local x_remainder = gc.width - (w * #src_colors)
        local first_w = w + math.ceil(x_remainder / 2)
        local last_w = w + math.floor(x_remainder / 2)

        for i, color in ipairs(src_colors) do
            local swatch_w
            if i == 1 then
                swatch_w = first_w
            elseif i == #src_colors then
                swatch_w = last_w
            else
                swatch_w = w
            end
            gc.color = color
            gc:fillRect(Rectangle(x, y, swatch_w, h))
            gc.color = lut[color]
            gc:fillRect(Rectangle(x, y + h, swatch_w, h))
            x = x + swatch_w
        end
    end

    local function on_mode_clicked()
        update_lut()
        update_widgets()
        update_preview()
    end

    local function on_gamma_released()
        update_lut()
        update_widgets()
        update_preview()
    end

    local function on_conform_method_changed()
        update_lut()
        update_widgets()
        update_preview()
    end

    local function on_bit_depth_clicked()
        update_lut()
        update_widgets()
        update_preview()
    end

    local function on_advanced_clicked()
        update_widgets()
    end

    local function on_preview_clicked()
        update_preview()
    end

    -- Mode
    dlg:radio { id = "mode_colorize", text = "Colorize", onclick = on_mode_clicked, selected = true, label = "Mode" }
    dlg:radio { id = "mode_conform", text = "Conform", onclick = on_mode_clicked }
    dlg:radio { id = "mode_grayscale", text = "Grayscale", onclick = on_mode_clicked }

    -- LUT
    dlg:separator { text = "Color" }
    dlg:canvas { id = "canvas", label = "LUT", height = 20, onpaint = on_canvas_paint }
    dlg:slider { id = "gamma", label = "Gamma", min = -100, max = 100, value = 0, onrelease = on_gamma_released }
    dlg:combobox { id = "conform_method", label = "Method", option = ALL_CONFORM_METHODS[1], options = ALL_CONFORM_METHODS, onchange = on_conform_method_changed }
    dlg:radio { id = "bit_depth_8", text = "8-bit", onclick = on_bit_depth_clicked, selected = true, label = "Bit Depth" }
    dlg:radio { id = "bit_depth_5", text = "5-bit", onclick = on_bit_depth_clicked }

    -- Preview / buttons
    dlg:separator()
    dlg:check { id = "advanced", text = "Advanced Options", onclick = on_advanced_clicked }
    dlg:newrow()
    dlg:check { id = "preview", text = "Preview", selected = true, onclick = on_preview_clicked }
    dlg:button { id = "ok", text = "OK" }
    dlg:button { id = "cancel", text = "Cancel" }

    -- Force callbacks
    update_lut()
    update_widgets()
    update_preview()
    dlg.bounds = Rectangle(dlg.bounds.x, dlg.bounds.y, 250, dlg.bounds.height) -- Set width

    -- Show dialog
    on_show_dialog_timer:start()
    dlg:show { hand = true }

    return dlg.data.ok
end

local function show_error(text)
    app.alert { title = "Colorize Error", text = text }
    error()
end

local function validate_color_mode()
    if app.sprite.colorMode ~= ColorMode.RGB then
        show_error("Sprite must be in RGB mode")
    end
end

local function validate_editable_images()
    if #app.range.editableImages == 0 then
        show_error("At least one unlocked or non-empty cel must be selected")
    end
end

local function validate_sprite_colors()
    if #src_colors == 0 then
        show_error("No colors were found in the source image")
    end
end

local function validate_palette_colors()
    if #dst_colors == 0 then
        if #app.range.colors == 0 then
            show_error("No valid palette colors exist")
        else
            show_error("No valid palette colors are selected")
        end
    end
end

local function main()
    original_images = get_original_images()
    src_colors = get_src_colors()
    dst_colors = get_dst_colors()

    validate_color_mode()
    validate_editable_images()
    validate_sprite_colors()
    validate_palette_colors()

    if show_dialog() then
        for i, image in ipairs(app.range.editableImages) do
            replace_image(image, colorized_images[i])
        end
    else
        error() -- This cancels the transaction so that a cancelled Colorize operation doesn't appear in the undo history
    end
end

app.transaction("Colorize", main)
