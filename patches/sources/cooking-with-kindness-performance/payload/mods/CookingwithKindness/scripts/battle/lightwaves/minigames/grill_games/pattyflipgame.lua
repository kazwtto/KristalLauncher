-- Code written by Mose

local PattyFlipGame, super = Class("LightMinigameWave")

function PattyFlipGame:init()
    super.init(self, _s("minigame_popup-pattyflipgame", "FLIP!"), "full_layout")

    Game:setFlag("Results", "none")

    self.time = -1

    self:setArenaSize(200,150)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 - 10)

    self.max_patties = 5 -- The amount of patties to be put on the grill
    self.patties = {} -- A table containing all the patties on the grill

    self.first_out = false -- Whether the first patty has been placed (used to determine which patty gets the controlls popup)

    self.state_times = {5, 9, 13} -- A table containing the times, in order, at which each burger's state should change
    self.gby_amt = 2 -- The amount of extra seconds grillby wants you to cook the burgers

    self.flipping = false -- Whether the spatula is flipping a patty

    self.airtime = 0.6 -- How long it should take for a patty to travel when it's flying through the air

    self.scores = {} -- A table to be filled with the amount of time each patty was cooked
    self.scoring = false -- Whether or not we are actively scoring the patties (just makes sure it doesn't happen 1 million times)
end

function PattyFlipGame:onStart()
    self.center_x, self.center_y = Game.battle.arena:getCenter()

    -- Create spatula
    self.spatula = self:spawnObject(Sprite("objects/pattyflipgame/spatula_1"), Game.battle.arena:getLeft() + 40, self.center_y + 40)
    self.spatula:setLayer(BATTLE_LAYERS["below_soul"])
    self.spatula:setScale(2)
    self.spatula:setOrigin(0.5)
    self.spatula.collider = Hitbox(self.spatula, 6.5, 8, self.spatula.width/2, self.spatula.height/6)
    self.spatula.speed = 7

    -- Show controls
    self.controls = self:spawnObject(ControlsDisplay(Game.battle.arena:getLeft() - 40, Game.battle.arena:getTop() + 40, "full_layout_alt"))
    self.controls:setOrigin(0.5)
    self.controls:setScale(1.4)
    self.controls:setLayer(BATTLE_LAYERS["top"])
    self.timer:after(2, function ()
        self.controls:remove()
    end)

    -- Spawn 5 patties at random intervals and at random points on the grill (so long as it's not on top of another patty)
    self.timer:script(function (wait)
        self:spawnPatty(self.center_x, self.center_y)
        wait(math.random(2,3))
        for i = 2, self.max_patties do -- Starting at  i=2 because one patty has already been put out
            self:spawnPatty(self:getGoodCoords())
            wait(math.random(2,3))
        end
    end)
end

function PattyFlipGame:update()
    super.update(self)

    if not self.flipping then
        self:moveSpatula()
    end

    for i, p in ipairs(self.patties) do
        if p.cooking then
            p.timer = p.timer + DT
        end

        if not self.first_out and p.cooking then
            self:pattyEffect(p, "tutorial")
        end

        -- All of this handles changing the cooking state of each burger
        if p.state == 0 and p.timer >= self.state_times[1] then -- If at state 0 and passing first time threshold, change to state 1
            self:updatePatty(p, 1)

        elseif p.state == 1 and (p.timer >= self.state_times[2] - 2 and p.timer < self.state_times[2]) and p.flip_count == 0 and not p.warned then -- If at state one, approaching the second time threshold, and hasn't been flipped
            self:warning(p)

        elseif p.state == 1 and p.timer >= self.state_times[2] then -- If at state one and passing second time threshold
            if p.flip_count == 1 then -- If you flipped the burger once already, change to state 2
                self:updatePatty(p, 2)
            else -- If you still haven't flipped the burger, burn the burger
                self:updatePatty(p, 3)
                p.timer = self.state_times[3]
            end

        elseif p.state == 2 and (p.timer >= self.state_times[3] - 2 and p.timer < self.state_times[3]) and p.flip_count == 1 and not p.warned then -- If at state two, approaching the final time threshold, and hasn't been flipped for a second time
            self:warning(p)

        elseif p.state == 2 and p.timer >= self.state_times[3] then -- If at state two and passing the third time threshold, burn the burger
            self:updatePatty(p, 3)
        end

        -- If you hit confirm while the spatula is under a patty, and if the spatula is not currently flipping, flip the patty
        if Input.pressed("confirm", false) and self.spatula.collider:collidesWith(p.collider) and not self.flipping then
            self:flipPatty(p, i)
        end

        if p.to_be_removed then
            table.remove(self.patties, i)
            table.insert(self.scores, p.timer)
            p:remove()
        end
    end

    if #self.scores == self.max_patties and not self.scoring then
        self.scoring = true
        self.timer:after(0.5, function ()
            self.finished = true
        end)
    end
end

-- Left right up and down inputs to move spatula across arena
function PattyFlipGame:moveSpatula()
    if Input.down("right") and self.spatula.x < Game.battle.arena:getRight() then
        self.spatula.x = self.spatula.x + DTMULT*self.spatula.speed
    end

    if Input.down("left") and self.spatula.x > Game.battle.arena:getLeft() then
        self.spatula.x = self.spatula.x - DTMULT*self.spatula.speed
    end

    if Input.down("down") and (self.spatula.y - self.spatula.height/2) < Game.battle.arena:getBottom() then
        self.spatula.y = self.spatula.y + DTMULT*self.spatula.speed
    end

    if Input.down("up") and (self.spatula.y - self.spatula.height/2) > Game.battle.arena:getTop() then
        self.spatula.y = self.spatula.y - DTMULT*self.spatula.speed
    end
end

-- Returns a set of coordinates that do not conflict with the location of another patty
function PattyFlipGame:getGoodCoords()
    -- If there are no patties, then just pick random coordiates, otherwise do the actual thing
    if #self.patties == 0 then
        return math.random(Game.battle.arena:getLeft() + 20, Game.battle.arena:getRight() - 20), math.random(Game.battle.arena:getTop() + 20, Game.battle.arena:getBottom() - 20)
    else
        local x
        local y
        local test = self.patties[1]

        while x == nil and y == nil do
            local conflicting = false

            local temp_x = math.random(Game.battle.arena:getLeft() + test.width*1.5, Game.battle.arena:getRight() - test.width*1.5)
            local temp_y = math.random(Game.battle.arena:getTop() + test.height, Game.battle.arena:getBottom() - test.height)

            for _, p in ipairs(self.patties) do
                -- Only check whether the x-value conflics if the y-value is conflicting
                if temp_y > (p.y - p.height*2) and temp_y < ((p.y + p.height*2)) then
                    if temp_x > (p.x - p.width*2) and temp_x < ((p.x + p.width*2)) then -- If both still conflict, start over, and don't bother testing the other one
                        conflicting = true
                        break
                    end
                end

                -- Only check whether the y-value conflicts if the x-value is conflicting
                if temp_x > (p.x - p.width*2) and temp_x < ((p.x + p.width*2)) then
                    if temp_y > (p.y - p.height*2) and temp_y < ((p.y + p.height*2)) then -- If both still conflict, start over
                        conflicting = true
                        break
                    end
                end
            end

            if conflicting then
                --print("bad coords")
            else
                x, y = temp_x, temp_y
                break
            end
        end

        return x, y
    end
end

-- Spawns a patty and flips it from the edge of the screen to the given coordinates
function PattyFlipGame:spawnPatty(x, y)
    local patty = self:spawnObject(Sprite("objects/pattyflipgame/patty/flip/0"), SCREEN_WIDTH + 10, self.center_y)
    patty:setLayer(BATTLE_LAYERS["soul"])
    patty:setScale(2.8)
    patty:setOrigin(0.5)
    patty:play(0.125)
    
    patty.collider = Hitbox(patty, patty.width/2 - 3, patty.height/2 - 6, 6, 6)

    patty.timer = 0 -- Will count how long the patty has been out
    patty.state = 0 -- How cooked the patty is (0=Raw, 1=Halfway, 2=Cooked, 3=Burned)
    patty.flip_count = 0 -- How many times this patty has been flipped
    patty.cooking = false -- Whether or not the patty is being cooked and timer is being incremented
    patty.warned = false -- If this patty is currently flashing a warning
    patty.to_be_removed = false -- A flag for if the patty needs to be removed

    table.insert(self.patties, patty)

    self.timer:tween(self.airtime, patty, {x = x, y = y, scale_x = 2, scale_y = 2}, "linear", function () -- Move the patty from the edge of the screen to its spot on the stove
        patty.cooking = true -- Start cooking the patty
        patty:setSprite("objects/pattyflipgame/patty/0") -- Set it to the sizzling animation
        patty:play(0.1)
        Assets.playSound("snd_sizzle", 0.5, 1.4) -- Play a little sizzle sound
    end)
end

-- Updates various properties of a patty object
---@class patty     Object -- The patty to be updated
---@param state     number -- Which state to set the patty to
function PattyFlipGame:updatePatty(patty, state)
    patty.state = state
    patty:setSprite("objects/pattyflipgame/patty/"..state)
    patty:play(0.08)

    if patty.effect then patty.effect:remove() end

    if state == 1 then
        Assets.playSound("snd_sizzle", 0.75, 1.2)
    elseif state == 2 then
        self:pattyEffect(patty, "steam")
        Assets.playSound("snd_sizzle", 1, 1)
    elseif state == 3 then
        self:pattyEffect(patty, "fire")
        Assets.playSound("bomb", 0.5, 1)
    end
end

-- Various effects that appear over the patties
function PattyFlipGame:pattyEffect(patty, type)
    if type ~= "tutorial2" then
        patty.effect = self:spawnObject(Sprite("objects/pattyflipgame/"..type), patty.x, patty.y)
        patty.effect:setScale(2)
        patty.effect:setOrigin(0.5,1)
        patty.effect:setLayer(BATTLE_LAYERS["above_soul"]) 
    end

    if type == "steam" then
        patty.effect.y = patty.y - 20
        patty.effect:play(0.5)

        self.timer:script(function (wait)
            while patty.effect.texture_path == "objects/pattyflipgame/steam_1" or patty.effect.texture_path == "objects/pattyflipgame/steam_2" do
                patty.effect:slideTo(patty.effect.x, patty.effect.y + 10, 1, "linear", function ()
                    patty.effect:slideTo(patty.effect.x, patty.effect.y - 10, 1, "linear")
                end)
                wait(2)
            end
            return false
        end)

    elseif type == "fire" then
        patty.effect:play(0.1)

    elseif type == "tutorial" then
        self.first_out = true
        patty.effect:setSprite("objects/buttons/waittext")
        patty.effect:setScale(1)
        patty.effect.y = patty.y - 20

        self.timer:after(self.state_times[1], function ()
            if patty.cooking == true then
                self:pattyEffect(patty, "tutorial2") -- Bandaid solution bc I don't feel like figuring out something better
            end
        end)

    elseif type == "tutorial2" and patty.effect.x > Game.battle.arena:getLeft() then -- Even more baind-aid solution to stop "z" from appearing on the left side of the screen
        patty.effect = self:spawnObject(ControlsDisplay(patty.x, patty.y-20, "button_alt"))
        patty.effect:setScale(1.4)
        patty.effect:setOrigin(0.5,1)
        patty.effect:setLayer(BATTLE_LAYERS["above_soul"])

        self.timer:after(self.state_times[2] - self.state_times[1], function ()
            patty.effect:remove()
        end)
    end
end

function PattyFlipGame:warning(patty)
    patty.warned = true
    patty.warning = self:spawnObject(Sprite("ui/battle/icons/warning"), patty.x, patty.y - 15)
    patty.warning:setScale(3)
    patty.warning:setOrigin(0.5,1)
    patty.warning:setLayer(BATTLE_LAYERS["above_bullets"])
    patty.warning:play(0.1)

    self.timer:every(0.1, function ()
        if patty.warned then
            Assets.playSound("snd_warn", 0.25)
        else
            return false
        end
    end)

    self.timer:after(2, function ()
        patty.warning:remove()
        patty.warned = false
    end)
end

-- Flips spatula, plays patty flip animation, and increments flip_count for the patty
function PattyFlipGame:flipPatty(patty, index)
    self.flipping = true -- Stop the spatula from moving

    patty.cooking = false -- Stop the patty from cooking
    if patty.effect then patty.effect:remove() end
    if patty.warning then patty.warning:remove() end
    patty.warned = false

    patty:setSprite("objects/pattyflipgame/patty/flip/"..patty.state) -- Change the patty to the flip animation
    patty:play(0.1, false)
    self.spatula:setSprite("objects/pattyflipgame/spatula_2") -- Change the spatula to the raised sprite

    Assets.playSound("snd_chop_4")

    patty.flip_count = patty.flip_count + 1 -- Add onto the patty's flip count

    if patty.timer < self.state_times[patty.flip_count] or patty.state == 3 then -- If you flipped the patty before it reached the next threshold, or if the patty is burning
        self.timer:tween((self.airtime/2)*DTMULT, patty, {x = 0, y = self.center_y, scale_x = 2.8, scale_y = 2.8}, "linear", function () -- Throw the patty off the left edge of the screen
            self.spatula:setSprite("objects/pattyflipgame/spatula_1") -- Set the spatula sprtie back
            self.flipping = false -- Let the spatula move again
            patty.to_be_removed = true -- Mark this patty for deletion
            self:scoreMessage(patty, "x")
        end)

    elseif patty.state == 2 then -- If you flip a finished patty
        self.timer:tween((self.airtime/2)*DTMULT, patty, {x = x, y = 0, scale_x = 2.8, scale_y = 2.8}, "linear", function () -- Throw the patty somewhere
            self.spatula:setSprite("objects/pattyflipgame/spatula_1") -- Set the spatula sprtie back
            self.flipping = false -- Let the spatula move again
            patty.to_be_removed = true -- Mark this patty for deletion
            if patty.timer >= self.state_times[2] + self.gby_amt then -- Only display the checkmark if the patty is done according to Grillby's order
                self:scoreMessage(patty, "check")
            end
        end)

    else -- If you haven't flipped too many times
        patty.timer = self.state_times[patty.flip_count] -- Set the patty's timer back to the beginning of this threshold

        self.timer:tween(0.25*DTMULT, patty, {scale_x = 2.8, scale_y = 2.8}, "out-quad", function () -- Make the patty bigger (so it looks like it's moving towards the camera)
            self.spatula:setSprite("objects/pattyflipgame/spatula_1") -- Set the spatula sprtie back
            self.flipping = false -- Let the spatula move again
            self.timer:tween(0.25*DTMULT, patty, {scale_x = 2, scale_y = 2}, "in-quad", function () -- Make the patty its original size (so it looks like it lands back on the grill)
                patty:setSprite("objects/pattyflipgame/patty/"..patty.state) -- Make the sprite animate again
                patty:play(0.08)
                patty.cooking = true -- Start cooking the patty further
            end)
        end)
    end
end

---@param type      string The type of message to show ("x" or "check")
function PattyFlipGame:scoreMessage(patty, type)
    local text = self:spawnObject(Sprite("ui/battle/scoremsg/"..type), patty.x, 0)
    text:setScale(4)
    text:setOrigin(0.5)
    text:setLayer(BATTLE_LAYERS["top"])

    if type == "x" then
        text.x = 0
        text.y = self.center_y
        Assets.playSound("error", 0.6, 1.2)
        text:slideTo(text.x + 100, text.y + Utils.random(-100, 100, 10), 1/3, "out-cubic", function()
            text:fadeOutAndRemove(0.5)
        end)

    elseif type == "check" then
        Assets.playSound("snd_good", 0.6, 1.2)
        text:slideTo(text.x + Utils.random(-100, 100, 10), text.y + 100, 1/3, "out-cubic", function()
            text:fadeOutAndRemove(0.5)
        end)
    end    
end

-- This needs to be properly balanced at some point.
function PattyFlipGame:onEnd()
    local score = 0
    local is_burnt = false
    local is_raw = false
    
    -- Average together all of the patty cook times
    local avg = 0
    for i = 1, #self.scores do
        avg = avg + self.scores[i]

        if self.scores[i] >= self.state_times[3] then -- If any patty is burnt, add a shit ton of extra time and toggle the burnt bool
            avg = avg + 50
            is_burnt = true
        elseif self.scores[i] <= self.state_times[1] then -- If any patty is raw, remove a shit ton of time and toggl ehte raw bool
            avg = avg - 50
            is_raw = true
        end
    end
    avg = avg/#self.scores

    if not is_burnt and not is_raw then
        if avg >= self.state_times[2] + self.gby_amt and avg < self.state_times[3] then -- If the avg is greater than gby amount wihtout burning the patty, "perfect" (avg > self.state_times[2] + self.gby_amt - 0.2) and (avg <= self.state_times[2] + self.gby_amt + 0.3)
            score = 5
            Game:setFlag("Results", "perfect")
        elseif avg >= self.state_times[3] then -- If the avg is greater than the burn amount, Score = 0, "burnt"
            score = 0
            Game:setFlag("Results", "burnt")
        elseif avg > self.state_times[2] then -- If it is between to the "done" time and grillby time, Score = 3, "normal"
            score = 3
            Game:setFlag("Results", "normal")
        elseif avg > self.state_times[1] then -- If it is less than "done" time, Score = 2, "undercooked"
            score = 2
            Game:setFlag("Results", "undercooked")
        elseif avg < self.state_times[1] then -- If it is less than the first cooking state, Score = 0, "raw"
            score = 0
            Game:setFlag("Results", "raw")
        end
    else
        if is_burnt then
            score = 0
            Game:setFlag("Results", "burnt")
        elseif is_raw then
            score = 0
            Game:setFlag("Results", "raw")
        end
    end

    --print(avg)
    --print(Game:getFlag("Results"))

    CustScore:addPoints(score)
    if Game:getFlag("Results") ~= "perfect" then
        Stepscript:backStep("burgerflip")
    end
end

return PattyFlipGame