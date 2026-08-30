-- Code written by Mose

local TorielWhiskGame, super = Class("LightMinigameWave")

function TorielWhiskGame:init()
    super.init(self, _s("minigame_popup-torielwhiskgame", "Whisk!"), "button_alt")

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

    self.isRightHandThereYet = false -- Hopefully the name is self-evident
    self.torielTakesOver = false -- Has toriel taken over

    self.scoring = false -- Used to ensure that scoring only happens once
    self.canWhisk = true -- Can you hit z lol

end

function TorielWhiskGame:onStart()
    self.centerX = (Game.battle.arena.left + Game.battle.arena.right) / 2
    self.centerY = (Game.battle.arena.top + Game.battle.arena.bottom) / 2

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
    self.whisk = self:spawnObject(Sprite("objects/whiskgame/whisk"), self.bowl.x + (self.bowl.width * self.bowl.scale_x/8), self.bowl.y)
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


    -- Create left and right toriel hands
    self.leftHand = self:spawnObject(Sprite("objects/whiskgame/hand_left"), Game.battle.arena.left - 100, Game.battle.arena.top + 100)
    self.leftHand:setOrigin(1, 0.5)
    self.leftHand:setScale(2)
    self.leftHand:setLayer(BATTLE_LAYERS["above_bullets"])

    self.rightHand = self:spawnObject(Sprite("objects/whiskgame/hand_left"), Game.battle.arena.right + 100, Game.battle.arena.top + 100)
    self.rightHand:setOrigin(1, 0.5)
    self.rightHand:setScale(-2, 2)
    self.rightHand:setLayer(BATTLE_LAYERS["above_bullets"])

    -- After a delay, move left hand to the left edge of the meter and slowly move to the left edge of the perfect green
    self.timer:after(1, function ()
        self.torielTakesOver = true -- Toriel has taken over
        self:moveWhisk() -- Start function to move whisk without player input
        self.leftHand:slideTo(self.meter.left, self.meter.y, 0.5, "out-quad", function () -- Move to the left of the meter
            self.leftHand:setSprite("objects/whiskgame/hand_left_press") -- Change to the palm sprite
            self.leftHand:slideTo(self.green.right + 6, self.meter.y, 8, "linear") -- Move to the perfect green
        end)
    end)

end

-- Move function for the indicator
function TorielWhiskGame:move()

    -- Accelerates the indicator forward when z is pressed and moves the whisk
    if Input.pressed("confirm") and self.heart.x < self.meter.right and self.canWhisk then
        self.heart:setSpeed(Utils.approach(self.heart.physics.speed_x, self.heart.posMax, self.heart.posAccel),0)

        -- Move the whisk with z if toriel hasn't taken over
        if not self.torielTakesOver then
            self.whisk:slideTo(self.whisk.x, self.whisk.init_y + 15, 2/30, "linear", function ()
                self.whisk:slideTo(self.whisk.x, self.whisk.init_y - 10, 2/30, "linear", function ()
                    self.whisk:slideTo(self.whisk.x, self.whisk.init_y, 2/30, "linear")
                end)
            end)
        end

    elseif self.heart.x > self.meter.left and self.canWhisk then -- Accelerates the indicator backward when z is not pressed
        self.heart:setSpeed(Utils.approach(self.heart.physics.speed_x, self.heart.negMax, self.heart.negAccel),0)
    else -- Stops the indicator if you can't whisk
        self.heart:setSpeed(0)
    end

    -- Moving the right hand
    if self.heart.x > self.pGreen.right and not self.isRightHandThereYet then -- Check if the indicator has gone into the far red section for the first time.
        self.isRightHandThereYet = true
        self.rightHand:slideTo(self.meter.right, self.meter.y, 0.2, "out-quad", function () -- Move right hand to the right of the meter
            self.rightHand:setSprite("objects/whiskgame/hand_left_press") -- Change to palm sprite
            self.rightHand:slideTo(self.pGreen.right - 6, self.meter.y, 0.2, "linear") -- Move to the perfect green
        end)
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

    -- Ensure the indicator doesn't go past the right hand
    if self.heart.x > self.rightHand.x then
        self.heart.x = self.rightHand.x
        self.heart:setSpeed(0)
    end

    -- Ensure the inidcator doesn't go behind the left hand
    if self.heart.x < self.leftHand.x then
        self.heart.x = self.leftHand.x
        self.heart:setSpeed(0)
    end

end

-- Moves the whisk periodically without player input.
-- Only if toriel has taken over
function TorielWhiskGame:moveWhisk()
    self.timer:script(function (wait) -- Lets me use "wait"
        while self.torielTakesOver do
            self.whisk:slideTo(self.whisk.x, self.whisk.init_y + 15, 2/30, "linear", function () -- Move whisk down
                self.whisk:slideTo(self.whisk.x, self.whisk.init_y - 10, 2/30, "linear", function () -- Move whisk up, overshoot
                    self.whisk:slideTo(self.whisk.x, self.whisk.init_y, 2/30, "linear") -- Move whisk back to starting point
                end)
            end)
            wait(0.15)
        end
    end)
end

-- Checks what color the indicator is over and returns the amount to increment the score by each frame.
-- Increment values are percentages (i.e. %0.05, %0.1, %0.25, etc)
function TorielWhiskGame:getIncrement()

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

function TorielWhiskGame:update()
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

    if mix_sprite and self.mix_sprite ~= mix_sprite then
        self.mix_sprite = mix_sprite
        self.mix:setSprite(mix_sprite)
    end

    -- When %100 progress is reached, play "perfect" effect and end the game
    if self.progress >= self.threshold and not self.scoring then
        self.scoring = true
        self.canWhisk = false
        self.torielTakesOver = false

        self:scoreMessage("Perfect", self.bowl.x, self.bowl.y)
        Assets.playSound("snd_perfect", 0.6, 1.2)

        self.timer:after(1, function () -- End the wave
            self.finished = true
        end)
    end

end

function TorielWhiskGame:onEnd()
    --print(self.counter.." seconds")
    --flag for toriel custcenes that indicate this step is done
    Game:setFlag("TorielSteps", 2)
end

return TorielWhiskGame
