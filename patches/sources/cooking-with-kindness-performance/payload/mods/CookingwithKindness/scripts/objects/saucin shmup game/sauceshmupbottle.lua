local SauceShmupBottle, super = Class(Sprite, "SauceShmupBottle")

function SauceShmupBottle:init(x, y, sauceTable, board)
    super.init(self, "objects/saucinshmupgame/saucebottle/bottlefg", x, y)

    self.fgSpriteName = "objects/saucinshmupgame/saucebottle/bottlefg"
    self.colorSpriteName = "objects/saucinshmupgame/saucebottle/bottlecolormask"
    
    self:setScale(2)
    self:setOrigin(0.5, 0.5)

    self.sauceTable = sauceTable
    self.currentSauceIndex = 1

    self.colorSprite = self:addChild(Sprite(self.colorSpriteName, 0, 0))
    self.colorSprite:setOrigin(0, 0)
    self.colorSprite.color = self.sauceTable[self.currentSauceIndex]["color"] or {1, 1, 1}

    self.shootTimer = 0
    self.changeTimer = 0

    self.shotTime = 3
    self.changeTime = 7
    self.baseSpeed = 6

    self.baseModeCollider = Hitbox(self, 2, 1, 17, 6)
    self.changeModeCollider = CircleCollider(self, self.width/2, self.height/2, 4.5)
    self.collider = self.baseModeCollider

    self.board = board
    self.hits = 0
    
    self.knockbackSpeed_x = 0
    self.knockbackSpeed_y = 0
    self.knockbackDecay = 1 * 30

    self.iframesTime = 1
    self.iframes = 0
    self.iframesBlinker = false

    self.has_died = false
end

