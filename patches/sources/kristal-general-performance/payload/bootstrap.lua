-- Kristal general performance runtime bootstrap.
local ok, performance = pcall(require, "kristal_performance.runtime")
if ok and type(performance) == "table" and type(performance.install) == "function" then
    performance.install()
end
