-- Lightweight data event used by Cooking with Kindness's aggregate light renderer.
-- The original event allocated one unused screen-sized canvas per light and updated
-- itself again from draw(). The aggregate renderer reads only the fields below.

local lighttest, super = Class(Event)

function lighttest:init(data)
    super.init(self, data)

    local properties = data.properties or {}
    self.shape = properties["shape"] or "circle"
    self.r = properties["radius"] or 120
    self.instances = properties["instances"] or 3
    self.test = properties["test"] or false
    self.red = properties["r"] or properties["red"] or 0
    self.green = properties["g"] or properties["green"] or 0
    self.blue = properties["b"] or properties["blue"] or 0

    if properties["visible"] == false then
        self.visible = false
    end

    self.h, self.s, self.l = Utils.rgbToHsl(self.red, self.green, self.blue)
    self.l = 0.02
    self.color_to_set = Utils.rgbToHsl(self.h, self.s, self.l)
    self.siner = 0
end

function lighttest:update()
    super.update(self)
end

function lighttest:draw()
    -- The aggregate light renderer draws this event. The original draw path
    -- produced no pixels here; it only (accidentally) updated the event twice.
end

return lighttest
