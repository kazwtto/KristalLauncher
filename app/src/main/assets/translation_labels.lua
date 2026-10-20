-- Canonical selectors are never replaced. This module owns presentation labels only.
local labels = setmetatable({}, {__mode = "k"})
local runtime = {}

function runtime.label(owner, kind, original, translated)
    if type(owner) == "table" and type(original) == "string" and type(translated) == "string" then
        local groups = labels[owner]
        if not groups then groups = {}; labels[owner] = groups end
        if not groups[kind] then groups[kind] = {} end
        groups[kind][original] = translated
    end
    return original
end

-- Cooking's marked JSON values are expressions, not literal menu selectors.
-- Use its own evaluator and the original variable arguments, without changing
-- Kristal.DialogueDump or the existing _s function. Invalid translated expressions
-- fall back to the canonical label instead of interrupting action registration.
function runtime.dynamic(owner, kind, original, translated, varnames, ...)
    local vars = {...}
    local function evaluate(value)
        local ok, expression = pcall(Kristal.UnconcateText, value, varnames, vars)
        if not ok then return nil end
        local chunk = (loadstring or load)("local txt = " .. expression .. "\nreturn txt")
        if not chunk then return nil end
        local succeeded, result = pcall(chunk)
        if succeeded and type(result) == "string" then return result end
    end
    local canonical = evaluate(original)
    assert(canonical, "Cannot resolve original dynamic ACT selector")
    local display = translated == original and canonical or (evaluate(translated) or canonical)
    return runtime.label(owner, kind, canonical, display)
end

function runtime.display(owner, kind, original)
    local groups = labels[owner]
    local group = groups and groups[kind]
    if group and group[original] then return group[original] end
    -- Custom highlights may be a group rather than the action's enemy. Resolve
    -- only when every candidate agrees; ambiguous names retain their original label.
    if kind == "act" and Game and Game.battle then
        local result
        local enemies = Game.battle.enemies or Game.battle.enemies_index or {}
        for _, enemy in pairs(enemies) do
            local enemy_groups = labels[enemy]
            local value = enemy_groups and enemy_groups.act and enemy_groups.act[original]
            if value then
                if result and result ~= value then return original end
                result = value
            end
        end
        return result or original
    end
    return original
end

return runtime
