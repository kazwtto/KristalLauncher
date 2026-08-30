-- Mobile replacement for Cooking with Kindness's aggregate light renderer.
--
-- The original implementation allocates a canvas sized to the complete map. On the
-- 64 x 60 CORE Square map that becomes a 1920 x 1800 render target, even though only
-- a screen-sized portion can be visible. Drawing the small number of light circles
-- directly into the active world target preserves the effect without that allocation
-- or the extra full-map compositing pass.

local beeglighttest, super = Class(Event)

function beeglighttest:init(data)
    super.init(self, data)

    local properties = data.properties or {}
    self.x = 0
    self.y = 0
    self.lights = {}
    self.r = properties["radius"] or 120
    self.siner = 0
end

function beeglighttest:onLoad()
    self.lights = Game.world.map:getEvents("lighttest")

    for _, light in ipairs(self.lights) do
        light:setOrigin(0.5, 0.5)
    end
end

function beeglighttest:update()
    super.update(self)
    self.siner = self.siner + DT
    self.r = self.r + math.sin(self.siner / 1.1) / 3
end

function beeglighttest:draw()
    local previousMode, previousAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", previousAlphaMode)

    for _, light in ipairs(self.lights) do
        if light.visible then
            local instances = math.max(0, tonumber(light.instances) or 0)
            local radius = math.max(0, self.r)
            local step = radius / (instances + 1)

            for index = instances, 1, -1 do
                local size = radius - index * step
                Draw.setColor(Utils.hslToRgb(0.08, 0.4, 0.02 + 0.03 * instances))

                if light.shape == "circle" then
                    love.graphics.circle("fill", light.x, light.y, size)
                elseif light.shape == "rectangle" then
                    love.graphics.rectangle("fill", light.x, light.y, size, size)
                end
            end
        end
    end

    Draw.setColor()
    love.graphics.setBlendMode(previousMode, previousAlphaMode)
    super.draw(self)
end

return beeglighttest
