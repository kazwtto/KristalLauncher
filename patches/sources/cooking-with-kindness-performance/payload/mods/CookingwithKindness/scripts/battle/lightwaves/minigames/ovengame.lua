-- Code written by Mose

local OvenGame, super = Class("LightMinigameWave")

function OvenGame:init()
    super.init(self, _s("minigame_popup-ovengame", "STOP AT ZERO"), "button")

    self.time = -1

    self:setArenaSize(450,300)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 30)

    self.counter = math.random(8,9)
    self.counting = false
    self.fading = false
    self.is_scoring = false
    self.score = 0
    self.is_waiting_for_fail = false
    self.failed = false

    self.siner = self.counter
end

function OvenGame:onStart()
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

function OvenGame:update()
    super.update(self)

    self.siner = self.siner - (DT * DTMULT)

    -- Stop the timer with "z" if it is counting down
    -- Commented parts are for debugging
    if Input.pressed("confirm", false) and self.counting then
        --if self.counting == false then
        --    self.counter = 9.00
        --end
        self.counting = not self.counting
        self.text.alpha = 1
        self.fading = false

        self.heater:setSprite("objects/ovengame/element_off")
        self.controls.flash = false

        --self:ticking()
        self:setScore()
    end

    -- If toggled, decrement timer by DT and start fading out the object if it hasn't started yet
    if self.counting then
        if not self.fading then self:fadeText() end -- Lock to prevent this from running every frame

        self.steam.y = self.steam.y + (0.1 * math.sin(self.siner))
    end

    -- If the timer falls below zero, stop counting and run failure event if it hasn't started yet
    -- Also burn the pie
    if self.counter == 0 and not self.is_waiting_for_fail and not self.is_scoring then
        self.is_waiting_for_fail = true
        self.timer:after(0.33, function ()
            if not self.is_scoring then
                self.is_scoring = true
                self.pie:setSprite("objects/ovengame/pie_burn") -- Burn the pie
                self.pie:play(0.15, true)
                self.steam:remove()
                self.heater:setSprite("objects/ovengame/element_off")
                self:failEvent()
            end
        end)
    end

    -- Update the pie sprite only when its cooking stage changes.
    if not self.is_scoring then
        local pie_sprite = nil
        if self.counter == 0 then pie_sprite = "objects/ovengame/pie_4"
        elseif self.counter <= 3 then pie_sprite = "objects/ovengame/pie_3"
        elseif self.counter <= 6 then pie_sprite = "objects/ovengame/pie_2" end

        if pie_sprite and self.pie_sprite ~= pie_sprite then
            self.pie_sprite = pie_sprite
            self.pie:setSprite(pie_sprite)
        end
    end
end

---Sets the text of the text object to the display string
---@param color     string What color to set the text to
function OvenGame:setText(color)
    self.text:setText("[font:digital-segment-regular][color:"..color.."]"..self.counter)
end

-- Make ticking sound every half-second while the timer is counting
function OvenGame:ticking()
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
function OvenGame:fadeText()
    self.fading = true
    self.text:fadeTo(0, self.counter * (5/8)) -- Fade amount is relative to initial timer length
    self.button:fadeTo(0, self.counter * (5/8)) -- Fade the button out, too
    self.controls:fadeTo(0, self.counter * (5/8)) -- Fade the button out, too
end

-- Give a score based on how close to 0 the timer was when you stopped it
-- You get no points if the timer passes 0
function OvenGame:setScore()
    self.is_scoring = true

    local msg = "" -- What message to dislpay
    local snd = "error" -- What sound effect to play

    -- All the different scores
    if self.counter >= 2 then -- At or above 2s
        self:failEvent() -- Make this count as a fail
        if Utils.random() > 0.25 then
            msg = "Bad"
        else
            msg = ":("
        end
        snd = "error"
    elseif self.counter == 1 then -- At 1s
        self.score = 2
        msg = "Okay"
        snd = "snd_good"
    elseif self.counter == 0 then -- At 0s
        self.score = 5
        msg = "Perfect"
        snd = "snd_perfect"
    elseif self.counter < 0 then -- Below 0s
        self.score = 0
    end

    self:scoreMessage(msg, self.text.x, self.text.y)
    Assets.stopAndPlaySound(snd, 0.6, 1.2)

    self.timer:after(1, function () -- End the wave
        self.finished = true
    end)
end

-- Cutscene for if the timer passes below 0
function OvenGame:failEvent()
    self.failed = true
    self.counting = false
    self.text.alpha = 1
    self.text:setText("[font:digital-segment-regular][color:red]"..self.counter) -- Make the text red
    Assets.playSound("error", 0.6, 1.2)
    self.score = 0

    self.timer:script(function (wait) -- Flash the text a bit
        wait(0.22)
        self.text:fadeTo(0, 0.01)
        wait(0.22)
        self.text:fadeTo(1, 0.01)
        wait(0.22)
        self.text:fadeTo(0, 0.01)
        wait(0.22)
        self.text:fadeTo(1, 0.01)
    end)

    self.timer:after(1, function () -- End the wave
        self.finished = true
    end)
end

function OvenGame:onEnd()
    if Game.battle:getEnemyBattler("mimi") and Game:getFlag("mimiLocked", true) == true then
        CustScore:addPoints(self.score - 2)
    else
        CustScore:addPoints(self.score)
    end
    if self.failed == true then
        Stepscript:backStep("heatinggame")
    end
end

return OvenGame
