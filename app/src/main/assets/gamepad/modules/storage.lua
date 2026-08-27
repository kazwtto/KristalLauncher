local storage = {}

local LAYOUT_VERSION = 2
local GUI_H = 480
local CONTROL_INDICES = { 1, 2, 3, 5 }
local DEFAULT_RIGHT = { [1] = 198, [2] = 143, [3] = 88 }
local DEFAULT_BOTTOM = { [1] = 55, [2] = 115, [3] = 175, [5] = 130 }
local DEFAULT_J_LEFT = 120
local CUSTOM_BIT = { [1] = 1, [2] = 2, [3] = 4, [5] = 8 }

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function finiteNumber(value, fallback, lo, hi)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return fallback
    end
    if lo and hi then return clamp(value, lo, hi) end
    return value
end

local function approx(a, b, eps)
    return math.abs((a or 0) - (b or 0)) <= (eps or 1.0)
end

local function maskHas(mask, bit)
    return math.floor((mask or 0) / bit) % 2 == 1
end

local function buildMask(state)
    local mask = 0
    for _, index in ipairs(CONTROL_INDICES) do
        if state.layout_custom[index] then
            mask = mask + CUSTOM_BIT[index]
        end
    end
    return mask
end

function storage.guiMetrics(state)
    local scale = state.SH / GUI_H
    if scale <= 0 then scale = 1 end
    local gui_w = state.SW / scale
    return scale, gui_w, GUI_H
end

function storage.recalcDefaultPositions(state)
    local _, gui_w, gui_h = storage.guiMetrics(state)

    -- Action buttons are a compact group anchored to the physical right edge.
    -- Their internal spacing never expands on ultrawide screens.
    state.defaultZx = gui_w - DEFAULT_RIGHT[1]
    state.defaultZy = gui_h - DEFAULT_BOTTOM[1]
    state.defaultXx = gui_w - DEFAULT_RIGHT[2]
    state.defaultXy = gui_h - DEFAULT_BOTTOM[2]
    state.defaultCx = gui_w - DEFAULT_RIGHT[3]
    state.defaultCy = gui_h - DEFAULT_BOTTOM[3]

    -- Joystick/D-Pad is anchored to the physical left/bottom edges.
    state.defaultJx = DEFAULT_J_LEFT
    state.defaultJy = gui_h - DEFAULT_BOTTOM[5]

    -- Utility buttons use fixed offsets from the physical top-left edge.
    state.settings_x = 36.666666667
    state.settings_y = 40
    state.speedUp_x = 96.666666667
    state.speedUp_y = 40
end

local function defaultPosition(state, index)
    if index == 1 then return state.defaultZx, state.defaultZy end
    if index == 2 then return state.defaultXx, state.defaultXy end
    if index == 3 then return state.defaultCx, state.defaultCy end
    return state.defaultJx, state.defaultJy
end

local function ensureLayoutTables(state)
    state.layout_custom = state.layout_custom or {}
    state.layout_offset_x = state.layout_offset_x or {}
    state.layout_offset_y = state.layout_offset_y or {}

    for _, index in ipairs(CONTROL_INDICES) do
        if state.layout_custom[index] == nil then state.layout_custom[index] = false end
        if state.layout_offset_x[index] == nil then
            state.layout_offset_x[index] = (index == 5) and DEFAULT_J_LEFT or DEFAULT_RIGHT[index]
        end
        if state.layout_offset_y[index] == nil then
            state.layout_offset_y[index] = DEFAULT_BOTTOM[index]
        end
    end
end

local function controlExtents(state, index)
    if index == 5 then
        local s = math.abs(state.touchscreen_scale[1] or 2.5)
        return 30 * s, 29 * s, 30 * s, 29 * s
    end

    local s = math.abs(state.touchscreen_scale[2] or 2.5)
    return 14 * s, 13 * s, 15 * s, 14 * s
end

