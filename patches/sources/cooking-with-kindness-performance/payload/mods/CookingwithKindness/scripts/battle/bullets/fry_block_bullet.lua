local FryBlock, super = Class(Bullet)

function FryBlock.init(self, x, y, grid_x, grid_y, parent_wave)
    -- Last argument = sprite path
    super.init(self, x, y, "bullets/fry_block")

    self.grid_x, self.grid_y = grid_x, grid_y
    self.parent_wave = parent_wave
    

    self.damage = nil
    self.storedColor = {r=1.0, g=1.0, b=1.0}
    self.destroy_on_hit = false

    self.shape_id = nil
    self.grabbable = true
    self.offset_x = 0
    self.offset_y = 0
    self.grab_hitbox = Hitbox(self, 0,0,self.width, self.height)
    
end

function FryBlock:move(x,y)
    local target_x = x + self.offset_x
    local target_y = y + self.offset_y
    if self.x == target_x and self.y == target_y then
        return false
    end
    self:setPosition(target_x, target_y)
    return true
end
function FryBlock:shift(x,y)
    self:setPosition(self.x+x,self.y+y)
end

function FryBlock:getShapeID()
    return self.shape_id
end

function FryBlock:setShapeID(id)
    self.shape_id = id
end


function FryBlock:setOffset(x,y)
    self.offset_x = x
    self.offset_y = y
end
function FryBlock:autoOffset(soul)
    self.offset_x = self.x - soul.x
    self.offset_y = self.y - soul.y
end
function FryBlock.isInShape(self, id)
    if self.shape_id == id then
        return true
    else return false end
end
function FryBlock.isNotInShape(self, id)
    if self.shape_id == id then
        return false
    else return true end
end
function FryBlock.isNotNullOrInShape(self, id)
    if self.shape_id ~= nil and not self.shape_id == id then
        return true
    else return false end
end
function FryBlock:isInAnyShape()
    if self.shape_id ~= nil then
        return true
    else return false end
end
function FryBlock:getOffset()
    return self.offset_x, self.offset_y
end
function FryBlock:getCoords()
    return self.grid_x, self.grid_y
end
function FryBlock:addGrabbedBlock(val)
    table.insert(self.grabbed_blocks, val)
end
function FryBlock:wipeGrabbedBlocks()
    TableUtils.clear(self.grabbed_blocks)
end

function FryBlock:propagateShape(id, count)
    print("trying to propagate!")
    local count = count or 1
    if count > self.parent_wave.shape_size then return end
end

function FryBlock:setShapeColor(r,g,b)
    if r ~= nil then
    self.storedColor.r = r end
    if g ~= nil then
    self.storedColor.g = g end
    if b ~= nil then
    self.storedColor.b = b end
    
    self:setDisplayColor(self.storedColor.r,self.storedColor.g,self.storedColor.b)
end

function FryBlock:setDisplayColor(r,g,b,a)
    a = a or self.alpha
    local color = self.color
    if color[1] ~= r or color[2] ~= g or color[3] ~= b or self.alpha ~= a then
        self:setColor(r,g,b,a)
    end
end

function FryBlock:isColliding()
    return self.grab_hitbox:collidesWith(Game.battle.soul)
end
    
function FryBlock:onCollide(soul)
end

function FryBlock.update(self)
    if self == nil then return end

    super.update(self)
end

return FryBlock