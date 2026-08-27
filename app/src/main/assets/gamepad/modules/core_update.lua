local core_update = {}

local math_utils = require((...):match("(.-)[^%.]+$") .. "math_utils")
local input = require((...):match("(.-)[^%.]+$") .. "input")
local settings_menu = require((...):match("(.-)[^%.]+$") .. "settings_menu")

function core_update.updateControls(state, dt)
    input.updatePointerStates(state)

    local fade_speed = 3.0
    -- Menu states (98/99) must inherit the visibility that existed before
    -- opening the menu. Otherwise con = 99 is incorrectly treated as
    -- "controls visible" and image_alpha briefly rises from zero.
    local controls_visible = state.con >= 0
    if state.con == 99 or state.con == 98 then
        controls_visible = (state.menu_return_con or 0) >= 0
    end

    if controls_visible then
        state.image_alpha = math.min(state.image_alpha + fade_speed * dt, state.touchscreen_opacity)
    elseif state.con == 99 or state.con == 98 then
        -- If the user entered settings with the gamepad hidden, keep it
        -- absolutely hidden while opening/closing pages: no transition frame.
        state.image_alpha = 0
    else
        state.image_alpha = math.max(state.image_alpha - fade_speed * dt, 0)
    end

    if state.con == 99 then
        state.settings_alpha = math.min(state.settings_alpha + fade_speed * dt, 1)
    else
        state.settings_alpha = math.max(state.settings_alpha - fade_speed * dt, 0)
    end

    local safe_dt = math.min(dt, 0.05)
    if state.enable_pop_animations then
        if not state.pops_done then
            if state.con >= 0 then
                state.pop_timer = state.pop_timer + safe_dt
                for k, p in pairs(state.pops) do
                    if state.pop_timer >= p.delay then
                        local f = 200 * (1 - p.s)
                        p.v = p.v + f * safe_dt
                        p.v = p.v * math.max(0, 1 - 12 * safe_dt)
                        p.s = p.s + p.v * safe_dt
                    else
                        p.s = 0
                        p.v = 0
                    end
                end
            else
                state.pop_timer = 0
                for k, p in pairs(state.pops) do
                    p.s = p.s + (0 - p.s) * 20 * safe_dt
                    p.v = 0
                end
            end

            local all_done = true
            for k, p in pairs(state.pops) do
                if p.s < 0.98 then
                    all_done = false
                    break
                end
            end
            if all_done then
                state.pops_done = true
            end
        else
            for k, p in pairs(state.pops) do p.s = 1; p.v = 0 end
        end
    else
        for k, p in pairs(state.pops) do p.s = 1; p.v = 0 end
    end

    state.settings_z = 0
    local _key_state = state.next_key_state
    for i = 1, 7 do _key_state[i] = 0 end
    local _joystick_fade = state.next_joystick_fade
    _joystick_fade[1] = 0

    local gui_h = 480
    local scale = state.SH / gui_h
    local gui_w = state.SW / scale

    if state.con == 99 then
        settings_menu.update(state)
        return
    elseif state.con == 98 then
        settings_menu.updateLayoutEditor(state)
        return
    end

    for pid, ptr in pairs(state.currentPointers) do
        local _x = ptr.x
        local _y = ptr.y
        local _held = ptr.down and 1 or 0

        if state.con == -1 then
            -- Settings button: a normal click always opens the menu.
            if not state.settings_hide then
                local x0 = state.settings_x - (10 * 2.5)
                local y0 = state.settings_y - (12 * 2.5)
                local x1 = x0 + (19 * 2.5)
                local y1 = y0 + (23 * 2.5)

                if state.held[4] == nil and not input.isPointerClaimed(state, pid) and _held == 1 and _x > x0 and _x < x1 and _y > y0 and _y < y1 then
                    state.held[4] = pid
                end

                if state.held[4] == pid then
                    if _held == 1 then
                        state.settings_z = 1
                    else
                        state.held[4] = nil
                        settings_menu.open(state, -1)
                    end
                end
            end

        elseif state.con == 0 then
            -- Z Button
            local z_x0 = state.touchscreen_x[1] - (14 * state.touchscreen_scale[2])
            local z_y0 = state.touchscreen_y[1] - (15 * state.touchscreen_scale[2])
            local z_x1 = z_x0 + (27 * state.touchscreen_scale[2])
            local z_y1 = z_y0 + (29 * state.touchscreen_scale[2])

            if state.held[1] == nil and not input.isPointerClaimed(state, pid) and _held == 1 and _x > z_x0 and _x < z_x1 and _y > z_y0 and _y < z_y1 then
                state.held[1] = pid
            end
            if state.held[1] == pid then
                if _held == 1 then
                    _key_state[5] = (_x > z_x0 and _x < z_x1 and _y > z_y0 and _y < z_y1) and 1 or 0
                else
                    _key_state[5] = 0
                    state.held[1] = nil
                end
            end

            -- X Button
            local x_x0 = state.touchscreen_x[2] - (14 * state.touchscreen_scale[2])
            local x_y0 = state.touchscreen_y[2] - (15 * state.touchscreen_scale[2])
            local x_x1 = x_x0 + (27 * state.touchscreen_scale[2])
            local x_y1 = x_y0 + (29 * state.touchscreen_scale[2])

            if state.held[2] == nil and not input.isPointerClaimed(state, pid) and _held == 1 and _x > x_x0 and _x < x_x1 and _y > x_y0 and _y < x_y1 then
                state.held[2] = pid
            end
            if state.held[2] == pid then
                if _held == 1 then
                    _key_state[6] = (_x > x_x0 and _x < x_x1 and _y > x_y0 and _y < x_y1) and 1 or 0
                else
                    _key_state[6] = 0
                    state.held[2] = nil
                end
            end

            -- C Button
            local c_x0 = state.touchscreen_x[3] - (14 * state.touchscreen_scale[2])
            local c_y0 = state.touchscreen_y[3] - (15 * state.touchscreen_scale[2])
            local c_x1 = c_x0 + (27 * state.touchscreen_scale[2])
            local c_y1 = c_y0 + (29 * state.touchscreen_scale[2])

            if state.held[3] == nil and not input.isPointerClaimed(state, pid) and _held == 1 and _x > c_x0 and _x < c_x1 and _y > c_y0 and _y < c_y1 then
                state.held[3] = pid
            end
            if state.held[3] == pid then
                if _held == 1 then
                    _key_state[7] = (_x > c_x0 and _x < c_x1 and _y > c_y0 and _y < c_y1) and 1 or 0
                else
                    _key_state[7] = 0
                    state.held[3] = nil
                end
            end

            -- Settings Button: click to open. No hold gesture and no hidden shortcut.
            if not state.settings_hide then
                local s_x0 = state.settings_x - (10 * 2.5)
                local s_y0 = state.settings_y - (12 * 2.5)
                local s_x1 = s_x0 + (19 * 2.5)
                local s_y1 = s_y0 + (23 * 2.5)

                if state.held[4] == nil and not input.isPointerClaimed(state, pid) and _held == 1 and _x > s_x0 and _x < s_x1 and _y > s_y0 and _y < s_y1 then
                    state.held[4] = pid
                end
                if state.held[4] == pid then
                    if _held == 1 then
                        state.settings_z = 1
                    else
                        state.held[4] = nil
                        settings_menu.open(state, 0)
                    end
                end
            end

            -- Joystick & D-PAD
            if state.touchscreen_type == 0 or state.touchscreen_type == 1 or state.touchscreen_type == 4 or state.touchscreen_type == 5 then
                state.joybase_x[1] = state.touchscreen_x[5]
                state.joybase_y[1] = state.touchscreen_y[5]

                local jb_x0 = state.joybase_x[1] - (30 * state.touchscreen_scale[1])
                local jb_y0 = state.joybase_y[1] - (30 * state.touchscreen_scale[1])
                local jb_x1 = jb_x0 + (59 * state.touchscreen_scale[1])
                local jb_y1 = jb_y0 + (59 * state.touchscreen_scale[1])

                if state.held[5] == nil and not input.isPointerClaimed(state, pid) and _held == 1 and _x > jb_x0 and _x < jb_x1 and _y > jb_y0 and _y < jb_y1 then
                    state.held[5] = pid
                end

                if state.held[5] == pid then
                    if _held == 1 then
                        local radius = math_utils.point_distance(jb_x0, jb_y0, jb_x1, jb_y1) / 3
                        local dist = math_utils.point_distance(state.joybase_x[1], state.joybase_y[1], _x, _y)
                        local angle = math_utils.point_direction(state.joybase_x[1], state.joybase_y[1], _x, _y)
                        state.joystick_x[1] = _x
                        state.joystick_y[1] = _y

                        if dist > radius then
                            state.joystick_x[1] = state.joybase_x[1] + math_utils.lengthdir_x(radius, angle)
                            state.joystick_y[1] = state.joybase_y[1] + math_utils.lengthdir_y(radius, angle)
                        end

                        local deadzone = math_utils.lerp(0.1, 0.9, state.touchscreen_deadzone) * radius
                        _key_state[1] = 0; _key_state[2] = 0; _key_state[3] = 0; _key_state[4] = 0

                        if dist > deadzone then
                            if state.touchscreen_type == 4 then
                                -- 4-Way D-PAD (Only cardinal directions)
                                if angle < 45 or angle >= 315 then _key_state[3] = 1
                                elseif angle >= 45 and angle < 135 then _key_state[2] = 1
                                elseif angle >= 135 and angle < 225 then _key_state[1] = 1
                                elseif angle >= 225 and angle < 315 then _key_state[4] = 1 end
                            else
                                -- Analog Joystick or 8-Way D-PAD (Allows diagonal overlaps)
                                if angle < 67.5 or angle > 292.5 then _key_state[3] = 1 end
                                if angle > 22.5 and angle < 157.5 then _key_state[2] = 1 end
                                if angle > 112.5 and angle < 247.5 then _key_state[1] = 1 end
                                if angle > 202.5 and angle < 337.5 then _key_state[4] = 1 end
                            end
                        end
                        _joystick_fade[1] = 1
                    else
                        _key_state[1] = 0; _key_state[2] = 0; _key_state[3] = 0; _key_state[4] = 0
                        state.held[5] = nil
                    end
                end

            elseif state.touchscreen_type == 2 or state.touchscreen_type == 3 then
                local dynamicLimitX = gui_w / 2
                if state.held[5] == nil and not input.isPointerClaimed(state, pid) and _held == 1 and _x < dynamicLimitX and _y > gui_h / 3 then
                    state.joybase_x[1] = _x
                    state.joybase_y[1] = _y
                    state.joystick_x[1] = _x
                    state.joystick_y[1] = _y
                    state.held[5] = pid
                end

                local jb_x0 = state.joybase_x[1] - (30 * state.touchscreen_scale[1])
                local jb_y0 = state.joybase_y[1] - (30 * state.touchscreen_scale[1])
                local jb_x1 = jb_x0 + (59 * state.touchscreen_scale[1])
                local jb_y1 = jb_y0 + (59 * state.touchscreen_scale[1])

                if state.held[5] == pid then
                    if _held == 1 then
                        local radius = math_utils.point_distance(jb_x0, jb_y0, jb_x1, jb_y1) / 3
                        local dist = math_utils.point_distance(state.joybase_x[1], state.joybase_y[1], _x, _y)
                        local angle = math_utils.point_direction(state.joybase_x[1], state.joybase_y[1], _x, _y)
                        state.joystick_x[1] = _x
                        state.joystick_y[1] = _y

                        if dist > radius then
                            state.joystick_x[1] = state.joybase_x[1] + math_utils.lengthdir_x(radius, angle)
                            state.joystick_y[1] = state.joybase_y[1] + math_utils.lengthdir_y(radius, angle)
                        end

                        local deadzone = math_utils.lerp(0.1, 0.9, state.touchscreen_deadzone) * radius
                        _key_state[1] = 0; _key_state[2] = 0; _key_state[3] = 0; _key_state[4] = 0

                        if dist > deadzone then
                            if angle < 67.5 or angle > 292.5 then _key_state[3] = 1 end
                            if angle > 22.5 and angle < 157.5 then _key_state[2] = 1 end
                            if angle > 112.5 and angle < 247.5 then _key_state[1] = 1 end
                            if angle > 202.5 and angle < 337.5 then _key_state[4] = 1 end
                        end
                        _joystick_fade[1] = 1
                    else
                        _key_state[1] = 0; _key_state[2] = 0; _key_state[3] = 0; _key_state[4] = 0
                        state.held[5] = nil
                    end
                end
            end

            -- SpeedUp Button
            if not state.speedUp_hide then
                local su_x0 = state.speedUp_x - (10 * 2.5)
                local su_y0 = state.speedUp_y - (12 * 2.5)
                local su_x1 = su_x0 + (19 * 2.5)
                local su_y1 = su_y0 + (23 * 2.5)

                if state.held[6] == nil and not input.isPointerClaimed(state, pid) and _held == 1 and _x > su_x0 and _x < su_x1 and _y > su_y0 and _y < su_y1 then
                    state.held[6] = pid
                    input.toggle_speed_up(state)
                end
                if state.held[6] == pid and _held == 0 then
                    state.held[6] = nil
                end
            end

        end
    end

    if state.touchscreen_type == 0 or state.touchscreen_type == 1 or state.touchscreen_type == 4 or state.touchscreen_type == 5 then
        state.joybase_x[1] = state.touchscreen_x[5]
        state.joybase_y[1] = state.touchscreen_y[5]
        if _joystick_fade[1] == 0 then
            state.joystick_x[1] = state.joybase_x[1]
            state.joystick_y[1] = state.joybase_y[1]
            _joystick_fade[1] = 1
        end
    else
        if _joystick_fade[1] == 0 then
            state.joystick_x[1] = state.joybase_x[1]
            state.joystick_y[1] = state.joybase_y[1]
        end
    end

    for i = 1, 7 do
        if state.key_state[i] ~= _key_state[i] then
            state.key_state[i] = _key_state[i]
            input.triggerVirtualKey(state.VIRTUAL_KEYS[i], state.key_state[i] == 1)
        end
    end

    if _joystick_fade[1] == 1 then
        state.joystick_alpha[1] = math.min(state.joystick_alpha[1] + fade_speed * dt, 1)
    else
        state.joystick_alpha[1] = math.max(state.joystick_alpha[1] - fade_speed * dt, 0)
    end
end

return core_update
