local Whirlpool, super = Class(Object, "Whirlpool")

function Whirlpool:init(x,y,target)
    super.init(self,x,y,21,22)

    self.sprite = self:addChild(Sprite("objects/mawzz_games/finalwave/torpedo",0,0))
    self.sprite:play(0.1)
    self:setScale(2)
    self:setOrigin(0.5, 0.5)

    self.bubble_timer = 0
    self.damage_amount = 2

    self.target = target
    self.homing_timer = 0

    self.bubbles = {}

    if Game.battle.waves[1] then
        table.insert(Game.battle.waves[1].hazards, self)
    end
    
    
    self.collider = Hitbox(self,5,2,self.sprite.width-10,self.sprite.height-5)
end

function Whirlpool:update()
    super.update(self)

    self.homing_timer = self.homing_timer + 1 * DT

    if self.homing_timer >= 0.65 then
        self.physics.direction = self.physics.direction
        self.physics.speed = 9
    else
        local angle_to = MathUtils.angle(self.x,self.y,self.target.x,self.target.y)
        self.physics.direction = MathUtils.approachAngle(self.physics.direction,angle_to,5.5*DT)
        self.physics.speed = 10
    end
    
    self.bubble_timer = self.bubble_timer + DT
    
    if self.bubble_timer >= 0.25 then
        local bubble_sprite = TableUtils.pick({"objects/mawzz_games/divinggame/bubble", "particles/bubble_small"})
        self.bubble_timer = 0
        --local bubble = self.parent:addChild(Bubble(bubble_sprite,self.x,self.y))
        local bubble = Bubble(bubble_sprite,self.x,self.y)
        self.parent:addChild(bubble)
        bubble:setScale(1)
        table.insert(self.bubbles,bubble)
    end

    local bubble_write = 1
    for bubble_read = 1, #self.bubbles do
        local b = self.bubbles[bubble_read]
        local remove_bubble = not b.parent
        if not remove_bubble then
            local _, y = b:getScreenPos()
            remove_bubble = y < 80
        end
        if remove_bubble then
            if b.parent then b:remove() end
        else
            self.bubbles[bubble_write] = b
            bubble_write = bubble_write + 1
        end
    end
    for i = #self.bubbles, bubble_write, -1 do
        self.bubbles[i] = nil
    end
end

return Whirlpool