function storage.clampControlPosition(state, index, x, y)
    local _, gui_w, gui_h = storage.guiMetrics(state)
    local left_e, right_e, top_e, bottom_e = controlExtents(state, index)
    local min_x, max_x

    if index == 5 then
        min_x = left_e
        max_x = (gui_w * 0.5) - right_e
    else
        min_x = (gui_w * 0.5) + left_e
        max_x = gui_w - right_e
    end

    local min_y = top_e
    local max_y = gui_h - bottom_e

    if min_x > max_x then
        local cx = gui_w * 0.5
        min_x, max_x = cx, cx
    end
    if min_y > max_y then
        local cy = gui_h * 0.5
        min_y, max_y = cy, cy
    end

    return clamp(x, min_x, max_x), clamp(y, min_y, max_y)
end

function storage.setControlPosition(state, index, x, y)
    ensureLayoutTables(state)
    local _, gui_w, gui_h = storage.guiMetrics(state)
    x, y = storage.clampControlPosition(state, index, x, y)

    state.touchscreen_x[index] = x
    state.touchscreen_y[index] = y
    state.layout_custom[index] = true

    if index == 5 then
        state.layout_offset_x[index] = x
    else
        state.layout_offset_x[index] = gui_w - x
    end
    state.layout_offset_y[index] = gui_h - y
    state.config_changed = true
end

function storage.resolveLayout(state)
    ensureLayoutTables(state)
    storage.recalcDefaultPositions(state)
    local _, gui_w, gui_h = storage.guiMetrics(state)

    for _, index in ipairs(CONTROL_INDICES) do
        local x, y
        if state.layout_custom[index] then
            if index == 5 then
                x = state.layout_offset_x[index]
            else
                x = gui_w - state.layout_offset_x[index]
            end
            y = gui_h - state.layout_offset_y[index]
        else
            x, y = defaultPosition(state, index)
        end

        -- Soft clamp: keep the saved offset untouched. If the screen later gets
        -- larger again, a customized control returns to the exact chosen offset.
        x, y = storage.clampControlPosition(state, index, x, y)
        state.touchscreen_x[index] = x
        state.touchscreen_y[index] = y
    end

    if state.held == nil or state.held[5] == nil then
        state.joybase_x[1] = state.touchscreen_x[5]
        state.joybase_y[1] = state.touchscreen_y[5]
        state.joystick_x[1] = state.joybase_x[1]
        state.joystick_y[1] = state.joybase_y[1]
    end

    state.layout_last_gui_w = gui_w
    state.layout_last_gui_h = gui_h
end

function storage.onResize(state)
    storage.resolveLayout(state)
end

function storage.sanitizePositions(state)
    -- Kept for compatibility with the old callers. The responsive resolver is
    -- now the single source of truth and handles every aspect ratio continuously.
    storage.resolveLayout(state)
end

local function inferLegacyActionDefaults(state)
    -- Old builds already used the same compact geometry, but did not save the
    -- source GUI width. Recover it from any two untouched action buttons.
    local candidates = {}
    local default_y = { [1] = GUI_H - DEFAULT_BOTTOM[1], [2] = GUI_H - DEFAULT_BOTTOM[2], [3] = GUI_H - DEFAULT_BOTTOM[3] }
    for i = 1, 3 do
        if approx(state.touchscreen_y[i], default_y[i], 1.5) then
            candidates[i] = state.touchscreen_x[i] + DEFAULT_RIGHT[i]
        end
    end

    local inferred = nil
    for i = 1, 3 do
        for j = i + 1, 3 do
            if candidates[i] and candidates[j] and approx(candidates[i], candidates[j], 1.5) then
                inferred = (candidates[i] + candidates[j]) * 0.5
                break
            end
        end
        if inferred then break end
    end
    return candidates, inferred
end