function SauceShmupBottle:onHit(bullet)
    if self.iframes <= 0 then
        self.hits = self.hits + 1
        self.board.lives[#self.board.lives]:remove()
        table.remove(self.board.lives)

        self.iframes = self.iframesTime

        if #self.board.lives > 0 then
            local dx = self.x - bullet.x
            local dy = self.y - bullet.y
            local l = math.sqrt(dx*dx + dy*dy)
            if l ~= 0.0 then
                dx = dx / l
                dy = dy / l
            end
            
            self.knockbackSpeed_x = 8 * dx
            self.knockbackSpeed_y = 8 * dy

            Assets.playSound("snd_chop_4")

            bullet:hitFunc()
        else
            self.has_died = true
            self.board:setEndTimer("player death")

            self:explode()
            self:remove()
            bullet:hitFunc()
        end
    else
        bullet:hitFunc()
    end
end

function SauceShmupBottle:shoot()
    self.shootTimer = self.sauceTable[self.currentSauceIndex]["cooldown"]
    Assets.playSound("snd_bottlebloop")

    for _,bulletData in pairs(self.sauceTable[self.currentSauceIndex]["bullets"]) do
        local bullet = self.board:spawnObject(SauceBullet(self.x + self.width/2, self.y, self.sauceTable[self.currentSauceIndex]["color"], bulletData, self.board))
        bullet:setLayer(BATTLE_LAYERS["above_arena"])
        bullet.sauce = self.sauceTable[self.currentSauceIndex]["name"]
        table.insert(self.board.playerBullets, bullet)
    end
end

function SauceShmupBottle:changeSauce()
    self.changeTimer = self.changeTime
    self.collider = self.changeModeCollider
    self.graphics.spin = 2*math.pi / (self.changeTime + 1)

    self.currentSauceIndex = self.currentSauceIndex + 1
    if self.currentSauceIndex > #self.sauceTable then
        self.currentSauceIndex = 1
    end
    self.colorSprite.color = self.sauceTable[self.currentSauceIndex]["color"]

    for i = 1, #self.board.lives do
        self.board.lives[i].colorSprite.color = self.sauceTable[self.currentSauceIndex]["color"]
    end

    local new_sauce = self.parent:addChild(Text(string.upper(self.sauceTable[self.currentSauceIndex]["name"]) .. "!", self.x, self.y, 300, 32, {color=self.sauceTable[self.currentSauceIndex]["color"], align="center"}))
    new_sauce:setScale(0.1)
    new_sauce:setOrigin(0.5, 0)
    new_sauce:setLayer(99999)
    self.parent.timer:tween(0.75, new_sauce, {scale_x = 1, scale_y = 1, y = new_sauce.y-60, rotation = math.rad(-20)}, "out-quad")
    self.parent.timer:after(0.75, function ()
        new_sauce:fadeOutAndRemove(0.5)
    end)    
end

function SauceShmupBottle:finishChange()
    self.changeTimer = -1
    self.collider = self.baseModeCollider
    self.graphics.spin = 0
    self.rotation = 0
end

function SauceShmupBottle:setBottleFrame(frame)
    local fg = self.fgSpriteName.."_"..frame
    local color = self.colorSpriteName.."_"..frame
    if not self:isSprite(fg) then
        self:setSprite(fg)
    end
    if not self.colorSprite:isSprite(color) then
        self.colorSprite:setSprite(color)
    end
end

function SauceShmupBottle:draw()
    super.draw(self)
    if DEBUG_RENDER then
        self.collider:draw(0,1,0)
    end
end

function SauceShmupBottle:onRemove()
    self.collider = nil
    super.onRemove(self)
end

function SauceShmupBottle:update()
    
    local speed = self.baseSpeed

    if self.changeTimer > 0 then
        self.changeTimer = self.changeTimer - DTMULT
        
        speed = speed / 2
        
    elseif self.changeTimer > -1 then
        self:finishChange()
    end

    if self.changeTimer == -1 then
        if self.shootTimer > 0 then
            self:setBottleFrame(2)
            self.shootTimer = self.shootTimer - DTMULT
        elseif self.shootTimer > -1 then
            self.shootTimer = -1
        else
            self:setBottleFrame(1)
            if Input.down("confirm") then
                self:shoot()
            end
        end

        if Input.down("cancel") then
            self:changeSauce()
        end
        
        if Input.down("menu") then
            self.board:showMarkers()
        end
    end

    if self.iframes >= 0 then
        self.iframes = self.iframes - DT
        self.iframesBlinker = not self.iframesBlinker

        local sauce_color = self.sauceTable[self.currentSauceIndex]["color"]
        local r, g, b
        if self.iframes <= 0 or self.iframesBlinker then
            r, g, b = sauce_color[1], sauce_color[2], sauce_color[3]
        else
            r, g, b = 1, 1, 1
        end
        local color = self.colorSprite.color
        if color[1] ~= r or color[2] ~= g or color[3] ~= b then
            self.colorSprite:setColor(r, g, b)
        end
    end

    if Input.down("down") then
        self.inputSpeed_y = speed
    elseif Input.down("up") then
        self.inputSpeed_y = -speed
    else
        self.inputSpeed_y = 0
    end
    if Input.down("right") then
        self.inputSpeed_x = speed
    elseif Input.down("left") then
        self.inputSpeed_x = -speed
    else
        self.inputSpeed_x = 0
    end
    
    self.physics.speed_y = self.inputSpeed_y + self.knockbackSpeed_y
    self.physics.speed_x = self.inputSpeed_x + self.knockbackSpeed_x

    self.knockbackSpeed_x = Utils.approach(self.knockbackSpeed_x, 0, self.knockbackDecay * DT)
    self.knockbackSpeed_y = Utils.approach(self.knockbackSpeed_y, 0, self.knockbackDecay * DT)

    super.update(self)

    -- bullet board collision:
    if self.x < Game.battle.arena.left + self.width then
        self.x = Game.battle.arena.left + self.width
    end
    if self.x > Game.battle.arena.right - self.width then
        self.x = Game.battle.arena.right - self.width
    end
    if self.y < Game.battle.arena.top + self.height then
        self.y = Game.battle.arena.top + self.height
    end
    if self.y > Game.battle.arena.bottom - self.height then
        self.y = Game.battle.arena.bottom - self.height
    end
end

return SauceShmupBottle