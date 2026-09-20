-- Code written by Mose

local WhiskGame, super = Class("LightMinigameWave")

-- TODO:
-- See if there is a more efficient way to spawn in the obects
-- Catch mixture on fire if you whisk too fast

function WhiskGame:init()
    super.init(self, _s("minigame_popup-whiskgame", "WHISK!"), "button_alt")

    Game:setFlag("Results", "none")

    self.time = -1

    self:setArenaSize(475,400)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 10)

    -- Scales for everything associated with the meter
    self.metScale = 3
    self.redPercent = 6/30
    self.yellowPercent = 11/30
    self.greenPercent = 7/30
    self.perfectGreenPercent = 2/30
    self.overRedPercent = 4/30

    self.rotAmount = 0 -- Amount (in radians) to rotate the mixture in the bowl every frame

    -- Tracks what colors have been passed or not
    self.passRed = false
    self.passYlw = false
    self.passGrn = false
    self.passPerf = false

    self.counter = 0 -- Tracks how long the minigame goes on for

    self.progress = 0 -- Tracks your whisking progress

    self.threshold = 100 -- Maximum whisking progress to end the minigame. Set to %100 for now

    self.score = 0 -- The score you get at the end of the minigame
    self.scoring = false -- Used to ensure that scoring only happens once
    self.canWhisk = true -- Can you hit z lol

end

function WhiskGame:onStart()
    self.centerX, self.centerY = Game.battle.arena:getCenter()

    -- Create whisk meter
    self.meter = self:spawnObject(Sprite("objects/whiskgame/meter/meter"), self.centerX, Game.battle.arena.top + 50)
    self.meter:setOrigin(0.5)
    self.meter:setScale(self.metScale)
    self.meter:setLayer(BATTLE_LAYERS["bullets"])
    self.meter.right = self.meter.x + self.meter.width * self.meter.scale_x/2
    self.meter.left = self.meter.x - self.meter.width * self.meter.scale_x/2

    -- Fill in red part of meter
    self.red = self:spawnObject(Sprite("objects/whiskgame/meter/red"), self.meter.left, self.meter.y)
    self.red:setOrigin(0,0.5)
    self.red:setScale((self.meter.width * self.meter.scale_x) * self.redPercent, self.metScale)
    self.red:setLayer(BATTLE_LAYERS["bullets"])
    self.red.right = self.red.x + self.red.width * self.red.scale_x

    -- Fill in yellow part of meter
    self.yellow = self:spawnObject(Sprite("objects/whiskgame/meter/yellow"), self.red.right, self.meter.y)
    self.yellow:setOrigin(0,0.5)
    self.yellow:setScale((self.meter.width * self.meter.scale_x) * self.yellowPercent, self.metScale)
    self.yellow:setLayer(BATTLE_LAYERS["bullets"])
    self.yellow.right = self.yellow.x + self.yellow.width * self.yellow.scale_x

    -- Fill in green part of meter
    self.green = self:spawnObject(Sprite("objects/whiskgame/meter/green"), self.yellow.right, self.meter.y)
    self.green:setOrigin(0,0.5)
    self.green:setScale((self.meter.width * self.meter.scale_x) * self.greenPercent, self.metScale)
    self.green:setLayer(BATTLE_LAYERS["bullets"])
    self.green.right = self.green.x + self.green.width * self.green.scale_x

    -- Fill in perfect green part of meter
    self.pGreen = self:spawnObject(Sprite("objects/whiskgame/meter/perfect_green"), self.green.right, self.meter.y)
    self.pGreen:setOrigin(0,0.5)
    self.pGreen:setScale((self.meter.width * self.meter.scale_x) * self.perfectGreenPercent, self.metScale)
    self.pGreen:setLayer(BATTLE_LAYERS["bullets"])
    self.pGreen.right = self.pGreen.x + self.pGreen.width * self.pGreen.scale_x

    -- Fill in over red part of meter
    self.oRed = self:spawnObject(Sprite("objects/whiskgame/meter/red"), self.pGreen.right, self.meter.y)
    self.oRed:setOrigin(0,0.5)
    self.oRed:setScale((self.meter.width * self.meter.scale_x) * self.overRedPercent, self.metScale)
    self.oRed:setLayer(BATTLE_LAYERS["bullets"])
    self.oRed.right = self.oRed.x + self.oRed.width * self.oRed.scale_x

    -- Create progress indicator
    self.heart = self:spawnObject(Sprite("objects/whiskgame/meter/indicator"), self.meter.x - self.meter.width * self.meter.scale_x/2, self.meter.y)
    self.heart:setOrigin(0.5)
    self.heart:setScale(self.metScale)
    self.heart:setLayer(BATTLE_LAYERS["above_bullets"])
    self.heart:play(0.5, true)

    -- Acceleration and max speed for forward direction
    self.heart.posMax = 3
    self.heart.posAccel = 3

    -- Acceleration and max speed for reverse direction
    self.heart.negMax = -8
    self.heart.negAccel = 0.4

    -- Create bowl
    self.bowl = self:spawnObject(Sprite("objects/whiskgame/bowl_alt"), self.centerX, self.centerY + 50)
    self.bowl:setOrigin(0.5)
    self.bowl:setScale(4)
    self.bowl:setLayer(BATTLE_LAYERS["below_bullets"])

    -- Create the mixture
    self.mix = self:spawnObject(Sprite("objects/whiskgame/stuff/stage_1"), self.bowl.x, self.bowl.y)
    self.mix:setOrigin(0.5)
    self.mix:setScale(4)
    self.mix:setLayer(BATTLE_LAYERS["bullets"])

    -- Create the whisk
    self.whisk = self:spawnObject(Sprite("objects/whiskgame/whisk"), self.bowl.x + (self.bowl.width * self.bowl.scale_x/8) - 2, self.bowl.y)
    self.whisk:setOrigin(0,0.5)
    self.whisk:setScale(4)
    self.whisk:setLayer(BATTLE_LAYERS["above_bullets"])
    self.whisk.init_y = self.whisk.y

    -- Show controls
    self.controls = self:spawnObject(ControlsDisplay(self.centerX, self.meter.y + 50, "button_alt"))
    self.controls:setOrigin(0.5)
    self.controls:setScale(2)
    self.timer:after(2, function ()
        self.controls:fadeOutAndRemove(0.01)
    end)

