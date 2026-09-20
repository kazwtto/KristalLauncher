local IceCreamConeScoop, super = Class(Sprite, "IceCreamConeScoop")

function IceCreamConeScoop:init(x, y, lane, flavor, stack)
    super.init(self, "objects/icecreamconegame/scoop_"..flavor, x, y)

    self:setScale(2)
    self:setOrigin(0.5, 0)

    --self:play(5/30, true)

    self.isPlaced = false
    self.isFalling = true
    self.physics.speed_y = 9

    self.lane = lane
    self.nextOffset = 6

    self.x0 = nil
    self.springbackStart = 0
    self.springbackTimer = 0
    self.springbackTime  = 10

    self.flavor = flavor
    self.targetStack = stack

    self:setHitbox(0, 0, self.width, self.width)


    --for t = 0, .5, .05 do
    --    Kristal.Console:log(t .. " --- " .. self:easingFunc(t))
    --end
end

function IceCreamConeScoop:easingFunc(t)
    local p = 0

    t = 1 - t

    local t_peak = .4

    if t < 1 then
        if t < t_peak then        
            --local a1 = -1/(t_peak^2)
            --local b1 = 2/t_peak
            --p = a1*t^2 + b1*t
            local a1 = -2/(t_peak^3)
            local b1 = 3/t_peak^2
            p = a1*t^3 + b1*t^2
        else
            local a2 = -1/(1-2*t_peak+t_peak^2)
            local b2 = -2*a2*t_peak
            local c2 = a2*t_peak^2 + 1
            p = a2*t^2 + b2*t + c2
        end
    end

    return p
end

function IceCreamConeScoop:place()
    self.physics.speed_y = 0
    self.isFalling = false
    self.isPlaced = true
    
    self:setOrigin(0.5, 1)
    
    local n = #self.targetStack["scoops"]

    --self.targetStack["cone"]:addChild(self) This was creating a clone of the scoop in the top left of the screen
    self:setParent(self.targetStack["cone"])
    self:setScale(1)
    if n ~= 0 then
        self.springbackTimer = self.targetStack["top"].springbackTimer
        self.springbackStart = self.targetStack["top"].springbackStart
    end
    self.x = self.targetStack["top"].width/2
    self.x0 = self.targetStack["cone"].width/2

    if n == 0 then
        self.y = -self.targetStack["cone"].coneOffset
    else
        self.y = -self.targetStack["cone"].coneOffset - n*self.targetStack["cone"].scoopOffset
    end

    table.insert(self.targetStack["scoops"], self)
    self.targetStack["top"] = self
    self.targetStack["cone"].collider.y = self.targetStack["cone"].collider.y - self.targetStack["cone"].scoopOffset
    self.targetStack["grew"] = true
end

function IceCreamConeScoop:startSpringBack(dx)
    self.springbackTimer = self.springbackTime
    self.springbackStart = dx
end

function IceCreamConeScoop:draw()
    super.draw(self)
    if DEBUG_RENDER and not self.isPlaced then
        self.collider:draw(1,0,0)
    end
end

function IceCreamConeScoop:update()
    if self.isPlaced then
        self.x = self.x0 + self.springbackStart * self:easingFunc(self.springbackTimer/70)

        self.springbackTimer = self.springbackTimer - DTMULT
        if self.springbackTimer < .001 then
            self.x = self.x0
            self.springbackTimer = 0
        end
    elseif self:collidesWith(self.targetStack["cone"]) then
        self:place()
    elseif self.y > Game.battle.arena.bottom + self.height * math.abs(self.scale_y) then
        self:remove()
        return
    end

    super.update(self)
end

return IceCreamConeScoop