local function migrateLegacyLayout(state)
    ensureLayoutTables(state)
    storage.recalcDefaultPositions(state)
    local _, gui_w, gui_h = storage.guiMetrics(state)
    local candidates, inferred_w = inferLegacyActionDefaults(state)

    for _, index in ipairs(CONTROL_INDICES) do
        local is_default = false
        local def_x, def_y = defaultPosition(state, index)

        if approx(state.touchscreen_x[index], def_x, 1.5) and approx(state.touchscreen_y[index], def_y, 1.5) then
            is_default = true
        elseif index <= 3 and inferred_w and candidates[index] and approx(candidates[index], inferred_w, 1.5) then
            is_default = true
        elseif index == 5 and approx(state.touchscreen_x[5], DEFAULT_J_LEFT, 1.5)
            and approx(state.touchscreen_y[5], GUI_H - DEFAULT_BOTTOM[5], 1.5) then
            is_default = true
        end

        state.layout_custom[index] = not is_default
        if is_default then
            state.layout_offset_x[index] = (index == 5) and DEFAULT_J_LEFT or DEFAULT_RIGHT[index]
            state.layout_offset_y[index] = DEFAULT_BOTTOM[index]
        else
            if index == 5 then
                state.layout_offset_x[index] = state.touchscreen_x[index]
            else
                state.layout_offset_x[index] = gui_w - state.touchscreen_x[index]
            end
            state.layout_offset_y[index] = gui_h - state.touchscreen_y[index]
        end
    end
end

local function writeConfig(state, visible_con)
    ensureLayoutTables(state)
    local _, gui_w = storage.guiMetrics(state)
    local mask = buildMask(state)

    return string.format([[return {
    Zx = %.1f,
    Zy = %.1f,
    Xx = %.1f,
    Xy = %.1f,
    Cx = %.1f,
    Cy = %.1f,
    Jx = %.1f,
    Jy = %.1f,
    JoystickScale = %.2f,
    ButtonScale = %.2f,
    Deadzone = %.2f,
    Type = %d,
    Opacity = %.2f,
    Color = %d,
    Visible = %d,
    LayoutVersion = %d,
    LayoutCustomMask = %d,
    ZRightOffset = %.3f,
    ZBottomOffset = %.3f,
    XRightOffset = %.3f,
    XBottomOffset = %.3f,
    CRightOffset = %.3f,
    CBottomOffset = %.3f,
    JLeftOffset = %.3f,
    JBottomOffset = %.3f,
    LayoutSavedGuiWidth = %.3f
}]],
        state.touchscreen_x[1], state.touchscreen_y[1],
        state.touchscreen_x[2], state.touchscreen_y[2],
        state.touchscreen_x[3], state.touchscreen_y[3],
        state.touchscreen_x[5], state.touchscreen_y[5],
        state.touchscreen_scale[1], state.touchscreen_scale[2],
        state.touchscreen_deadzone,
        math.floor(state.touchscreen_type),
        state.touchscreen_opacity,
        math.floor(state.touchscreen_color),
        math.floor(visible_con),
        LAYOUT_VERSION,
        mask,
        state.layout_offset_x[1], state.layout_offset_y[1],
        state.layout_offset_x[2], state.layout_offset_y[2],
        state.layout_offset_x[3], state.layout_offset_y[3],
        state.layout_offset_x[5], state.layout_offset_y[5],
        gui_w
    )
end

function storage.saveTouchConfig(state)
    if not state.config_changed then return end
    storage.resolveLayout(state)

    local visible_con = state.con
    if state.con == 99 or state.con == 98 then
        visible_con = state.menu_return_con or 0
    end

    local str = writeConfig(state, visible_con)

    if not (love and love.filesystem and love.filesystem.write) then
        error("LÖVE filesystem storage is unavailable")
    end
    local success, message = love.filesystem.write("touch_config.lua", str)
    if not success then
        error("Unable to save the virtual gamepad configuration: " .. tostring(message))
    end
    state.config_changed = false
end

local function loadConfigChunk()
    local chunk = nil
    if love and love.filesystem and love.filesystem.load then
        chunk = love.filesystem.load("touch_config.lua")
    end
    return chunk
end

