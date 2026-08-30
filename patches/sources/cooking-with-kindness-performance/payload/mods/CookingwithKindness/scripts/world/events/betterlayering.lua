-- Removes two per-frame debug-console writes while preserving the original layering behavior.

local BetterLayering, super = Class(Event, "betterlayering")

function BetterLayering:init(data)
    super.init(self, data)
    data.properties.usetile = true

    self.depth_offset = data.properties["depth_offset"] or 1
    self.depth_offset_exact = data.properties["depth_offset_exact"] or self.height * (1 - self.depth_offset)
end

function BetterLayering:update()
    super.update(self)

    if Game.world.player.y >= self.y - self.depth_offset_exact then
        self:setLayer(Game.world.player.layer - 0.001)
    else
        self:setLayer(Game.world.player.layer + 0.001)
    end
end

function BetterLayering:applyTileObject(data, map)
    local tile = map:createTileObject(data, 0, 0, self.width, self.height)

    local ox, oy = tile:getOrigin()
    self:setOrigin(ox, oy)
    tile:setPosition(ox * self.width, oy * self.height)
    tile.inherit_color = true
    tile.debug_select = false
    self:addChild(tile)
end

return BetterLayering
