local Flyswatter, super = Class(Sprite, "Flyswatter")

function Flyswatter:init(x, y)
    super.init(self, "objects/flyswattergame/flyswatter_1", x, y)

    self:setScale(2)
    self:setOrigin(0.5, 8.5/150)
    self:setHitbox(5,8,17,21)

    self.swinging = -1
    self.swingLength = 10
end

function Flyswatter:startSwing()
    self.swinging = self.swingLength
    self.x = self.x + 3
    self.physics.speed_x = 0
    self.physics.speed_y = 0

end

function Flyswatter:update()
    if self.swinging > 0 then
        self.swinging = self.swinging - DTMULT

        local sprite = self.swinging > 7 and "objects/flyswattergame/flyswatter_2" or "objects/flyswattergame/flyswatter_3"
        if not self:isSprite(sprite) then
            self:setSprite(sprite)
        end
    elseif self.swinging > -1 then
        self.swinging = -1
        self.x = self.x - 3
    else
        local idle_sprite = "objects/flyswattergame/flyswatter_1"
        if not self:isSprite(idle_sprite) then
            self:setSprite(idle_sprite)
        end
        if Input.pressed("confirm") then
            self:startSwing()
            Assets.playSound("snd_chop_noise_only")
        else
            if Input.down("down") then
                self.physics.speed_y = 4
            elseif Input.down("up") then
                self.physics.speed_y = -4
            else
                self.physics.speed_y = 0
            end
            if Input.down("right") then
                self.physics.speed_x = 4
            elseif Input.down("left") then
                self.physics.speed_x = -4
            else
                self.physics.speed_x = 0
            end
        end
    end

    super.update(self)
end

return Flyswatter