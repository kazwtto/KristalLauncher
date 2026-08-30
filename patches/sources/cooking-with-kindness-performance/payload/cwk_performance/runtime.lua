-- Runtime safeguards for Cooking with Kindness DEMO v1.0.6.

local Runtime = {}
local installed = false
local CANVAS_CLEANUP_INTERVAL = 90

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

local function retainSharedCanvases()
    if type(Draw) ~= "table" or type(Draw._clearUnusedCanvases) ~= "function" then
        return
    end

    local originalCleanup = Draw._clearUnusedCanvases
    local framesSinceCleanup = 0

    Draw._clearUnusedCanvases = function(...)
        framesSinceCleanup = framesSinceCleanup + 1
        if framesSinceCleanup < CANVAS_CLEANUP_INTERVAL then
            return
        end

        framesSinceCleanup = 0
        return originalCleanup(...)
    end
end

function Runtime.install()
    if installed then
        return
    end

    installed = true
    skipRedundantFrameSleep()
    retainSharedCanvases()
end

return Runtime
