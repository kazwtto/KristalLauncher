-- Code written by Mose

local TorielOvenGame, super = Class("LightMinigameWave")

function TorielOvenGame:init()
    super.init(self, _s("minigame_popup-torielovengame", "STOP AT ZERO"), "button")

    self.time = -1

    self:setArenaSize(450,300)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 30)

    self.counter = math.random(8,9)
    self.counting = false
    self.fading = false
    self.is_scoring = false
    self.score = 0

    self.has_hand_spawned = false

    self.siner = self.counter
end

function TorielOvenGame:onStart()
    self.centerX = (Game.battle.arena.left + Game.battle.arena.right) / 2
    self.centerY = (Game.battle.arena.top + Game.battle.arena.bottom) / 2

    -- Create oven background
    self.bg = self:spawnObject(Sprite("objects/ovengame/oven"),self.centerX, self.centerY)
    self.bg:setScale(2)
    self.bg:setOrigin(0.5)

    -- Create heating element
    self.heater = self:spawnObject(Sprite("objects/ovengame/element_off"), self.bg.x, self.bg.y)
    self.heater:setScale(2)
    self.heater:setOrigin(0.5)

    -- Create pie
    self.pie = self:spawnObject(Sprite("objects/ovengame/pie"), self.bg.x, self.bg.y)
    self.pie:setScale(2)
    self.pie:setOrigin(0.5)

    -- Create steam
    self.steam = self:spawnObject(Sprite("objects/ovengame/steam"), self.pie.x, self.pie.y - 38)
    self.steam:setScale(2)
    self.steam:setOrigin(0.5)
    self.steam:play(0.3, true)
    self.steam.alpha = 0

    -- Create Text object
    self.text = self:spawnObject(Text("[font:digital-segment-regular][color:green]"..self.counter), Game.battle.arena:getRight() - 66, self.centerY + 56, 100, 100)

    -- Set the display and the text
    self:setText("green")

    -- Create stop button
    self.controls = self:spawnObject(ControlsDisplay(self.text.x-20, self.text.y + 62, "button", false))
    self.controls:setOrigin(1, 0.5)
    self.controls:setScale(1.4)

    -- Create stop text
    self.button = self:spawnObject(Sprite("objects/buttons/stop_text"), self.controls.x+2, self.controls.y)
    self.button:setScale(2)
    self.button:setOrigin(0, 0.5)

    -- Beginning Sequence
    self.timer:after(1, function ()
        self.timer:script(function (wait)
            Assets.playSound("snd_cookie_cutter_bounce", 0.6)
            wait(1)
            Assets.playSound("snd_cookie_cutter_bounce", 0.6)
            wait(1)
            Assets.playSound("snd_cookie_cutter_bounce", 0.6)
            wait(1)
            Assets.playSound("snd_cookie_cutter_bounce_higher", 0.6)

            self.counting = true -- Start the count
            self:ticking()

            self.heater:setSprite("objects/ovengame/element") -- Turn on the heating element
            self.heater:play(0.5, true)

            self.timer:after(1, function ()
                self.steam:fadeTo(1, 2)
            end)
        end)
    end)
end

function TorielOvenGame:update()
    super.update(self)

    self.siner = self.siner - (DT * DTMULT)

    -- Stop the timer with "z" if it is counting down
    if Input.pressed("confirm", false) and self.counting then
        if self.counter >= 0.2 then
            Assets.stopAndPlaySound("error", 0.6, 1.2)
        else
            self.counting = not self.counting
            self.text.alpha = 1
            self.fading = false

            self.heater:setSprite("objects/ovengame/element_off")
            self.controls.flash = false
            --self:ticking()
            self:setScore()
        end
    end

    -- If toggled, decrement timer by DT and start fading out the object if it hasn't started yet
    if self.counting then
        if not self.fading then self:fadeText() end -- Lock to prevent this from running every frame

        self.steam.y = self.steam.y + (0.1 * math.sin(self.siner))
    end

    -- Update the pie sprite only when its cooking stage changes.
    local pie_sprite = nil
    if self.counter == 0 then
        pie_sprite = "objects/ovengame/pie_4"
    elseif self.counter <= 3 then
        pie_sprite = "objects/ovengame/pie_3"
    elseif self.counter <= 6 then
        pie_sprite = "objects/ovengame/pie_2"
        if not self.handSpawned then self:toriHand() end -- Start the toriel hand cutscene
    end

    if pie_sprite and self.pie_sprite ~= pie_sprite then
        self.pie_sprite = pie_sprite
        self.pie:setSprite(pie_sprite)
    end

    -- End the minigame if the timer reaches 0
    if self.counter <= 0 and not self.is_scoring then
        self.counting = not self.counting
        self.text.alpha = 1
        self.fading = false

        self.heater:setSprite("objects/ovengame/element_off")
        self.controls.flash = false

        self:setScore()
    end
end

---Sets the text of the text object to the display string
---@param color     string What color to set the text to
function TorielOvenGame:setText(color)
    self.text:setText("[font:digital-segment-regular][color:"..color.."]"..self.counter)
end

-- Make ticking sound every half-second while the timer is counting
function TorielOvenGame:ticking()
    self.timer:script(function (wait)
        while self.counting == true do

            self.counter = self.counter - 1
            self.text:setText("[font:digital-segment-regular][color:green]"..self.counter)

            Assets.playSound("graze", 0.6) -- The first tick
            wait(14 * DT) -- I don't know why I had to set the delay to less than half a second but whatever

            -- Putting this here to prevent the second tick from happening if the timer is already stopped
            -- I don't feel like coming up with a better way to handle this
            if self.counting == true then
                Assets.playSound("graze", 0.3) -- A quiter, second tick
                wait(14 * DT)
            end

        end
    end)
end

-- Fades out the timer visual by a set amount every frame
function TorielOvenGame:fadeText()
    self.fading = true
    self.text:fadeTo(0, self.counter * (5/8)) -- Fade amount is relative to initial timer length
    --self.button:fadeTo(0, self.counter * (5/8)) -- Fade the button out, too
end

-- Spawns in hand, moves towards the stop button, then hits the stop button at last second
function TorielOvenGame:toriHand()
    self.handSpawned = true
    local hand = self:spawnObject(Sprite("objects/whiskgame/hand_left_point"), self.controls.x - 110, self.controls.y + 15)
    hand:setOrigin(1, 0.5)
    hand:setLayer(BATTLE_LAYERS["top"])
    hand.alpha = 0

    -- Lord forgive me, for I have sinned
    self.timer:everyInstant(DT * DTMULT, function ()
        hand.alpha = Utils.approach(hand.alpha, 1, 0.11)
        if hand.alpha == 1 then return false end
    end)

    hand:slideTo(self.controls.x - 75, self.controls.y, 0.5, "out-quad", function ()
        hand:slideTo(self.controls.x - 74.99, self.controls.y, 0.5, "linear", function ()
            hand:slideTo(self.controls.x - self.controls.width/2, self.controls.y, 5, "linear")
        end)
    end)
end

-- Give a score based on how close to 0 the timer was when you stopped it
-- You get no points if the timer passes 0
function TorielOvenGame:setScore()
    self.is_scoring = true

    self:scoreMessage("Perfect", self.text.x, self.text.y)
    Assets.playSound("snd_perfect", 0.6, 1.2)

    self.score = 5 -- Set the score to perfect score

    self.timer:after(1, function () -- End the wave
        self.finished = true
    end)
end

function TorielOvenGame:onEnd()
    -- Flag for toriel custcenes that indicate the recipe is done
    Game:setFlag("TorielSteps", 3)
end

return TorielOvenGame
