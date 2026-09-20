-- Code written by Mose

local PancakeGame, super = Class("LightMinigameWave")

function PancakeGame:init()
    --super.init(self, _s("minigame_popup-pancakegame", "        FLIP!        \n         x4         "), "horiz_layout")
    super.init(self, _s("minigame_popup-pancakegame", "      FLIP x4!      "), "horiz_layout")

    Game:setFlag("Results", "none")

    self.time = -1

    self:setArenaSize(500,250)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 10)

    self.cakeStage = 'none'
    self.tossCount = 1
    self.catchCount = 0

    -- side a: [1]+[3], side b: [2]+[4]
    -- makes life easier to split it up like this
    self.cookedAmt = {0, 0, 0, 0}

    -- no idea why but it doesn't work right until t=20 so...
    self.cookTime = 20

    self.canMove = false

end

function PancakeGame:onStart()
    self.centerX = (Game.battle.arena.left + Game.battle.arena.right) / 2
    self.centerY = (Game.battle.arena.top + Game.battle.arena.bottom) / 2

    -- create pan
    self.pan = self:spawnObject(Sprite("objects/pancakegame/pan/pour"))
    self.pan:setScale(4)
    self.pan:setOrigin(0.5, 0)
    self.pan:setLayer(BATTLE_LAYERS["bullets"])
    self.pan.x = self.centerX
    self.pan.y = self.centerY - 60

    self.pan.speed = 10

    self.pan:play(0.1, false)
    Game.battle.timer:after(0.1, function ()
        self.canMove = true
    end)

    -- create eye
    self.eye = self:spawnObject(Sprite("objects/pancakegame/eye_alt"))
    self.eye:play(0.08, true)
    self.eye:setScale(4)
    self.eye:setOrigin(0.5, 0)
    self.eye:setLayer(BATTLE_LAYERS["above_arena"])
    self.eye.x = self.centerX
    self.eye.y = self.centerY

    -- make pancake but it's hidden
    self.cake = self:spawnObject(Sprite("objects/pancakegame/pancake/rise_2"))
    self.cake:setScale(4)
    self.cake:setOrigin(0.5, 0.5)
    self.cake:setLayer(BATTLE_LAYERS["above_bullets"])
    self.cake.x = 10000
    self.cake.y = self.centerY

    -- show controls
    self.controls = self:spawnObject(Sprite("objects/buttons/waittext", self.centerX, Game.battle.arena.top + 30))
    self.controls:setOrigin(0.5)
    self.controls:setScale(2)
    Game.battle.timer:after(2, function ()
        self.controls:remove()
        self.controls = self:spawnObject(ControlsDisplay(self.centerX, Game.battle.arena.top + 30, "horiz_layout"))
        self.controls:setScale(2)
        self.controls:setOrigin(0.5)
        Game.battle.timer:after(2, function ()
            self.controls:fadeOutAndRemove(0.01)
        end)
    end)

    -- remaining flips counter
    self.counter = self:spawnObject(Text("[font:main, 32]FLIPS: 4"), Game.battle.arena:getLeft() + 6, Game.battle.arena:getBottom() - 32)
    
    --self.pan:setSprite("objects/pancakegame/pan/pour")
    --self.pan:play(0.13, false)
    --Game.battle.timer:after(0.5, function()
        --self.canMove = true
    --end)


end

function PancakeGame:movePan()
    
    if Input.down("left") and self.pan.x >= (Game.battle.arena.left + 22) then
        self.pan:setSpeed(-self.pan.speed,0)
    elseif Input.down("right") and self.pan.x <= (Game.battle.arena.right - 22)then
        self.pan:setSpeed(self.pan.speed,0)
    else
        self.pan:setSpeed(0,0)
    end

end

