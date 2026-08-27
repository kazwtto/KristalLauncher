local settings_menu = {}

local input = require((...):match("(.-)[^%.]+$") .. "input")
local storage = require((...):match("(.-)[^%.]+$") .. "storage")
local localization = require((...):match("(.-)[^%.]+$") .. "localization")

local function tr(key)
    return localization.get(key)
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function guiMetrics(state)
    local scale = state.SH / 480
    local gui_w = state.SW / scale
    return scale, gui_w
end

local function inside(x, y, r)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function menuLayout(state)
    local _, gui_w = guiMetrics(state)
    local w = math.min(560, gui_w - 16)
    if w < 260 then w = math.max(180, gui_w - 8) end
    local h = 432
    local x = (gui_w - w) / 2
    local y = 24
    local pad = 18
    local inner_w = w - pad * 2

    return {
        gui_w = gui_w,
        x = x, y = y, w = w, h = h,
        pad = pad,
        inner_x = x + pad,
        inner_w = inner_w,
        header_y = y + 12,
        tabs_y = y + 58,
        tabs_h = 34,
        content_y = y + 104,
        footer_y = y + h - 48,
    }
end

local function addRegion(regions, id, x, y, w, h, kind)
    regions[#regions + 1] = { id = id, x = x, y = y, w = w, h = h, kind = kind }
end

local function getRegions(state)
    local L = menuLayout(state)
    local r = {}

    addRegion(r, "close", L.x + L.w - 44, L.y + 10, 32, 32)

    local tab_gap = 6
    local tab_w = (L.inner_w - tab_gap * 2) / 3
    addRegion(r, "tab_controls", L.inner_x, L.tabs_y, tab_w, L.tabs_h)
    addRegion(r, "tab_visual", L.inner_x + tab_w + tab_gap, L.tabs_y, tab_w, L.tabs_h)
    addRegion(r, "tab_layout", L.inner_x + (tab_w + tab_gap) * 2, L.tabs_y, tab_w, L.tabs_h)

    if state.menu_page == "controls" then
        addRegion(r, "toggle_visibility", L.inner_x, L.content_y, L.inner_w, 42)

        local y = L.content_y + 66
        local gap = 6
        local bw = (L.inner_w - gap * 3) / 4
        addRegion(r, "direction_fixed", L.inner_x, y, bw, 40)
        addRegion(r, "direction_dynamic", L.inner_x + (bw + gap), y, bw, 40)
        addRegion(r, "direction_dpad4", L.inner_x + (bw + gap) * 2, y, bw, 40)
        addRegion(r, "direction_dpad8", L.inner_x + (bw + gap) * 3, y, bw, 40)

        y = y + 62
        local half = (L.inner_w - gap) / 2
        addRegion(r, "analog_style_0", L.inner_x, y, half, 34)
        addRegion(r, "analog_style_1", L.inner_x + half + gap, y, half, 34)

        y = y + 62
        addRegion(r, "slider_deadzone", L.inner_x, y, L.inner_w, 42, "slider")

    elseif state.menu_page == "visual" then
        local y = L.content_y + 20
        addRegion(r, "slider_joy_size", L.inner_x, y, L.inner_w, 48, "slider")
        y = y + 66
        addRegion(r, "slider_button_size", L.inner_x, y, L.inner_w, 48, "slider")
        y = y + 66
        addRegion(r, "slider_opacity", L.inner_x, y, L.inner_w, 48, "slider")

        -- Optional legacy appearance selector. Hidden by default through
        -- state.disable_appearance_selector = true.
        if not state.disable_appearance_selector then
            y = y + 66
            addRegion(r, "slider_appearance", L.inner_x, y, L.inner_w, 48, "slider")
        end

    elseif state.menu_page == "layout" then
        local y = L.content_y + 60
        addRegion(r, "edit_layout", L.inner_x, y, L.inner_w, 54)
        addRegion(r, "reset_positions", L.inner_x, y + 68, L.inner_w, 42)
    end

    addRegion(r, "reset_all", L.inner_x, L.footer_y, 156, 34)
    addRegion(r, "done", L.x + L.w - L.pad - 112, L.footer_y, 112, 34)
    return r, L
end

local function findRegion(state, x, y)
    local regions = getRegions(state)
    for _, r in ipairs(regions) do
        if inside(x, y, r) then return r.id, r end
    end
    return nil, nil
end

local function getRegionById(state, id)
    local regions = getRegions(state)
    for _, r in ipairs(regions) do
        if r.id == id then return r end
    end
    return nil
end

local function setDirection(state, mode)
    local t = state.touchscreen_type
    if mode == "fixed" then
        state.touchscreen_type = (t == 1 or t == 3) and 1 or 0
    elseif mode == "dynamic" then
        state.touchscreen_type = (t == 1 or t == 3) and 3 or 2
    elseif mode == "dpad4" then
        state.touchscreen_type = 4
    elseif mode == "dpad8" then
        state.touchscreen_type = 5
    end
    state.config_changed = true
end

local function setSliderFromX(state, action, r, x)
    if not r then return end
    local track_pad = 10
    local track_x = r.x + track_pad
    local track_w = math.max(1, r.w - track_pad * 2)
    local t = clamp((x - track_x) / track_w, 0, 1)

    if action == "slider_deadzone" then
        state.touchscreen_deadzone = 0.10 + t * 0.80
    elseif action == "slider_joy_size" then
        state.touchscreen_scale[1] = 1.80 + t * 1.80
        storage.resolveLayout(state)
    elseif action == "slider_button_size" then
        state.touchscreen_scale[2] = 1.80 + t * 1.80
        storage.resolveLayout(state)
    elseif action == "slider_opacity" then
        state.touchscreen_opacity = 0.20 + t * 0.80
    elseif action == "slider_appearance" then
        state.touchscreen_color = clamp(math.floor(t * 8 + 1.5), 1, 9)
    else
        return
    end
    state.config_changed = true
end

local function isSliderAction(action)
    return action == "slider_deadzone"
        or action == "slider_joy_size"
        or action == "slider_button_size"
        or action == "slider_opacity"
        or action == "slider_appearance"
end

function settings_menu.open(state, return_con)
    input.event_user_0(state)
    state.menu_return_con = (return_con == -1) and -1 or 0
    state.menu_page = state.menu_page or "controls"
    state.menu_pointer = nil
    state.menu_pressed_action = nil
    state.menu_slider_action = nil
    state.menu_reset_confirm = false
    state.con = 99
end

function settings_menu.close(state)
    input.event_user_0(state)
    state.con = state.menu_return_con or 0
    state.menu_pointer = nil
    state.menu_pressed_action = nil
    state.menu_slider_action = nil
    state.menu_reset_confirm = false
    storage.saveTouchConfig(state)
end

local function applyAction(state, action)
    if not action then return end

    if action ~= "reset_all" then
        state.menu_reset_confirm = false
    end

    if action == "close" or action == "done" then
        settings_menu.close(state)
    elseif action == "tab_controls" then
        state.menu_page = "controls"
    elseif action == "tab_visual" then
        state.menu_page = "visual"
    elseif action == "tab_layout" then
        state.menu_page = "layout"
    elseif action == "toggle_visibility" then
        state.menu_return_con = (state.menu_return_con == -1) and 0 or -1
        state.config_changed = true
    elseif action == "direction_fixed" then
        setDirection(state, "fixed")
    elseif action == "direction_dynamic" then
        setDirection(state, "dynamic")
    elseif action == "direction_dpad4" then
        setDirection(state, "dpad4")
    elseif action == "direction_dpad8" then
        setDirection(state, "dpad8")
    elseif action == "analog_style_0" then
        if state.touchscreen_type == 1 then state.touchscreen_type = 0
        elseif state.touchscreen_type == 3 then state.touchscreen_type = 2 end
        state.config_changed = true
    elseif action == "analog_style_1" then
        if state.touchscreen_type == 0 then state.touchscreen_type = 1
        elseif state.touchscreen_type == 2 then state.touchscreen_type = 3 end
        state.config_changed = true
    elseif action == "edit_layout" then
        state.menu_pointer = nil
        state.menu_pressed_action = nil
        state.menu_slider_action = nil
        state.editor_pointer = nil
        state.editor_pressed_action = nil
        state.con = 98
    elseif action == "reset_positions" then
        storage.resetPositions(state)
    elseif action == "reset_all" then
        if state.menu_reset_confirm then
            state.menu_return_con = 0
            storage.resetDefaults(state)
            state.menu_reset_confirm = false
        else
            state.menu_reset_confirm = true
        end
    end
end

function settings_menu.update(state)
    for pid, ptr in pairs(state.currentPointers) do
        local x, y = ptr.x, ptr.y

        if ptr.down then
            if state.menu_pointer == nil then
                local action, region = findRegion(state, x, y)
                if action then
                    state.menu_pointer = pid
                    state.menu_pressed_action = action
                    if isSliderAction(action) then
                        state.menu_slider_action = action
                        setSliderFromX(state, action, region, x)
                    end
                end
            elseif state.menu_pointer == pid and state.menu_slider_action then
                local region = getRegionById(state, state.menu_slider_action)
                setSliderFromX(state, state.menu_slider_action, region, x)
            end

        elseif state.menu_pointer == pid then
            local released_over = findRegion(state, x, y)
            local action = state.menu_pressed_action
            local was_slider = state.menu_slider_action ~= nil
            state.menu_pointer = nil
            state.menu_pressed_action = nil
            state.menu_slider_action = nil

            if not was_slider and (pid ~= "mouse" or released_over == action) then
                applyAction(state, action)
                return
            end
        end
    end
end

local function editorRects(state)
    local _, gui_w = guiMetrics(state)
    return {
        reset = { x = 16, y = 14, w = 132, h = 36 },
        done = { x = gui_w - 112, y = 14, w = 96, h = 36 },
    }, gui_w
end

function settings_menu.updateLayoutEditor(state)
    local buttons, gui_w = editorRects(state)

    for pid, ptr in pairs(state.currentPointers) do
        local x, y = ptr.x, ptr.y
        local down = ptr.down

        if down and state.editor_pointer == nil then
            if inside(x, y, buttons.done) then
                state.editor_pointer = pid
                state.editor_pressed_action = "done"
            elseif inside(x, y, buttons.reset) then
                state.editor_pointer = pid
                state.editor_pressed_action = "reset"
            end
        elseif not down and state.editor_pointer == pid then
            local action = state.editor_pressed_action
            state.editor_pointer = nil
            state.editor_pressed_action = nil
            if action == "done" and (pid ~= "mouse" or inside(x, y, buttons.done)) then
                state.held = { nil, nil, nil, nil, nil, nil }
                state.con = 99
                return
            elseif action == "reset" and (pid ~= "mouse" or inside(x, y, buttons.reset)) then
                storage.resetPositions(state)
                return
            end
        end

        if state.editor_pointer == nil then
            local bs = state.touchscreen_scale[2]
            local controls = {
                { slot = 1, index = 1, halfw = 14 * bs, halfh = 15 * bs },
                { slot = 2, index = 2, halfw = 14 * bs, halfh = 15 * bs },
                { slot = 3, index = 3, halfw = 14 * bs, halfh = 15 * bs },
            }

            for _, c in ipairs(controls) do
                local cx, cy = state.touchscreen_x[c.index], state.touchscreen_y[c.index]
                if state.held[c.slot] == nil and down and not input.isPointerClaimed(state, pid)
                    and x >= cx - c.halfw and x <= cx + c.halfw and y >= cy - c.halfh and y <= cy + c.halfh then
                    state.held[c.slot] = pid
                end
                if state.held[c.slot] == pid then
                    if down then
                        storage.setControlPosition(state, c.index, x, y)
                    else
                        state.held[c.slot] = nil
                    end
                end
            end

            if state.touchscreen_type == 0 or state.touchscreen_type == 1 or state.touchscreen_type == 4 or state.touchscreen_type == 5 then
                local js = state.touchscreen_scale[1]
                local cx, cy = state.touchscreen_x[5], state.touchscreen_y[5]
                local radius = 30 * js
                if state.held[6] == nil and down and not input.isPointerClaimed(state, pid)
                    and x >= cx - radius and x <= cx + radius and y >= cy - radius and y <= cy + radius then
                    state.held[6] = pid
                end
                if state.held[6] == pid then
                    if down then
                        storage.setControlPosition(state, 5, x, y)
                    else
                        state.held[6] = nil
                    end
                end
            end
        end
    end

    state.joybase_x[1] = state.touchscreen_x[5]
    state.joybase_y[1] = state.touchscreen_y[5]
    state.joystick_x[1] = state.joybase_x[1]
    state.joystick_y[1] = state.joybase_y[1]
end

-- Bitmap atlases generated from the provided main_mono.ttf.
local FONT_GLYPHS = [[ !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~áàâãéêíóôõúçÁÀÂÃÉÊÍÓÔÕÚÇ×•]]

local FONT_META = {
    tiny  = { file = "main_mono_tiny.png",  cellw = 7,  cellh = 11, advance = 5 },
    small = { file = "main_mono_small.png", cellw = 8,  cellh = 13, advance = 6 },
    body  = { file = "main_mono_body.png",  cellw = 9,  cellh = 15, advance = 7 },
    title = { file = "main_mono_title.png", cellw = 12, cellh = 21, advance = 10 },
}

local function utf8chars(str)
    local out = {}
    local i = 1
    while i <= #str do
        local b = str:byte(i)
        local n = (b < 0x80 and 1) or (b < 0xE0 and 2) or (b < 0xF0 and 3) or 4
        out[#out + 1] = str:sub(i, i + n - 1)
        i = i + n
    end
    return out
end

local function fontPath(state, file)
    local full = state.script_folder .. "fonts/" .. file
    if love.filesystem and love.filesystem.getInfo then
        if love.filesystem.getInfo(full) then return full end
        if love.filesystem.getInfo("fonts/" .. file) then return "fonts/" .. file end
    end
    return full
end

local function ensureFonts(state)
    if state.menu_fonts then return state.menu_fonts end
    state.menu_fonts = {}
    local glyphs = utf8chars(FONT_GLYPHS)
    for name, meta in pairs(FONT_META) do
        local image = love.graphics.newImage(fontPath(state, meta.file))
        image:setFilter("nearest", "nearest")
        local iw, ih = image:getDimensions()
        local quads = {}
        for i, ch in ipairs(glyphs) do
            quads[ch] = love.graphics.newQuad((i - 1) * meta.cellw, 0, meta.cellw, meta.cellh, iw, ih)
        end
        state.menu_fonts[name] = {
            image = image,
            quads = quads,
            cellw = meta.cellw,
            cellh = meta.cellh,
            advance = meta.advance,
        }
    end
    return state.menu_fonts
end

local function rgba(c, a)
    return c[1], c[2], c[3], (c[4] or 1) * a
end

-- Near-black neutral palette using the launcher's active primary blue.
local launcher_accent = _G.KRISTAL_LAUNCHER_ACCENT
if type(launcher_accent) ~= "table"
    or type(launcher_accent[1]) ~= "number"
    or type(launcher_accent[2]) ~= "number"
    or type(launcher_accent[3]) ~= "number" then
    launcher_accent = {0.290, 0.506, 0.965}
end

local C = {
    panel = {0.012, 0.012, 0.014},
    panel2 = {0.022, 0.022, 0.025},
    surface = {0.040, 0.040, 0.045},
    surface2 = {0.070, 0.070, 0.078},
    line = {0.135, 0.135, 0.145},
    text = {0.965, 0.965, 0.970},
    muted = {0.590, 0.590, 0.620},
    accent = launcher_accent,
    accentSoft = {
        launcher_accent[1] * 0.22,
        launcher_accent[2] * 0.22,
        launcher_accent[3] * 0.22
    },
    danger = {1.000, 0.340, 0.300},
}

local function setc(c, a)
    love.graphics.setColor(rgba(c, a))
end

local function rect(mode, x, y, w, h)
    love.graphics.rectangle(mode, math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5))
end

local function textWidth(fonts, font, str)
    local f = fonts[font]
    return #utf8chars(str) * f.advance
end

local function text(fonts, font, str, x, y, color, a)
    local f = fonts[font]
    setc(color or C.text, a)
    local cursor = math.floor(x + 0.5)
    local py = math.floor(y + 0.5)
    for _, ch in ipairs(utf8chars(str)) do
        local q = f.quads[ch] or f.quads["?"]
        if q then love.graphics.draw(f.image, q, cursor, py) end
        cursor = cursor + f.advance
    end
end

local function centered(fonts, font, str, x, y, w, h, color, a)
    local f = fonts[font]
    local tw = textWidth(fonts, font, str)
    local tx = x + (w - tw) / 2
    local ty = y + (h - f.cellh) / 2
    text(fonts, font, str, tx, ty, color, a)
end

local function wrapped(fonts, font, str, x, y, maxw, color, a, line_gap)
    local words = {}
    for word in str:gmatch("%S+") do words[#words + 1] = word end
    local line = ""
    local yy = y
    local f = fonts[font]
    local step = f.cellh + (line_gap or 2)
    for _, word in ipairs(words) do
        local candidate = (line == "") and word or (line .. " " .. word)
        if line ~= "" and textWidth(fonts, font, candidate) > maxw then
            text(fonts, font, line, x, yy, color, a)
            yy = yy + step
            line = word
        else
            line = candidate
        end
    end
    if line ~= "" then text(fonts, font, line, x, yy, color, a) end
    return yy + step
end

local function button(fonts, id, label, r, selected, pressed, a)
    if selected then
        setc(C.accentSoft, a)
    elseif pressed == id then
        setc(C.surface2, a)
    else
        setc(C.surface, a)
    end
    rect("fill", r.x, r.y, r.w, r.h)
    setc(selected and C.accent or C.line, a)
    love.graphics.setLineWidth(selected and 2 or 1)
    rect("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1)
    centered(fonts, "small", label, r.x + 4, r.y, r.w - 8, r.h, selected and C.text or C.muted, a)
end

local function regionMap(state)
    local regions = getRegions(state)
    local map = {}
    for _, r in ipairs(regions) do map[r.id] = r end
    return map
end

local function directionMode(t)
    if t == 0 or t == 1 then return "fixed" end
    if t == 2 or t == 3 then return "dynamic" end
    if t == 4 then return "dpad4" end
    return "dpad8"
end

local function drawTabs(state, fonts, map, a)
    local tabs = {
        {"tab_controls", tr("tab_controls"), "controls"},
        {"tab_visual", tr("tab_visual"), "visual"},
        {"tab_layout", tr("tab_layout"), "layout"},
    }
    for _, t in ipairs(tabs) do
        button(fonts, t[1], t[2], map[t[1]], state.menu_page == t[3], state.menu_pressed_action, a)
    end
end

local function drawSectionLabel(fonts, label, x, y, w, a)
    text(fonts, "tiny", label, x, y, C.muted, a)
    setc(C.line, a)
    rect("fill", x, y + 14, w, 1)
end

local function sliderRatio(value, minv, maxv)
    return clamp((value - minv) / (maxv - minv), 0, 1)
end

local function slider(fonts, state, id, label, value_text, r, ratio, a)
    local active = state.menu_slider_action == id
    local label_y = r.y
    text(fonts, "small", label, r.x, label_y, C.text, a)
    local vw = textWidth(fonts, "small", value_text)
    text(fonts, "small", value_text, r.x + r.w - vw, label_y, active and C.accent or C.muted, a)

    local tx = r.x + 10
    local ty = r.y + 30
    local tw = r.w - 20
    local th = 6
    setc(C.line, a)
    rect("fill", tx, ty, tw, th)
    setc(C.accent, a)
    rect("fill", tx, ty, math.max(2, tw * ratio), th)

    local knob_x = tx + tw * ratio
    local knob_w, knob_h = 10, 18
    setc(active and C.text or C.accent, a)
    rect("fill", knob_x - knob_w / 2, ty - (knob_h - th) / 2, knob_w, knob_h)
end

local function drawControlsPage(state, fonts, L, map, a)
    local vis = state.menu_return_con ~= -1
    local vr = map.toggle_visibility
    setc(C.surface, a); rect("fill", vr.x, vr.y, vr.w, vr.h)
    setc(C.line, a); rect("line", vr.x + 0.5, vr.y + 0.5, vr.w - 1, vr.h - 1)
    text(fonts, "body", tr("controls_on_screen"), vr.x + 12, vr.y + 5, C.text, a)
    text(fonts, "tiny", tr(vis and "controls_visible" or "controls_hidden"), vr.x + 12, vr.y + 25, C.muted, a)
    local tw, th = 50, 24
    local tx, ty = vr.x + vr.w - tw - 10, vr.y + (vr.h - th) / 2
    setc(vis and C.accentSoft or C.panel2, a); rect("fill", tx, ty, tw, th)
    setc(vis and C.accent or C.muted, a); rect("fill", vis and (tx + 28) or (tx + 4), ty + 4, 18, 16)

    drawSectionLabel(fonts, tr("direction_type"), L.inner_x, map.direction_fixed.y - 20, L.inner_w, a)
    local mode = directionMode(state.touchscreen_type)
    button(fonts, "direction_fixed", tr("direction_fixed"), map.direction_fixed, mode == "fixed", state.menu_pressed_action, a)
    button(fonts, "direction_dynamic", tr("direction_dynamic"), map.direction_dynamic, mode == "dynamic", state.menu_pressed_action, a)
    button(fonts, "direction_dpad4", tr("direction_dpad4"), map.direction_dpad4, mode == "dpad4", state.menu_pressed_action, a)
    button(fonts, "direction_dpad8", tr("direction_dpad8"), map.direction_dpad8, mode == "dpad8", state.menu_pressed_action, a)

    drawSectionLabel(fonts, tr("direction_style"), L.inner_x, map.analog_style_0.y - 20, L.inner_w, a)
    if state.touchscreen_type <= 3 then
        local style3d = (state.touchscreen_type == 1 or state.touchscreen_type == 3)
        button(fonts, "analog_style_0", "2D", map.analog_style_0, not style3d, state.menu_pressed_action, a)
        button(fonts, "analog_style_1", "3D", map.analog_style_1, style3d, state.menu_pressed_action, a)
    else
        setc(C.panel2, a); rect("fill", map.analog_style_0.x, map.analog_style_0.y, L.inner_w, map.analog_style_0.h)
        centered(fonts, "tiny", tr("analog_modes_only"), map.analog_style_0.x, map.analog_style_0.y, L.inner_w, map.analog_style_0.h, C.muted, a)
    end

    drawSectionLabel(fonts, tr("dead_zone"), L.inner_x, map.slider_deadzone.y - 18, L.inner_w, a)
    slider(fonts, state, "slider_deadzone", tr("analog_response"), string.format("%d%%", math.floor(state.touchscreen_deadzone * 100 + 0.5)),
        map.slider_deadzone, sliderRatio(state.touchscreen_deadzone, 0.10, 0.90), a)
end

local function drawVisualPage(state, fonts, L, map, a)
    drawSectionLabel(fonts, tr("scale"), L.inner_x, L.content_y - 1, L.inner_w, a)

    slider(fonts, state, "slider_joy_size", tr("direction_size"), string.format("%.2fx", state.touchscreen_scale[1]),
        map.slider_joy_size, sliderRatio(state.touchscreen_scale[1], 1.80, 3.60), a)

    slider(fonts, state, "slider_button_size", tr("button_size"), string.format("%.2fx", state.touchscreen_scale[2]),
        map.slider_button_size, sliderRatio(state.touchscreen_scale[2], 1.80, 3.60), a)

    drawSectionLabel(fonts, tr("visibility"), L.inner_x, map.slider_opacity.y - 18, L.inner_w, a)
    slider(fonts, state, "slider_opacity", tr("opacity"), string.format("%d%%", math.floor(state.touchscreen_opacity * 100 + 0.5)),
        map.slider_opacity, sliderRatio(state.touchscreen_opacity, 0.20, 1.00), a)

    if map.slider_appearance then
        drawSectionLabel(fonts, tr("button_appearance"), L.inner_x, map.slider_appearance.y - 18, L.inner_w, a)
        slider(fonts, state, "slider_appearance", tr("variation"), tostring(math.floor(state.touchscreen_color)),
            map.slider_appearance, sliderRatio(state.touchscreen_color, 1, 9), a)
    end
end

local function drawLayoutPage(state, fonts, L, map, a)
    text(fonts, "body", tr("layout_intro"), L.inner_x, L.content_y + 1, C.text, a)
    wrapped(fonts, "tiny", tr("layout_help"), L.inner_x, L.content_y + 24, L.inner_w, C.muted, a, 1)

    local r = map.edit_layout
    setc(C.accentSoft, a); rect("fill", r.x, r.y, r.w, r.h)
    setc(C.accent, a); rect("fill", r.x, r.y, 4, r.h)
    text(fonts, "body", tr("edit_positions"), r.x + 14, r.y + 7, C.text, a)
    text(fonts, "tiny", tr("edit_hint"), r.x + 14, r.y + 31, C.muted, a)
    setc(C.accent, a); love.graphics.polygon("fill", r.x + r.w - 30, r.y + 20, r.x + r.w - 20, r.y + 27, r.x + r.w - 30, r.y + 34)

    r = map.reset_positions
    setc(C.surface, a); rect("fill", r.x, r.y, r.w, r.h)
    setc(C.line, a); rect("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1)
    text(fonts, "small", tr("reset_positions_only"), r.x + 12, r.y + 6, C.text, a)
    text(fonts, "tiny", tr("keep_visual_settings"), r.x + 12, r.y + 25, C.muted, a)
end

function settings_menu.draw(state)
    if state.settings_alpha <= 0 then return end
    local fonts = ensureFonts(state)
    local a = state.settings_alpha
    local _, gui_w = guiMetrics(state)
    local map, L = regionMap(state), menuLayout(state)

    setc({0, 0, 0, 0.82}, a)
    rect("fill", 0, 0, gui_w, 480)

    setc(C.panel, a); rect("fill", L.x, L.y, L.w, L.h)
    setc(C.line, a); love.graphics.setLineWidth(1); rect("line", L.x + 0.5, L.y + 0.5, L.w - 1, L.h - 1)
    setc(C.panel2, a); rect("fill", L.x + 1, L.y + 1, L.w - 2, 50)
    setc(C.line, a); rect("fill", L.x + 1, L.y + 51, L.w - 2, 1)

    text(fonts, "title", tr("title"), L.inner_x, L.header_y - 2, C.text, a)
    text(fonts, "tiny", tr("subtitle"), L.inner_x, L.header_y + 27, C.muted, a)

    local cr = map.close
    setc(state.menu_pressed_action == "close" and C.surface2 or C.surface, a)
    rect("fill", cr.x, cr.y, cr.w, cr.h)
    setc(C.line, a); rect("line", cr.x + 0.5, cr.y + 0.5, cr.w - 1, cr.h - 1)
    centered(fonts, "body", "×", cr.x, cr.y - 1, cr.w, cr.h, C.text, a)

    drawTabs(state, fonts, map, a)

    if state.menu_page == "controls" then
        drawControlsPage(state, fonts, L, map, a)
    elseif state.menu_page == "visual" then
        drawVisualPage(state, fonts, L, map, a)
    else
        drawLayoutPage(state, fonts, L, map, a)
    end

    setc(C.panel2, a)
    rect("fill", L.x + 1, L.footer_y - 8, L.w - 2, L.h - (L.footer_y - L.y) + 7)
    setc(C.line, a); rect("fill", L.x + 1, L.footer_y - 8, L.w - 2, 1)

    local rr = map.reset_all
    setc(state.menu_reset_confirm and {0.20, 0.035, 0.025} or C.surface, a)
    rect("fill", rr.x, rr.y, rr.w, rr.h)
    setc(state.menu_reset_confirm and C.danger or C.line, a)
    rect("line", rr.x + 0.5, rr.y + 0.5, rr.w - 1, rr.h - 1)
    centered(fonts, "tiny", tr(state.menu_reset_confirm and "confirm_reset" or "restore_defaults"), rr.x, rr.y, rr.w, rr.h, state.menu_reset_confirm and C.danger or C.muted, a)

    local dr = map.done
    setc(C.accent, a); rect("fill", dr.x, dr.y, dr.w, dr.h)
    centered(fonts, "small", tr("done"), dr.x, dr.y, dr.w, dr.h, C.panel, a)
end

function settings_menu.drawLayoutEditor(state)
    if state.con ~= 98 then return end
    local fonts = ensureFonts(state)
    local buttons, gui_w = editorRects(state)

    love.graphics.setColor(0, 0, 0, 0.82)
    rect("fill", 156, 12, math.max(200, gui_w - 312), 42)
    setc(C.line, 1); rect("line", 156.5, 12.5, math.max(199, gui_w - 313), 41)
    centered(fonts, "small", tr("edit_mode"), 164, 12, math.max(184, gui_w - 328), 42, C.text, 1)

    setc(C.surface, 1); rect("fill", buttons.reset.x, buttons.reset.y, buttons.reset.w, buttons.reset.h)
    setc(C.line, 1); rect("line", buttons.reset.x + 0.5, buttons.reset.y + 0.5, buttons.reset.w - 1, buttons.reset.h - 1)
    centered(fonts, "tiny", tr("reset_positions"), buttons.reset.x, buttons.reset.y, buttons.reset.w, buttons.reset.h, C.text, 1)

    setc(C.accent, 1); rect("fill", buttons.done.x, buttons.done.y, buttons.done.w, buttons.done.h)
    centered(fonts, "small", tr("done"), buttons.done.x, buttons.done.y, buttons.done.w, buttons.done.h, C.panel, 1)
end

return settings_menu
