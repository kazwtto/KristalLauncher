-- Code written by Mose

local SaladTossGame, super = Class("LightMinigameWave")

function SaladTossGame:init()
    super.init(self, _s("minigame_popup-saladtossgame", "TOSS!"), "button")

    Game:setFlag("Results", "none")

    self.time = -1

    self:setArenaSize(480,320)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 - 10)

    self:setSoulPosition(10000,10000)

    -- A table of all the states the minigame can be in (baby's first finite state machine, sort of)
    self.states = {
        aiming = "aiming",
        power = "power",
        throwing = "throwing",
        scoring = "scoring",
    }

    self.my_power = 15 -- The amount of power used to throw the bowl during the power phase
    self.powerdir = 1 -- Used to increase/decreasae my_power during the power phase
    self.throw_modifier = 0.75 -- Alters the speed of the throwing phase
    self.bowl_height = 0 -- The height of the bowl as it passes through the goal. Recorded at the end of the throwing phase
    self.is_scoring = false -- Whether or not the minigame is being scored, ensures self:scoring() is only run once
    self.result = "too_low" -- The result of the throw. Can be "too_high", "too_low", or "perfect"
end

function SaladTossGame:onStart()
    self.center_x, self.center_y = Game.battle.arena:getCenter()

    -- Make bowl
    self.bowl = self:spawnObject(Sprite("objects/saladtossgame/bowl"), Game.battle.arena:getLeft() + 50, Game.battle.arena:getBottom() - 50)
    self.bowl:setOrigin(0.5)
    self.bowl:setScale(2)
    self.bowl:setLayer(BATTLE_LAYERS["above_soul"])

    -- Make heart
    self.heart = self:spawnObject(Sprite("player/heart_legs_1"), self.bowl.x - 50, self.bowl.y + self.bowl.height)
    self.heart:setOrigin(0.5, 1)
    self.heart:setScale(3)
    self.heart:setLayer(BATTLE_LAYERS["above_soul"])

    -- Make ground
    self.ground = self:spawnObject(Sprite("objects/saladtossgame/ground_alt"), Game.battle.arena:getLeft(), self.bowl.y - 50)
    self.ground:setScale(3)
    self.ground:setLayer(BATTLE_LAYERS["arena"])

    -- Make goal
    self.goal = self:spawnObject(Sprite("objects/saladtossgame/goal"), Game.battle.arena:getRight() - 90, Game.battle.arena:getBottom() - 40)
    self.goal:setOrigin(0.5, 1)
    self.goal:setScale(3)
    self.goal:setLayer(BATTLE_LAYERS["soul"])
    self.goal_range = { -- Table of the y-values of the bottom and top of the goal opening
        bot = self.goal.y - 41 * self.goal.scale_y, -- The bottom of the goal range. The 41 comes from sprite measurments
        top = self.goal.y - self.goal.height * self.goal.scale_y, -- The top of the goalpost
    }
    -- Make front goalpoast seperately so it can render above the bowl
    self.goal_front = self:spawnObject(Sprite("objects/saladtossgame/goal_front"), self.goal.x, self.goal.y)
    self.goal_front:setOrigin(0.5, 1)
    self.goal_front:setScale(self.goal.scale_x, self.goal.scale_y)
    self.goal_front:setLayer(BATTLE_LAYERS["bullets"])

    -- Make arrow
    self.arrow = self:spawnObject(Sprite("objects/saladtossgame/arrow"), self.bowl.x + 40, self.bowl.y - 20)
    self.arrow:setOrigin(0,0.5)
    self.arrow:setScale(2)
    self.arrow:setLayer(BATTLE_LAYERS["soul"])
    self.arrow_lerp = 0 -- Used in the aiming phase to determine the angle of the arrow
    self.arrow_lerp_sign = 1 -- Used in the aiming phase to change the value of the lerp

    -- Make mask above the arena
    local mask_obj = self:spawnObject(Sprite("objects/saladtossgame/mask"), Game.battle.arena:getTopLeft())
    mask_obj:setScale(Game.battle.arena:getSize())
    mask_obj:setLayer(BATTLE_LAYERS["bottom"])
    mask_obj.visible = false
    self.mask = MaskFX(mask_obj)

    -- Add the mask to all the objects
    self.ground:addFX(self.mask)
    self.goal:addFX(self.mask)
    self.goal_front:addFX(self.mask)
    self.bowl:addFX(self.mask)
    self.heart:addFX(self.mask)

    self.state = self.states.aiming -- Immediately set the state to "aiming" on start

    Assets.playSound("grab", 0.25) -- Play the sound that plays at the start of the Ralsei throw in deltarune
end

function SaladTossGame:update()
    super.update(self)

    if self.state == self.states.aiming then self:aiming()
    elseif self.state == self.states.power then self:power()
    elseif self.state == self.states.throwing then self:throwing()
    elseif self.state == self.states.scoring and not self.is_scoring then self:scoring() end
end

function SaladTossGame:aiming()
    -- This stuff sets arrow_lerp, which is used to determine the angle of the arrow
    if self.arrow_lerp <= -1 then self.arrow_lerp_sign = 1
    elseif self.arrow_lerp >= 1 then self.arrow_lerp_sign = -1 end
    self.arrow_lerp = self.arrow_lerp + (self.arrow_lerp_sign * DT * 2)

    self.arrow.rotation = -math.rad(30) + self.arrow_lerp * math.rad(30) -- Set the angle of the arrow

    if Input.pressed("confirm", false) then
        self.arrow:setColor(1,0,0,1) -- Make the arrow red
        self.state = self.states.power -- Switch to the "power" state
    end
end

-- When self.state is set to "power", the trajectory curve is made in self:draw()
function SaladTossGame:power()
    if Input.pressed("confirm", false) then
        self.arrow:remove()
        self.state = self.states.throwing
        Assets.playSound("heavyswing", 0.5)
        self.heart:setSprite("player/heart_legs_2") -- Switch the soul to the other frame of the walk animation
        self.heart:shake() -- Shake the soul for dramatic effect
    end
end

function SaladTossGame:throwing()
    if self.bowl.physics.gravity == 0 then -- Only happens once
        self.bowl:setSpeed(self.lx * self.throw_modifier, self.ly * self.throw_modifier) -- Use the vector values from self:draw() to determine the initial x and y velocities
        self.bowl.physics.gravity = 1 * self.throw_modifier * self.throw_modifier -- Set the gravity of the bowl
        self.bowl.graphics.spin = -math.rad(5) -- Make it spin counterclockwise a bit
    end

    if self.bowl.x >= self.goal.x then -- When the bowl passes through the goal
        self.bowl_height = self.bowl.y -- save the bowl's height so we can use it to determine score
        self.state = self.states.scoring
    end
end

function SaladTossGame:scoring()
    self.is_scoring = true -- This just makes sure scoring() is only run once

    if self.bowl_height < self.goal_range.top then
        self.result = "Too High!"
    elseif self.bowl_height > self.goal_range.bot then
        self.result = "Too Low!"
    else
        self.result = "perfect"
    end

    -- If I decide later to make different animations for failures, then we can get rid of this if statement
    if self.result == "perfect" then -- Play the whole animation if you get a good score
        Assets.playSound("bell_bounce_short", 0.5)

        local time = 1 -- How long the tweens will take
        local dy = 300 -- The difference in y-values the objects will travel
        local ground_y = self.ground.y -- This is saved so the ground can go back to it's original position
        self.timer:after(0.1, function ()
            self.timer:tween(time, self.heart, {y = self.heart.y - dy}, "linear") -- Move the heart up
            self.timer:tween(time, self.ground, {y = self.ground.y - dy}, "linear") -- Move the ground up
            self.timer:tween(time, self.goal, {y = self.goal.y - dy}, "linear") -- Move the goal up
            self.timer:tween(time, self.goal_front, {y = self.goal.y - dy}, "linear", function () -- Move the front part of the goal up, then, when that's done....
                self.goal:remove()
                self.goal_front:remove()

                self.ground.y = Game.battle.arena:getBottom() -- Move the ground to the bottom of the arena
                self.timer:tween(time * 0.8, self.ground, {y = ground_y}, "linear") -- Then move the ground to its original position

                -- Make the big bowl
                local bowl = self:spawnObject(Sprite("objects/saladtossgame/big_bowl_front"), self.center_x, 0)
                bowl:setOrigin(0.5,1)
                bowl:setScale(3)
                bowl:setLayer(BATTLE_LAYERS["above_soul"])
                bowl:addFX(self.mask)
                -- Put the back of the bowl on a different layer
                local bowl_back = self:spawnObject(Sprite("objects/saladtossgame/big_bowl_back"), self.center_x, 0)
                bowl_back:setOrigin(0.5,1)
                bowl_back:setScale(bowl.scale_x, bowl.scale_y)
                bowl_back:setLayer(BATTLE_LAYERS["below_soul"])
                bowl_back:addFX(self.mask)

                self.timer:tween(time, bowl_back, {y = Game.battle.arena:getBottom() - 50}, "in-quad") -- Move the bowl down
                self.timer:tween(time, bowl, {y = Game.battle.arena:getBottom() - 50}, "in-quad", function () -- Move the bowl down, then...
                    bowl:shake()
                    bowl_back:shake()
                    Assets.playSound("noise", 0.6)
                    self:fruitFall(bowl.x, bowl.y, bowl.width * bowl.scale_x, bowl.height * bowl.scale_y) -- Make the fruit fall
                end)
            end)
        end)
    else -- If self.result is not "perfect", make a score message saying the result
        self:scoreMessage(self.result, self.goal.x, self.goal.y - self.goal.height, nil, 0)
        Assets.playSound("error", 0.6, 1.2)

        self.timer:after(1, function () -- End the wave
            self.finished = true
        end)
    end
end

-- Might make a special animation for other results later but I don't want to deal with that right now lmao
-- This plays a little animation of the fruit falling... somehow it ended up being very complicated
function SaladTossGame:fruitFall(bowl_x, bowl_y, bowl_width, bowl_height)
    local amount = 8 -- The amount of fruit to drop
    local fruits = {} -- A temporary table to hold all the fruits

    if self.result == "perfect" then
        local pile = self:spawnObject(Sprite("objects/saladtossgame/big_bowl_fruit"), bowl_x, (bowl_y - bowl_height) + 30) -- The y-value was determined via sprite measurements
        pile:setOrigin(0.5, 0)
        pile:setScale(3)
        pile:setLayer(BATTLE_LAYERS["soul"])
        pile.visible = false
        local pile_dy = ((bowl_y - bowl_height) - pile.y) / amount -- The amount to change the y-value of the pile every time a fruit lands

        for i = 1, amount do
            local x = math.random((bowl_x - bowl_width/2) + 30, (bowl_x + bowl_width/2) - 30) -- Generate a random x-coord within the range of the bowl (30 adjusts for sprite edges)
            local y = math.random(-200, 0) -- Generate a random y-coord within the range from the top of the screen to just above the top of the arena 
            local f = self:spawnObject(Sprite("objects/saladtossgame/fruit/"..math.random(1,4)), x, y) -- Spawn a random fruit sprite at the top of the screen
            f:setOrigin(0.5)
            f:setScale(3)
            f:setLayer(BATTLE_LAYERS["soul"])
            f:addFX(self.mask)
            f.rotation = math.random(0, 2 * math.pi) -- Give the fruit a random rotation
            f.physics.gravity = 1 + (math.random()) -- Pick a random gravity amount, so that some fall faster than others
            table.insert(fruits, f)
        end

        self.timer:every(DT, function () -- Every frame,
            for i, f in ipairs(fruits) do -- Look through the fruit list
                if f.y >= bowl_y - (bowl_height + 30) then -- And check if a fruit has fallen into the bowl (The 20 comes from sprite measurements)
                    f:remove() -- If it has, remove it
                    table.remove(fruits, i)
                    pile.visible = true
                    pile.y = pile.y + pile_dy -- And move the fruit pile up a bit
                    Assets.playSound("snd_bottlebloop", 0.25, 1.2)
                end
            end

            if #fruits == 0 then -- If all of the fruit have fallen, display "perfect" score message and end the minigame
                self:scoreMessage("Perfect", pile.x, pile.y)
                Assets.playSound("snd_perfect", 0.6, 1.2)

                self.timer:after(1, function () -- End the wave
                    self.finished = true
                end)

                return false
            end
        end)
    end
end

function SaladTossGame:draw()
    super.draw(self)

    if self.state == self.states.power then
        local grav = 1
        local angle = self.arrow.rotation
        local maxpower = 30
        local minpower = 15
        local powerspeed = 0.6
        local x = self.arrow.x
        local y = self.arrow.y
        self.lx = math.cos(angle)*self.my_power
        self.ly = math.sin(angle)*self.my_power

        self.my_power = self.my_power + (self.powerdir * powerspeed)*DTMULT
        if (self.my_power >= maxpower) then
            self.powerdir = -1
        elseif (self.my_power <= minpower) then
            self.powerdir = 1
        end

        local points = self._cwk_trajectory_points
        if not points then
            points = {}
            self._cwk_trajectory_points = points
        end

        love.graphics.setColor(0.5, 0.5, 1)
        for i=0, 20 do
            local step = i * 2
            local xx = x + self.lx * step
            local yy = y + self.ly * step + ((step + 1) * (step + 2) / 2) * grav
            points[i * 2 + 1] = xx
            points[i * 2 + 2] = yy
            love.graphics.circle("fill", xx, yy, 5)
        end
        love.graphics.setLineWidth(3)
        love.graphics.line(unpack(points))
    end
end

function SaladTossGame:onEnd()
    if self.result == "perfect" then
        CustScore:addPoints(3)
    else
        CustScore:addPoints(0)
        Stepscript:backStep("salad_toss")
    end
end

return SaladTossGame