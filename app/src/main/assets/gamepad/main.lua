-- Virtual gamepad used by Kristal Launcher staged packages.

local mobilecontrols = {}

local script_arg = ... or "mobilecontrols"
local script_folder = ""
local require_prefix = ""

if type(script_arg) == "string" and script_arg:find("%.") then
    script_folder = script_arg:match("(.*)%.[^%.]+$"):gsub("%.", "/") .. "/"
    require_prefix = script_arg:match("(.*)%.[^%.]+$") .. "."
end

local state = require(require_prefix .. "modules.state")
local storage = require(require_prefix .. "modules.storage")
local graphics = require(require_prefix .. "modules.graphics")
local input = require(require_prefix .. "modules.input")
local settings_menu = require(require_prefix .. "modules.settings_menu")
local core_update = require(require_prefix .. "modules.core_update")

state.script_folder = script_folder

local initialized = false

function mobilecontrols.load()
    if initialized then return end
    state.SW, state.SH = love.graphics.getDimensions()
    local maxDim = math.max(state.SW, state.SH)
    if maxDim >= 1550 then
        state.screenMode = 2
    else
        state.screenMode = 1
    end
    storage.recalcDefaultPositions(state)
    graphics.loadSprites(state)
    storage.loadTouchConfig(state)
    initialized = true
end

function mobilecontrols.resize(w, h)
    -- Release active virtual keys before the coordinate system changes, then
    -- resolve the saved edge offsets against the new physical screen.
    input.event_user_0(state)
    state.SW, state.SH = w, h
    storage.onResize(state)
end

function mobilecontrols.update(dt)
    if not initialized then mobilecontrols.load() end
    core_update.updateControls(state, dt)
end

function mobilecontrols.draw()
    if not initialized then mobilecontrols.load() end
    graphics.drawControls(state)
end

function mobilecontrols.keypressed(key)
    if key == "escape" then
        if state.con == 99 then
            settings_menu.close(state)
        elseif state.con == 98 then
            state.held = { nil, nil, nil, nil, nil, nil }
            state.con = 99
        end
    end
end

function mobilecontrols.quit()
    storage.saveTouchConfig(state)
end

function mobilecontrols.setSpeedUpHide(hide)
    state.speedUp_hide = hide
end

function mobilecontrols.hook()
    mobilecontrols.load()

    if Utils and Utils.hook then
        Utils.hook(love, "update", function(orig, ...)
            if not Kristal or not Kristal.getState or Kristal.getState() ~= Kristal.States["Loading"] then
                mobilecontrols.update(...)
            end
            orig(...)
        end)

        Utils.hook(love, "draw", function(orig, ...)
            orig(...)
            if not Kristal or not Kristal.getState or Kristal.getState() ~= Kristal.States["Loading"] then
                mobilecontrols.draw()
            end
        end)

        Utils.hook(love, "resize", function(orig, w, h)
            orig(w, h)
            mobilecontrols.resize(w, h)
        end)

        Utils.hook(love, "keypressed", function(orig, key, ...)
            mobilecontrols.keypressed(key)
            return orig(key, ...)
        end)

        Utils.hook(love, "quit", function(orig)
            mobilecontrols.quit()
            if orig then return orig() end
        end)
    end
end

return mobilecontrols