function PancakeGame:toss()

    self.cakeStage = 'rising'
    self.canMove = false

    self.cake.physics.speed_x = 0
    self.cake.physics.speed_y = 0
    self.cake.physics.gravity = 0
    self.cake.x = 10000
    self.cake.y = self.centerY
    self.cake:setSprite("objects/pancakegame/pancake/rise")

    -- pan go up
    self.pan:slideTo(self.pan.x, self.pan.y - 10, 4/30, "linear", function()
        Assets.playSound("noise", 0.4, 1.3)

        self.pan:setSprite("objects/pancakegame/pan/pan")

        self.cake.x = self.pan.x
        self.cake:play(0.1, false)

        -- pan go down
        self.pan:slideTo(self.pan.x, self.pan.y + 10, 4/30, "linear", function ()
            self.canMove = true
            self.cakeStage = 'readyToFall'
        end)

    end)

    -- Reset cook time and add to tossCount
    self.tossCount = self.tossCount + 1
    self.cookTime = 20

end

function PancakeGame:fall()

    self.cakeStage = 'falling'

    -- random position anywhere but the center of the arena
    local pos = TableUtils.pick{math.random(Game.battle.arena.left + 60, self.centerX - self.cake.width), math.random(self.centerX + self.cake.width, Game.battle.arena.right - 60)}
    self.cake.x = pos

    -- the falling part
    Game.battle.timer:after(1, function ()

        self.cake:setSprite("objects/pancakegame/pancake/fall")

        Game.battle.timer:after(0.5, function ()

            Assets.playSound("snd_fall_short", 0.5, 1.2)
            self.cake:play(0.1, false)

            Game.battle.timer:after(0.6, function ()
                self.cakeStage = 'check'
            end)
        end)
    end)

end

function PancakeGame:checkLanding()
    
    local landed = false

    if Utils.between(self.pan.x, self.cake.x - self.cake.width * 2, self.cake.x + self.cake.width * 2, true) then
        landed = true
    end

    return landed

end

function PancakeGame:checkOverEye()
    
    local over = false
    self.cakeStage = 'none'

    if Utils.between(self.pan.x, self.centerX - self.eye.width, self.centerX + self.eye.width, true) then
        over = true
        self.cakeStage = 'cooking'
    end

    return over

end

function PancakeGame:cook()

    self.cookTime = self.cookTime + (DTMULT * (1/30))

    -- Steam effects and changing cooking amounts
    if (Utils.round(self.cookTime % 0.5, 0.03)) == 0 then

        -- If you just started change to normal cake sprite
        if self.tossCount == 1 then
            self.pan:setSprite("objects/pancakegame/pan/pan_cake_1")
        end

        local steam = self:spawnObject(Sprite("objects/pancakegame/steam/tiny"))
        self.cookedAmt[self.tossCount] = 0
        Assets.playSound("snd_sizzle", 0.25, 0.8)
        
        if self.cookTime > 22 and self.cookTime <= 24 then
            steam:setSprite("objects/pancakegame/steam/light")
            self.cookedAmt[self.tossCount] = 1
            Assets.playSound("snd_sizzle", 0.5, 0.9)

        elseif self.cookTime > 24 then
            steam:setSprite("objects/pancakegame/steam/dark")     
            self.cookedAmt[self.tossCount] = 2 
            Assets.playSound("snd_sizzle", 1, 1)

        end
       
        steam:setOrigin(0.5)
        steam:setLayer(BATTLE_LAYERS["above_bullets"])
        steam.x = math.random(self.pan.x - self.pan.width, self.pan.x + self.pan.width)
        steam.y = self.centerY - 10
        Game.battle.timer:tween(0.6, steam, {y = Game.battle.arena.top})
        Game.battle.timer:tween(0.6, steam, {scale_x = 5})
        Game.battle.timer:tween(0.6, steam, {scale_y = 5})
        Game.battle.timer:tween(0.6, steam, {alpha = 0}, 'linear', function ()
            steam:fadeOutAndRemove(0.01)
        end)

    end

end