end

-- Move function for the indicator
function WhiskGame:move()

    -- Accelerates the indicator forward when z is pressed and moves the whisk
    if Input.pressed("confirm") and self.heart.x < self.meter.right and self.canWhisk then
        self.heart:setSpeed(Utils.approach(self.heart.physics.speed_x, self.heart.posMax, self.heart.posAccel),0)

        self.whisk:slideTo(self.whisk.x, self.whisk.init_y + 15, 2/30, "linear", function ()
            self.whisk:slideTo(self.whisk.x, self.whisk.init_y - 10, 2/30, "linear", function ()
                self.whisk:slideTo(self.whisk.x, self.whisk.init_y, 2/30, "linear")
            end)
        end)

    elseif self.heart.x > self.meter.left and self.canWhisk then -- Accelerates the indicator backward when z is not pressed
        self.heart:setSpeed(Utils.approach(self.heart.physics.speed_x, self.heart.negMax, self.heart.negAccel),0)
    else -- Stops the indicator if you can't whisk
        self.heart:setSpeed(0)
    end

    -- Ensure the inidcator stays within the right bound of the meter
    if self.heart.x > self.meter.right then
        self.heart.x = self.meter.right
        self.heart:setSpeed(0)
    end

    -- Ensure the inidcator stays within the left bound of the meter
    if self.heart.x < self.meter.left then
        self.heart.x = self.meter.left
        self.heart:setSpeed(0)
    end

