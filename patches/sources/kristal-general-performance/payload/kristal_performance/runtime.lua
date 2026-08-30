-- Conservative performance hooks shared by compatible Kristal revisions.

local Performance = {}
local installed = false
local CANVAS_CLEANUP_INTERVAL = 120

local function getOperatingSystem()
    if not (love and love.system and type(love.system.getOS) == "function") then
        return nil
    end

    local ok, operatingSystem = pcall(love.system.getOS)
    return ok and operatingSystem or nil
end

local function isVSyncEnabled()
    if not (love and love.window and type(love.window.getVSync) == "function") then
        return false
    end

    local ok, value = pcall(love.window.getVSync)
    return ok and value ~= false and value ~= nil and value ~= 0
end

local function patchShortSleep()
    if not (love and love.timer and type(love.timer.sleep) == "function") then return end

    local originalSleep = love.timer.sleep
    love.timer.sleep = function(seconds)
        local isShortFrameYield = type(seconds) == "number" and seconds > 0 and seconds <= 0.001
        if isShortFrameYield and (getOperatingSystem() == "Android" or isVSyncEnabled()) then
            return
        end
        return originalSleep(seconds)
    end
end

local function patchCanvasCleanup()
    local draw = rawget(_G, "Draw")
    if type(draw) ~= "table" then return end
    if type(draw._clearUnusedCanvases) ~= "function" or type(draw._canvases) ~= "table" then return end

    local originalCleanup = draw._clearUnusedCanvases
    local framesSinceCleanup = 0

    draw._clearUnusedCanvases = function(...)
        framesSinceCleanup = framesSinceCleanup + 1
        if framesSinceCleanup >= CANVAS_CLEANUP_INTERVAL then
            framesSinceCleanup = 0
            return originalCleanup(...)
        end

        -- Let the engine perform its normal cleanup bookkeeping, but treat the
        -- currently allocated canvases as recently used for a short grace period.
        -- This avoids assuming how a particular Kristal revision tracks locks.
        local usedCanvases = draw._used_canvas
        if type(usedCanvases) == "table" then
            for _, canvases in pairs(draw._canvases) do
                if type(canvases) == "table" then
                    for _, canvas in ipairs(canvases) do
                        usedCanvases[canvas] = true
                    end
                end
            end
        end
        return originalCleanup(...)
    end
end

function Performance.install()
    if installed then return end
    installed = true

    patchShortSleep()
    patchCanvasCleanup()
end

return Performance
