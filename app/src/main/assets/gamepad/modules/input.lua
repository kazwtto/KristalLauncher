local input = {}

local _triggering = false

function input.triggerVirtualKey(keyName, isPressed)
    if not keyName or _triggering then return end
    _triggering = true
    local ok, err = xpcall(function()
        if isPressed then
            if love.keypressed then
                love.keypressed(keyName, keyName, false)
            end
        else
            if love.keyreleased then
                love.keyreleased(keyName, keyName)
            end
        end
    end, debug.traceback)
    _triggering = false
    if not ok then error(err, 0) end
end

function input.updatePointerStates(state)
    for id in pairs(state.currentPointers) do
        state.currentPointers[id] = nil
    end

    local scale = state.SH / 480
    local touches = love.touch.getTouches()
    for _, id in ipairs(touches) do
        local tx, ty = love.touch.getPosition(id)
        local pointer = state.pointerPool[id] or {}
        pointer.x, pointer.y, pointer.down = tx / scale, ty / scale, true
        state.pointerPool[id] = pointer
        state.currentPointers[id] = pointer
        state.prevPointersDown[id] = true
    end

    for id in pairs(state.prevPointersDown) do
        if type(id) ~= "string" or id ~= "mouse" then
            if not state.currentPointers[id] then
                local pointer = state.pointerPool[id] or {}
                pointer.x, pointer.y, pointer.down = 0, 0, false
                state.pointerPool[id] = pointer
                state.currentPointers[id] = pointer
                state.prevPointersDown[id] = nil
                state.pointerPool[id] = nil
            end
        end
    end

    if #touches == 0 then
        if love.mouse.isDown(1) then
            local mx, my = love.mouse.getPosition()
            local pointer = state.pointerPool.mouse or {}
            pointer.x, pointer.y, pointer.down = mx / scale, my / scale, true
            state.pointerPool.mouse = pointer
            state.currentPointers.mouse = pointer
            state.prevPointersDown["mouse"] = true
        elseif state.prevPointersDown["mouse"] then
            local mx, my = love.mouse.getPosition()
            local pointer = state.pointerPool.mouse or {}
            pointer.x, pointer.y, pointer.down = mx / scale, my / scale, false
            state.pointerPool.mouse = pointer
            state.currentPointers.mouse = pointer
            state.prevPointersDown["mouse"] = nil
        end
    else
        if state.prevPointersDown["mouse"] then
            local pointer = state.pointerPool.mouse or {}
            pointer.x, pointer.y, pointer.down = 0, 0, false
            state.pointerPool.mouse = pointer
            state.currentPointers.mouse = pointer
            state.prevPointersDown["mouse"] = nil
        end
    end
end

function input.isPointerClaimed(state, pid)
    for i = 1, 6 do
        if state.held[i] == pid then return true end
    end
    return false
end

function input.event_user_0(state)
    for i = 1, 7 do
        if state.key_state[i] == 1 then
            input.triggerVirtualKey(state.VIRTUAL_KEYS[i], false)
        end
        state.key_state[i] = 0
    end
    state.held = { nil, nil, nil, nil, nil, nil }
end

function input.toggle_speed_up(state)
    state.speedUp_isActive = not state.speedUp_isActive
end

return input
