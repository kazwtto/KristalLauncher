--Code by snrona (with help from Sharks)

local beeglighttest, super = Class(Event)

function beeglighttest:init(data)
    super.init(self, data)

    local properties = data.properties or {}

    self.x = 0
    self.y = 0
    self.lights = {}
    self.shape = "circle"
    self.r = properties["radius"] or 120
    self.siner = 0
    self._cwk_light_width = Game.world.map.width * 30
    self._cwk_light_height = Game.world.map.height * 30
end

function beeglighttest:onLoad()
    self.lights = Game.world.map:getEvents("lighttest")

    for _,light in ipairs(self.lights) do
        light:setOrigin(0.5, 0.5)
    end
end

function beeglighttest:update()
    super.update(self)

    self.siner = self.siner + DT
    self.r = self.r + (math.sin((self.siner) / 1.1)) / 3
end

function beeglighttest:draw()
    -- Draw.pushCanvas resets the transform. Instead of a map-sized render target,
    -- render the same world-space light buffer only for the currently visible AABB.
    local x1, y1 = love.graphics.inverseTransformPoint(0, 0)
    local x2, y2 = love.graphics.inverseTransformPoint(SCREEN_WIDTH, 0)
    local x3, y3 = love.graphics.inverseTransformPoint(0, SCREEN_HEIGHT)
    local x4, y4 = love.graphics.inverseTransformPoint(SCREEN_WIDTH, SCREEN_HEIGHT)

    -- Keep the same integer world-pixel grid and map clipping as the original
    -- map-sized canvas. This avoids subpixel rasterization differences while only
    -- allocating the visible portion.
    local left = math.max(0, math.floor(math.min(x1, x2, x3, x4)))
    local top = math.max(0, math.floor(math.min(y1, y2, y3, y4)))
    local right = math.min(self._cwk_light_width, math.ceil(math.max(x1, x2, x3, x4)))
    local bottom = math.min(self._cwk_light_height, math.ceil(math.max(y1, y2, y3, y4)))

    if right <= left or bottom <= top then
        super.draw(self)
        return
    end

    local canvas_w = right - left
    local canvas_h = bottom - top
    local lightCanvas = Draw.pushCanvas(canvas_w, canvas_h)
    love.graphics.setBlendMode("lighten", "premultiplied")

    for _, light in ipairs(self.lights) do
        if light.visible == true then
            local instances = light.instances
            local glow_divider = instances + 1
            local step = self.r / glow_divider

            for i = instances, 1, -1 do
                local size = self.r - i * step
                Draw.setColor(Utils.hslToRgb(0.08, 0.4, (0.02 + (0.03 * instances))))

                if light.shape == "circle" then
                    love.graphics.circle("fill", light.x - left, light.y - top, size)
                elseif light.shape == "rectangle" then
                    love.graphics.rectangle("fill", light.x - left, light.y - top, size, size)
                end
                instances = instances - 1
                Draw.setColor()
            end
        end
    end

    Draw.popCanvas()

    love.graphics.setBlendMode("add")
    Draw.drawCanvas(lightCanvas, left, top)
    love.graphics.setBlendMode("alpha")

    super.draw(self)
end

return beeglighttest
