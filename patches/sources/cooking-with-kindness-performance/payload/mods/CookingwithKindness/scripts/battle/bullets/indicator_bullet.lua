---@class GridNode : Bullet
local GridNode, super = Class(Bullet)

local SHOULD_COLLIDE_WITH_SOUL = false

function GridNode.init(self, x, y, grid_x, grid_y, parent_wave)
    super.init(self, x, y, "bullets/grid_indicator")

    self.grid_x, self.grid_y = grid_x, grid_y
    self.parent_wave = parent_wave
    self.actualSize = self.parent_wave.cell_size-20
    
    local size = self.actualSize/2
    self:setHitbox(0, 0, size, size)

    self.damage = nil
    self.destroy_on_hit = false

    self.colliding = false
    self.occupied = false
    self.shouldPlaySound = false
    self.justTouched = false
end

function GridNode:isColliding()
    local collidingWithBullet = self.colliding
    self.colliding = false
    if SHOULD_COLLIDE_WITH_SOUL then
        return collidingWithBullet or self.collider:collidesWith(Game.battle.soul)
    else
        return collidingWithBullet
    end
end
function GridNode:onCollide(soul)
end
function GridNode:playSound()
        self.shouldPlaySound = true
end
function GridNode.update(self)
    if self == nil then return end
    local occupied = self:isColliding()
    if occupied then
        if not self.justTouched then
            self.justTouched = true
        end
        self.occupied = true
    else
        if self.justTouched then
            self.justTouched = false
        end
        self.occupied = false
    end

    if occupied then
        if self.color[1] ~= 1 or self.color[2] ~= 1 or self.color[3] ~= 0 or self.alpha ~= 0.5 then
            self:setColor(1,1,0,0.5)
        end
    else
        if self.color[1] ~= 0.7 or self.color[2] ~= 0.7 or self.color[3] ~= 0.7 or self.alpha ~= 0.8 then
            self:setColor(0.7,0.7,0.7,0.8)
        end
    end

    if self.shouldPlaySound then
        self.shouldPlaySound = false
            Assets.playSound("snd_cookie_cutter_bounce", 0.4, 1.5)
    end

    super.update(self)
end

return GridNode