function storage.loadTouchConfig(state)
    storage.recalcDefaultPositions(state)
    ensureLayoutTables(state)
    state.touchscreen_x = { state.defaultZx, state.defaultXx, state.defaultCx, 0, state.defaultJx }
    state.touchscreen_y = { state.defaultZy, state.defaultXy, state.defaultCy, 0, state.defaultJy }

    local chunk = loadConfigChunk()
    local data = nil
    if chunk then
        local success, result = pcall(chunk)
        if success and type(result) == "table" then
            data = result
        elseif not success then
            print("Kristal Launcher: ignoring an invalid virtual gamepad configuration: " .. tostring(result))
        end
    end

    if data then
        state.touchscreen_x[1] = finiteNumber(data.Zx, state.touchscreen_x[1])
        state.touchscreen_y[1] = finiteNumber(data.Zy, state.touchscreen_y[1])
        state.touchscreen_x[2] = finiteNumber(data.Xx, state.touchscreen_x[2])
        state.touchscreen_y[2] = finiteNumber(data.Xy, state.touchscreen_y[2])
        state.touchscreen_x[3] = finiteNumber(data.Cx, state.touchscreen_x[3])
        state.touchscreen_y[3] = finiteNumber(data.Cy, state.touchscreen_y[3])
        state.touchscreen_x[5] = finiteNumber(data.Jx, state.touchscreen_x[5])
        state.touchscreen_y[5] = finiteNumber(data.Jy, state.touchscreen_y[5])

        state.touchscreen_scale[1] = finiteNumber(data.JoystickScale, state.touchscreen_scale[1], 0.5, 4.0)
        state.touchscreen_scale[2] = finiteNumber(data.ButtonScale, state.touchscreen_scale[2], 0.5, 4.0)
        state.touchscreen_deadzone = finiteNumber(data.Deadzone, state.touchscreen_deadzone, 0, 1)
        state.touchscreen_type = math.floor(finiteNumber(data.Type, state.touchscreen_type, 0, 5))
        state.touchscreen_opacity = finiteNumber(data.Opacity, state.touchscreen_opacity, 0.1, 1)
        state.touchscreen_color = math.floor(finiteNumber(data.Color, state.touchscreen_color, 0, 9))
        state.con = data.Visible == -1 and -1 or 0

        if (data.LayoutVersion or 0) >= LAYOUT_VERSION
            and data.ZRightOffset and data.XRightOffset and data.CRightOffset and data.JLeftOffset then
            local mask = data.LayoutCustomMask or 0
            for _, index in ipairs(CONTROL_INDICES) do
                state.layout_custom[index] = maskHas(mask, CUSTOM_BIT[index])
            end
            state.layout_offset_x[1] = data.ZRightOffset
            state.layout_offset_y[1] = data.ZBottomOffset or DEFAULT_BOTTOM[1]
            state.layout_offset_x[2] = data.XRightOffset
            state.layout_offset_y[2] = data.XBottomOffset or DEFAULT_BOTTOM[2]
            state.layout_offset_x[3] = data.CRightOffset
            state.layout_offset_y[3] = data.CBottomOffset or DEFAULT_BOTTOM[3]
            state.layout_offset_x[5] = data.JLeftOffset
            state.layout_offset_y[5] = data.JBottomOffset or DEFAULT_BOTTOM[5]
        else
            migrateLegacyLayout(state)
            state.config_changed = true
        end
    else
        for _, index in ipairs(CONTROL_INDICES) do
            state.layout_custom[index] = false
            state.layout_offset_x[index] = (index == 5) and DEFAULT_J_LEFT or DEFAULT_RIGHT[index]
            state.layout_offset_y[index] = DEFAULT_BOTTOM[index]
        end
    end

    storage.resolveLayout(state)

    if state.con ~= 0 and state.con ~= -1 then state.con = 0 end
    state.menu_return_con = state.con
    state.image_alpha = (state.con < 0) and 0 or state.touchscreen_opacity
    state.settings_alpha = 0
end

function storage.resetPositions(state)
    ensureLayoutTables(state)
    for _, index in ipairs(CONTROL_INDICES) do
        state.layout_custom[index] = false
        state.layout_offset_x[index] = (index == 5) and DEFAULT_J_LEFT or DEFAULT_RIGHT[index]
        state.layout_offset_y[index] = DEFAULT_BOTTOM[index]
    end
    storage.resolveLayout(state)
    state.config_changed = true
end

function storage.resetDefaults(state)
    state.touchscreen_deadzone = 0.5
    state.touchscreen_scale = { 2.5, 2.5 }
    state.touchscreen_type = 2
    state.touchscreen_opacity = 0.7
    state.touchscreen_color = state.defaultColor
    storage.resetPositions(state)
    state.config_changed = true
    storage.saveTouchConfig(state)
end

return storage