end

-- Checks what color the indicator is over and returns the amount to increment the score by each frame.
-- Increment values are percentages (i.e. %0.05, %0.1, %0.25, etc)
function WhiskGame:getIncrement()

    local increment = 0

    -- Red
    if self.heart.x > self.red.x and self.heart.x < self.red.right then
        increment = 0.05
        self.rotAmount = math.rad(1)

    -- Yellow
    elseif self.heart.x > self.yellow.x and self.heart.x < self.yellow.right then
        increment = 0.15
        self.rotAmount = math.rad(2)
        self.passRed = true

    -- Green
    elseif self.heart.x > self.green.x and self.heart.x < self.green.right then
        increment = 0.3
        self.rotAmount = math.rad(5)
        self.passYlw = true

    -- Perfect Green
    elseif self.heart.x > self.pGreen.x and self.heart.x < self.pGreen.right then
        increment = 0.5
        self.rotAmount = math.rad(10)
        self.passGrn = true

    -- Over Red
    elseif self.heart.x > self.oRed.x and self.heart.x < self.oRed.right + 1 then
        increment = 1
        self.rotAmount = math.rad(40)
        self.passPerf = true

    end

    return increment

end

-- Give a score based on how quickly you whisked the mixture
-- You get no points if you go too fast (only possible by staying in the red)
function WhiskGame:setScore()
    local msg = "blank" -- What message to dislpay
    local snd = "error" -- What sound effect to play

    -- All the different scores
    if self.counter < 9 then             -- Less than 9s
        if Utils.random() > 0.25 then
            msg = "Bad"
        else
            msg = ":("
        end
        snd = "error"
        self.score = 0
        Stepscript:backStep("whiskgame")
    elseif self.counter < 13 then        -- 9s to 13s
        msg = "Perfect"
        snd = "snd_perfect"
        self.score = 5
    elseif self.counter < 16 then        -- 13s to 16s
        msg = "Okay"
        snd = "snd_good"
        self.score = 3
    else                               -- Greater than 16s
        if Utils.random() > 0.25 then
            msg = "Bad"
        else
            msg = ":("
        end
        snd = "error"
        self.score = 1
        Stepscript:backStep("whiskgame")
    end

    self:scoreMessage(msg, self.bowl.x, self.bowl.y)
    Assets.playSound(snd, 0.6, 1.2)

    self.timer:after(1, function () -- End the wave
        self.finished = true
    end)
end

function WhiskGame:update()
    super.update(self)

    self.counter = self.counter + DT

    self:move()

    self.mix.rotation = self.mix.rotation + self.rotAmount -- Rotate the mixture

    self.progress = self.progress + self:getIncrement() -- Increment progress

    -- Update mixture sprite according to progress

    --if self.passPerf and self.passGrn and self.passYlw and self.passRed then
        --self.mix:setSprite("objects/whiskgame/stuff/stage_5")

    local mix_sprite = nil
    if self.passGrn and self.passYlw and self.passRed then
        mix_sprite = "objects/whiskgame/stuff/stage_4"
    elseif self.passYlw and self.passRed then
        mix_sprite = "objects/whiskgame/stuff/stage_3"
    elseif self.passRed then
        mix_sprite = "objects/whiskgame/stuff/stage_2"
    end

    if mix_sprite and not self.mix:isSprite(mix_sprite) then
        self.mix:setSprite(mix_sprite)
    end

    -- When %100 progress is reached, run score function and end the game
    if self.progress >= self.threshold and not self.scoring then
        self.scoring = true
        self.canWhisk = false
        self:setScore()
    end

end

function WhiskGame:onEnd()
    if Game.battle:getEnemyBattler("mimi") and Game:getFlag("mimiLocked", true) == true then
        CustScore:addPoints(self.score - 2)
    else
        CustScore:addPoints(self.score + 1)
    end
end

return WhiskGame
