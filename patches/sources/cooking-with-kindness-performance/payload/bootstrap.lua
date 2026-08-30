-- Installs runtime safeguards only when Kristal starts the target mod.

local ok, runtime = pcall(require, "cwk_performance.runtime")
if ok and type(runtime) == "table" and type(runtime.install) == "function" and Kristal and type(Kristal.loadMod) == "function" then
    local originalLoadMod = Kristal.loadMod

    Kristal.loadMod = function(id, ...)
        if id == "cooking-with-kindness" then
            runtime.install()
        end
        return originalLoadMod(id, ...)
    end
end