function PancakeGame:update()
    super.update(self)

    -- End the encounter after cooking on both sides twice
    if self.catchCount == 4 and not self._cwk_finish_timer_started then
        self._cwk_finish_timer_started = true
        self.canMove = false
        self.pan:setSpeed(0,0)

        Game.battle.timer:after(0.1, function ()
            self.pan:slideTo(self.centerX, self.pan.y, 0.2, "linear")
            Game.battle.timer:after(0.2, function ()
                self.finished = true
            end)
        end)
    end

    if self.canMove and self.catchCount < 4 then

        self:movePan()
    
        -- Cooking
        if self.cakeStage == 'none' or self.cakeStage == 'cooking' then
            
            if self:checkOverEye() then
                self:cook()
            end
        end

        -- Tossing stuff
        -- If z is pressed and everything allows it, toss pancake
        if Input.pressed("confirm", false) and self.canMove and self.cakeStage == 'cooking' then
            if self.controls then
                self.controls:fadeOutAndRemove(0.01)
            end
            self:toss()

        elseif self.cakeStage == 'readyToFall' then
            self:fall()

        elseif self.cakeStage == 'check' then

            self.cakeStage = 'checking'

            if self:checkLanding() then
                self.cake.x = 10000

                -- Decide what the pancake looks like based off cook amounts
                if self.tossCount == 2 or self.tossCount == 4 then
                    self.pan:setSprite("objects/pancakegame/pan/pan_cake_" .. (self.cookedAmt[1] + self.cookedAmt[3]))
                else
                    self.pan:setSprite("objects/pancakegame/pan/pan_cake_" .. (self.cookedAmt[2] + self.cookedAmt[4]))
                end

                self.pan:slideTo(self.pan.x, self.pan.y + 8, 3/30, "linear", function()
                    Assets.playSound("break1", 0.5, 1.2)
                    self.catchCount = self.catchCount + 1
                    self.counter:setText("FLIPS: ".. 4 - self.catchCount)
                    self.pan:slideTo(self.pan.x, self.pan.y - 8, 3/30)
                    self.cakeStage = 'none'
                end)

            else
                -- Decide what the pancake looks like based off cook amounts
                if self.tossCount == 2 or self.tossCount == 4 then
                    self.cake:setSprite("objects/pancakegame/pancake/cake_" .. (self.cookedAmt[1] + self.cookedAmt[3]))
                else
                    self.cake:setSprite("objects/pancakegame/pancake/cake_" .. (self.cookedAmt[2] + self.cookedAmt[4]))
                end
                
                -- Cake bounces off
                -- Restart
                self.cake.physics.speed_x = TableUtils.pick({-5, 5})
                self.cake.physics.speed_y = -5
                self.cake.physics.gravity = 0.8

                Assets.playSound("splat", 0.3, 1.5)

                Game.battle.timer:tween(1.4, self.cake, {rotation = math.pi * Utils.sign(self.cake.physics.speed_x)}, 'linear', function ()

                    -- Reset all the pancake stats
                    self.cake.physics.speed_x = 0
                    self.cake.physics.speed_y = 0
                    self.cake.physics.gravity = 0
                    self.cake.rotation = 0 

                    self.cookTime = 20
                    self.cookedAmt = {0,0,0,0}
                    self.tossCount = 1
                    self.catchCount = 0
                    self.counter:setText("FLIPS: 4")
    
                    -- Move pan back to center
                    self.canMove = false
                    self.pan:setSpeed(0,0)
                    Game.battle.timer:tween(0.2, self.pan, {x = self.eye.x}, 'linear', function ()
    
                        self.pan:setSprite("objects/pancakegame/pan/pour")
                        self.pan:play(0.1, false)
    
                        Game.battle.timer:after(0.5, function ()
                            self.canMove = true
                            self.cakeStage = 'none'
                        end)
                    end)
                end)
            end
        end
    end
end

function PancakeGame:onEnd()
    -- put final scoring here
    local sideA = self.cookedAmt[1] + self.cookedAmt[3]
    local sideB = self.cookedAmt[2] + self.cookedAmt[4]

    if sideA == 0 and sideB == 0 then
        -- return 'undercooked'
        Game:setFlag("Results", "undercooked")
    elseif (sideA == 0 and sideB == 4) or (sideA == 4 and sideB == 0) then
        -- return 'luna'
        Game:setFlag("Results", "luna")
    elseif sideA == 4 and sideB == 4 then
        -- return 'burnt'
        Game:setFlag("Results", "burnt")
    else
        -- return 'normal'
        Game:setFlag("Results", "normal")
    end

    CustScore:addPoints(0)
end

return PancakeGame