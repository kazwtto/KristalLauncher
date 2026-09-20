---@class Text : Text
---@overload fun(...) : Text
local Text, super = HookSystem.hookScript(Text)

function Text:init(text, x, y, w, h, options)
    if type(w) == "table" then
        options = w
        w = SCREEN_WIDTH
        h = SCREEN_HEIGHT
    else
        w = w or SCREEN_WIDTH
        h = h or SCREEN_HEIGHT
    end

    super.init(self, text, x, y, w, h, options)
end

function Text:draw()
    if self.text == "" then
        Object.draw(self)
        return
    end

    super.draw(self)
end

return Text
