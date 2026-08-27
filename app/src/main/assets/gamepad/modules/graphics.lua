local graphics = {}

local math_utils = require((...):match("(.-)[^%.]+$") .. "math_utils")
local settings_menu = require((...):match("(.-)[^%.]+$") .. "settings_menu")

function graphics.getSpritePath(state, relPath)
    local fullPath = state.script_folder .. "sprites/" .. relPath
    if love.filesystem and love.filesystem.getInfo then
        if love.filesystem.getInfo(fullPath) then
            return fullPath
        elseif love.filesystem.getInfo("sprites/" .. relPath) then
            return "sprites/" .. relPath
        end
    end
    return fullPath
end

function graphics.loadSprites(state)
    state.spr.jb[0] = love.graphics.newImage(graphics.getSpritePath(state, "spr_vgamepad_jb_0.png"))
    state.spr.jb[1] = love.graphics.newImage(graphics.getSpritePath(state, "spr_vgamepad_jb_1.png"))
    state.spr.js[0] = love.graphics.newImage(graphics.getSpritePath(state, "spr_vgamepad_js_0.png"))
    state.spr.js[1] = love.graphics.newImage(graphics.getSpritePath(state, "spr_vgamepad_js_1.png"))

    for i = 0, 9 do
        state.spr.z[i] = love.graphics.newImage(graphics.getSpritePath(state, string.format("spr_vgamepad_z/spr_vgamepad_z_%d.png", i)))
        state.spr.x[i] = love.graphics.newImage(graphics.getSpritePath(state, string.format("spr_vgamepad_x/spr_vgamepad_x_%d.png", i)))
        state.spr.c[i] = love.graphics.newImage(graphics.getSpritePath(state, string.format("spr_vgamepad_c/spr_vgamepad_c_%d.png", i)))
        state.spr.s[i] = love.graphics.newImage(graphics.getSpritePath(state, string.format("spr_vgamepad_s/spr_vgamepad_s_%d.png", i)))
        state.spr.su[i] = love.graphics.newImage(graphics.getSpritePath(state, string.format("spr_vgamepad_su/spr_vgamepad_su_%d.png", i)))
    end

    for i = 0, 8 do
        state.spr.dp[i] = love.graphics.newImage(graphics.getSpritePath(state, string.format("spr_vgamepad_dp/spr_vgamepad_dp_%d.png", i)))
    end
end

function graphics.drawControls(state)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas()
    love.graphics.setShader()
    love.graphics.setScissor()
    love.graphics.setBlendMode("alpha", "alphamultiply")
    local gui_h = 480
    local scale = state.SH / gui_h
    love.graphics.scale(scale, scale)

    local style = (state.touchscreen_type == 0 or state.touchscreen_type == 2) and 0 or 1

    -- Hard visibility gate. The settings button remains independent below, but
    -- gameplay controls are never rendered with a stale alpha when the saved
    -- visibility is hidden. This prevents one-frame flashes around menu changes.
    local controls_hidden = state.con < 0
    if state.con == 99 or state.con == 98 then
        controls_hidden = (state.menu_return_con or 0) < 0
    end
    local controls_alpha = controls_hidden and 0 or state.image_alpha

    local j_alpha = controls_alpha * math_utils.clamp(state.joystick_alpha[1], 0, 1)
    local s_joy = state.touchscreen_scale[1] * state.pops.joy.s
    love.graphics.setColor(1, 1, 1, j_alpha)

    if state.touchscreen_type == 4 or state.touchscreen_type == 5 then
        -- Draw D-PAD
        local f = 0
        local L, U, R, D = state.key_state[1], state.key_state[2], state.key_state[3], state.key_state[4]
        if R == 1 and U == 1 then f = 5
        elseif R == 1 and D == 1 then f = 6
        elseif L == 1 and D == 1 then f = 7
        elseif L == 1 and U == 1 then f = 8
        elseif R == 1 then f = 1
        elseif D == 1 then f = 2
        elseif L == 1 then f = 3
        elseif U == 1 then f = 4
        end
        love.graphics.draw(state.spr.dp[f], state.joybase_x[1], state.joybase_y[1], 0, s_joy, s_joy, 30, 30)
    else
        -- Draw Analog Joystick
        love.graphics.draw(state.spr.jb[style], state.joybase_x[1], state.joybase_y[1], 0, s_joy, s_joy, 30, 30)
        love.graphics.draw(state.spr.js[style], state.joystick_x[1], state.joystick_y[1], 0, s_joy, s_joy, 21, 21)
    end

    local c_frame = (state.key_state[7] == 1) and math.floor(state.touchscreen_color) or 0
    local s_c = state.touchscreen_scale[2] * state.pops.c.s
    love.graphics.setColor(1, 1, 1, controls_alpha)
    love.graphics.draw(state.spr.c[c_frame], state.touchscreen_x[3], state.touchscreen_y[3], 0, s_c, s_c, 14, 15)

    local x_frame = (state.key_state[6] == 1) and math.floor(state.touchscreen_color) or 0
    local s_x = state.touchscreen_scale[2] * state.pops.x.s
    love.graphics.setColor(1, 1, 1, controls_alpha)
    love.graphics.draw(state.spr.x[x_frame], state.touchscreen_x[2], state.touchscreen_y[2], 0, s_x, s_x, 14, 15)

    local z_frame = (state.key_state[5] == 1) and math.floor(state.touchscreen_color) or 0
    local s_z = state.touchscreen_scale[2] * state.pops.z.s
    love.graphics.setColor(1, 1, 1, controls_alpha)
    love.graphics.draw(state.spr.z[z_frame], state.touchscreen_x[1], state.touchscreen_y[1], 0, s_z, s_z, 14, 15)

    if not state.settings_hide then
        local s_frame = (state.settings_z == 1) and math.floor(state.touchscreen_color) or 0
        -- The settings button is the escape hatch when gameplay controls are hidden.
        -- Never let the gamepad hide/pop animation shrink this button to zero.
        local settings_pop = controls_hidden and 1 or state.pops.s.s
        local s_s = 2.5 * settings_pop
        love.graphics.setColor(1, 1, 1, state.touchscreen_opacity)
        love.graphics.draw(state.spr.s[s_frame], state.settings_x, state.settings_y, 0, s_s, s_s, 10, 12)
    end

    if not state.speedUp_hide then
        local su_frame = state.speedUp_isActive and math.floor(state.touchscreen_color) or 0
        local s_su = 2.5 * state.pops.su.s
        love.graphics.setColor(1, 1, 1, controls_alpha)
        love.graphics.draw(state.spr.su[su_frame], state.speedUp_x, state.speedUp_y, 0, s_su, s_su, 10, 12)
    end

    -- The reworked settings UI is drawn last so it always sits above the gamepad.
    settings_menu.draw(state)
    settings_menu.drawLayoutEditor(state)

    love.graphics.pop()
end

return graphics
