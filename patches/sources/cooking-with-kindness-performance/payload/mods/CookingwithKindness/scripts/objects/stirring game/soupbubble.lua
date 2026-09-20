local SoupBubble, super = Class(Sprite, "SoupBubble")

function SoupBubble:init(x,y,rx,ry,fx,fy,theta,popY)
    super.init(self, "objects/stirringgame/soupbubble", x+rx, y)

    self:setOrigin(.5,.5)
    self:setScale(2,2)

    self.physics.friction = 0.0

    self.rx = rx
    self.ry = ry
    self.fx = fx
    self.fy = fy
    self.theta = theta

    self.xCenter = x
    self.yCenter = y
    
    self.wiggle = 7
    self.wiggleConst = math.pi / .75
    self.wiggleTimer = 0
    self.riseSpeed = 4
    self.popY = popY

    self.velocity = 0
    self.popping = false
end

function SoupBubble:update()
    self.theta = self.theta + DTMULT*self.velocity

    self.yCenter = self.yCenter - self.riseSpeed*DTMULT
    self.wiggleTimer = self.wiggleTimer + DT

    self.x = self.xCenter + self.rx*math.cos(self.fx*self.theta) + self.wiggle*math.cos(self.wiggleTimer*self.wiggleConst)
    self.y = self.yCenter - self.ry*math.sin(self.fy*self.theta)

    if self.y > self.popY and not self.popping then
        self.popping = true
        self:play(2/30, false, function()
            self:remove()
        end)
    end

    super.update(self)
end

return SoupBubble