local runtime = {}

local translations = require("kristal_pt.translations")
local unpackValues = table.unpack or unpack
local installed = false
local stringCache = {}
local stringCacheSize = 0
local MAX_STRING_CACHE_SIZE = 4096
local hookedTargets = setmetatable({}, { __mode = "k" })

local function isCurrentHook(target, name)
    local hooks = hookedTargets[target]
    return hooks and hooks[name] == target[name]
end

local function rememberHook(target, name)
    local hooks = hookedTargets[target]
    if not hooks then
        hooks = {}
        hookedTargets[target] = hooks
    end
    hooks[name] = target[name]
end

local function escapePattern(value)
    return (value:gsub("([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"))
end

local function compileDynamicRule(rule)
    local source = rule.source
    local patternParts = { "^" }
    local captureIndexes = {}
    local staticLength = 0
    local cursor = 1

    while true do
        local first, last, index = source:find("{lua(%d+)}", cursor)
        if not first then break end
        local static = source:sub(cursor, first - 1)
        staticLength = staticLength + #static
        patternParts[#patternParts + 1] = escapePattern(static)
        patternParts[#patternParts + 1] = "(.-)"
        captureIndexes[#captureIndexes + 1] = tonumber(index)
        cursor = last + 1
    end

    local tail = source:sub(cursor)
    staticLength = staticLength + #tail
    patternParts[#patternParts + 1] = escapePattern(tail)
    patternParts[#patternParts + 1] = "$"

    return {
        pattern = table.concat(patternParts),
        target = rule.target,
        capture_indexes = captureIndexes,
        minimum_length = staticLength,
        first_byte = source:find("^{lua%d+}") and nil or source:sub(1, 1),
    }
end

local dynamicByFirstByte = {}
local dynamicWildcard = {}
for _, sourceRule in ipairs(translations.dynamic) do
    local rule = compileDynamicRule(sourceRule)
    if rule.first_byte and rule.first_byte ~= "" then
        dynamicByFirstByte[rule.first_byte] = dynamicByFirstByte[rule.first_byte] or {}
        table.insert(dynamicByFirstByte[rule.first_byte], rule)
    else
        table.insert(dynamicWildcard, rule)
    end
end

local function applyDynamicRules(value, rules)
    for _, rule in ipairs(rules) do
        if #value >= rule.minimum_length then
            local captures = { value:match(rule.pattern) }
            if captures[1] ~= nil then
                local valuesByIndex = {}
                for position, index in ipairs(rule.capture_indexes) do
                    valuesByIndex[index] = captures[position]
                end
                return (rule.target:gsub("{lua(%d+)}", function(index)
                    return valuesByIndex[tonumber(index)] or ""
                end))
            end
        end
    end
    return nil
end

local function translateString(value)
    local cached = stringCache[value]
    if cached ~= nil then return cached end

    local exact = translations.exact[value]
    local translated = exact
    if not translated and #value > 1 then
        translated = applyDynamicRules(value, dynamicByFirstByte[value:sub(1, 1)] or {})
            or applyDynamicRules(value, dynamicWildcard)
    end
    translated = translated or value

    if stringCacheSize >= MAX_STRING_CACHE_SIZE then
        stringCache = {}
        stringCacheSize = 0
    end
    stringCache[value] = translated
    stringCacheSize = stringCacheSize + 1
    return translated
end

local function translateValue(value, seen)
    if type(value) == "string" then
        return translateString(value)
    end
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then return seen[value] end
    local translated = {}
    seen[value] = translated
    for key, item in pairs(value) do
        translated[key] = translateValue(item, seen)
    end
    return setmetatable(translated, getmetatable(value))
end

local function hookLoveTextFunction(name)
    local graphics = love and love.graphics
    local original = graphics and graphics[name]
    if type(original) ~= "function" then return end

    graphics[name] = function(first, ...)
        if type(first) == "string" or type(first) == "table" then
            return original(translateValue(first), ...)
        end

        -- LÖVE 12 also accepts an explicit Font before the text argument.
        local arguments = { ... }
        if type(arguments[1]) == "string" or type(arguments[1]) == "table" then
            arguments[1] = translateValue(arguments[1])
        end
        return original(first, unpackValues(arguments))
    end
end

local function hookNewText()
    local graphics = love and love.graphics
    local original = graphics and graphics.newText
    if type(original) ~= "function" then return end
    graphics.newText = function(font, text)
        return original(font, translateValue(text))
    end
end

local function hookFirstTextArgument(target, name)
    if type(target) ~= "table" or type(target[name]) ~= "function" then return end
    if isCurrentHook(target, name) then return end
    local original = target[name]
    target[name] = function(first, text, ...)
        return original(first, translateValue(text), ...)
    end
    rememberHook(target, name)
end

local function hookDrawFunction(name)
    local draw = rawget(_G, "Draw")
    if type(draw) ~= "table" or type(draw[name]) ~= "function" then return end
    if isCurrentHook(draw, name) then return end
    local original = draw[name]
    draw[name] = function(text, ...)
        return original(translateValue(text), ...)
    end
    rememberHook(draw, name)
end

function runtime.install()
    if installed then return end

    hookLoveTextFunction("print")
    hookLoveTextFunction("printf")
    hookNewText()

    local function installEngineHooks()
        hookFirstTextArgument(rawget(_G, "Text"), "setText")
        hookFirstTextArgument(rawget(_G, "DialogueText"), "setText")
        hookFirstTextArgument(rawget(_G, "TextMenuItemComponent"), "setText")
        hookFirstTextArgument(rawget(_G, "LabelMenuItemComponent"), "setText")

        for _, name in ipairs({ "print", "printf", "printAlign", "printShadow", "printOutline" }) do
            hookDrawFunction(name)
        end
    end

    installEngineHooks()
    local originalLoad = love and love.load
    if love then
        love.load = function(...)
            if originalLoad then originalLoad(...) end
            installEngineHooks()
        end
    end

    _G.KRISTAL_PTBR_TRANSLATE = translateValue
    installed = true
end

runtime.translate = translateValue

return runtime
