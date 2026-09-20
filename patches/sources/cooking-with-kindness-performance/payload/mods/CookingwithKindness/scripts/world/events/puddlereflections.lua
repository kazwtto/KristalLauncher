local PuddleReflections, super = Class(Event)

function PuddleReflections:init(data)
    self.reflection_sprites =  {
        ["walk/down"] = "walk/down",
        ["walk/up"] = "walk/up",
        ["walk/left"] = "walk/left",
        ["walk/right"] = "walk/right",
    }
    super.init(self, data.x, data.y, data.width, data.height)

    self.canvas = love.graphics.newCanvas(self.width, self.height)

    self.offset = data.properties["offset"] or 0
    self.opacity = data.properties["opacity"] or 1

    if data.properties["mask"] then
        self.mask = Sprite(data.properties["mask"],data.properties["mask_x"],data.properties["mask_y"])
        self.mask:setScale(2)
        self.mask.flip_y = true
        self.mask.visible = false
        self:addChild(self.mask)
    
        self:addFX(MaskFX(self.mask))
    end

    self.bottom = self.y + self.height
    self.flip_y = true


end

function PuddleReflections:drawReflection()
    for i = #Game.world.children, 1, -1 do
        local obj = Game.world.children[i]
        if obj:includes(Character) then
            self:drawCharacter(obj)
        end
    end
end

function PuddleReflections:drawCharacter(chara)
    love.graphics.push()

    chara:preDraw()
    local oyd = chara.y - self.bottom
    love.graphics.translate(0, -oyd + self.offset)
    local oldsprite = string.sub(chara.sprite.texture_path, #chara.sprite.path + 2)
    local pathless, frame = oldsprite:match("^([^_]*)_([^_]*)")
    pathless = pathless or oldsprite
    local newsprite = oldsprite
    local reflection = chara.actor.reflection_sprites or self.reflection_sprites
    if reflection and reflection[pathless] then
        newsprite = reflection[pathless] .. "_" .. frame
    end
    chara.sprite:setTextureExact(chara.actor.path .. "/" .. newsprite)
    chara:draw()
    chara:postDraw()
    love.graphics.pop()
end

function PuddleReflections:draw()
    super.draw(self)

    Draw.pushCanvas(self.canvas)
    love.graphics.clear()
    love.graphics.translate(-self.x, -self.y)

    self:drawReflection()

    Draw.popCanvas()

    Draw.setColor(1, 1, 1, self.opacity)
    Draw.draw(self.canvas)
    Draw.setColor(1, 1, 1, 1)
end

return PuddleReflections