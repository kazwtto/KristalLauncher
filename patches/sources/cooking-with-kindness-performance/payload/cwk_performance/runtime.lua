-- Runtime safeguards for Cooking with Kindness DEMO v1.0.6.

local Runtime = {}
local installed = false

local function isAndroid()
    if not (love and love.system and type(love.system.getOS) == "function") then
        return false
    end

    local ok, operatingSystem = pcall(love.system.getOS)
    return ok and operatingSystem == "Android"
end

local function skipRedundantFrameSleep()
    if not (love and love.timer and type(love.timer.sleep) == "function") then
        return
    end

    local originalSleep = love.timer.sleep
    love.timer.sleep = function(seconds)
        if isAndroid() and type(seconds) == "number" and seconds > 0 and seconds <= 0.001 then
            return
        end
        return originalSleep(seconds)
    end
end

local function accelerateBattleTransition()
    if not isAndroid() or type(LightEncounter) ~= "table" or
        type(LightEncounter.onNoTransition) ~= "function" then
        return
    end

    -- The regular transition keeps a FakeClone and the complete battle scene active while the
    -- heart blinks. That path is disproportionately expensive on mobile GPUs. The engine's own
    -- no-transition path preserves battle setup while completing the hand-off in one frame.
    LightEncounter.onSoulTransition = function(self)
        return self:onNoTransition()
    end
end

function Runtime.install()
    if installed then
        return
    end

    installed = true
    skipRedundantFrameSleep()
    accelerateBattleTransition()
end

return Runtime
