-- Code written by Mose

local MeatballGame, super = Class("LightMinigameWave")

function MeatballGame:init()
    super.init(self, _s("minigame_popup-meatballgame", "CATCH!"), "horiz_layout_alt")

    Game:setFlag("Results", "none")

    self.delays = {}
    self.winAmnt = 0 -- Amount of balls to catch to win

    -- If the enemy is not catamari, set "soothed_ball" to true so evil balls don't appear
    if not Game.battle:getEnemyBattler("catamari") then
        Game:setFlag("soothed_ball", true)
        self.delays = {4, 1.8, 4, 3, 5, 4, 4, 3, 3, 3, 2} -- A table of all the delays (in seconds) for sending out balls, in order, for other everyone but catamari
        self.winAmnt = 4
    else
        self.delays = {7, 4, 4, 1.8, 5.2, 4, 2, 3, 5, 2, 1, 5, 4, 4} -- A table of all the delays (in seconds) for sending out balls, for catamari
        self.winAmnt = 3
    end

    self.time = -1

    self:setArenaSize(500,300)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 10)

    self.ballsOut = {} -- A table of all the current balls (good and bad) that are out

    self.can_move = true

    self.useTimer = 0
    self.useFlashTimer = 0

    self.stunFrames = 30/30

    self.duration = 2.5 -- The default duration of each arc of the balls
    self.timerMult = 1 -- The modifier to multiply self.duration (should be between 0 and 1)

    self.failCount = 0 -- Counter for how many balls have been dropped
    self.catchCount = 0 -- Counter for how many balls have landed on the plate

end

function MeatballGame:onStart()
    self.centerX, self.centerY = Game.battle.arena:getCenter()

    -- Create background
    self.bg = self:spawnObject(Sprite("objects/meatballgame/bg"), self.centerX, self.centerY)
    self.bg:setOrigin(0.5)
    self.bg:setLayer(BATTLE_LAYERS["arena"])
    self.bg:play(0.5)

    -- Create plate
    self.plate = self:spawnObject(Sprite("objects/meatballgame/plate_alt"), Game.battle.arena.left + 453, 362)
    self.plate:setOrigin(0.5)
    self.plate:setScale(2)
    self.plate:setLayer(BATTLE_LAYERS["above_bullets"])
    
    -- Create player cat
    self.cat = self:spawnObject(Sprite("objects/meatballgame/cat_alt"), 195, self.centerY + 114)
    self.cat:setOrigin(0.5)
    self.cat:setLayer(BATTLE_LAYERS["below_bullets"])
    self.cat.collider = Hitbox(self.cat, 0, 4, self.cat.width, 0)
    self.cat:play(0.8, true)

    -- Make a reference meatball for scaling and distance purposes
    self.testball = self:spawnObject(Sprite("objects/meatballgame/meatball"), 10000, 10000)
    self.testball:setScale(2)
    self.testball:setOrigin(0.5)

    self.arcMin = (self.cat.y - self.testball.width) -- y-value for the lowest point in the arcs of the balls

    -- Show controls
    self.controls = self:spawnObject(ControlsDisplay(self.cat.x, self.cat.y + 24, "horiz_layout_alt"))
    self.controls:setOrigin(0.5)
    self.controls:setScale(1.4)
    print(MathUtils.rangeMap(2, 1, 3, 1, 2))
    self.timer:after(2, function ()
        self.controls:fadeOutAndRemove(0.01)
    end)

    -- Create miss counter
    self.counter = self:spawnObject(Sprite("objects/meatballgame/miss_counter_0"), Game.battle.arena.right - 68, Game.battle.arena.top + 10)
    self.counter:setScale(3)
    local text = self:spawnObject(Text("[font:main, 32]MISS:"), self.counter.x - 68, self.counter.y - 9)

    self.timer:after(1, function ()
        self:spawnBall(self.duration * self.timerMult, "good")
        self:spawnHandler()
    end)

end

function MeatballGame:update()
    super.update(self)

    --self.timerMult = self.timerMult - 0.0001 -- Not working properly with the physics right now
    --print(self.timerMult)

    if self.can_move then
        self:moveCat()
    end

    -- Cat flashing effect while stunned
    if self.useTimer > 0 then
        self.useTimer = Utils.approach(self.useTimer, 0, DT)
        self.useFlashTimer = self.useFlashTimer + DT
        local amt = math.floor(self.useFlashTimer / (4/30))
        local dimmed = (amt % 2) == 1
        if dimmed then
            if self.cat.color[1] ~= 0.5 or self.cat.color[2] ~= 0.5 or self.cat.color[3] ~= 0.5 then
                self.cat:setColor(0.5, 0.5, 0.5)
            end
        else
            if self.cat.color[1] ~= 1 or self.cat.color[2] ~= 1 or self.cat.color[3] ~= 1 then
                self.cat:setColor(1, 1, 1)
            end
        end
    else
        self.useFlashTimer = 0
        if self.cat.color[1] ~= 1 or self.cat.color[2] ~= 1 or self.cat.color[3] ~= 1 or self.cat.alpha ~= 1 then
            self.cat:setColor(1, 1, 1, 1)
        end
    end

    Object.startCache()
    for i, ball in ipairs(self.ballsOut) do
        if ball.collider:collidesWith(self.cat.collider) and ball.y < (self.cat.y - ball.width/2) and ball.just_bounced == false then
            if ball.tag == "good" then
                ball.just_bounced = true

                ball:setSpeed(self.vx*DT, self:getNeededVelocity(ball.bounces, ball.t, ball.g))
                ball.bounces = ball.bounces + 1

                -- Cat bounce animation
                Assets.playSound("snd_bottlebloop", 0.9, 0.9)
                
                self.cat:setSprite("objects/meatballgame/cat_bounce_alt")
                self.cat:play(0.15, false)

                self.timer:after(0.3, function ()
                    self.cat:setSprite("objects/meatballgame/cat_alt")
                    self.cat:play(0.8, true)
                    ball.just_bounced = false
                end)
            elseif ball.tag == "bad" then
                self.can_move = false
                self.cat:setSpeed(0,0)
                self.cat:setSprite("objects/meatballgame/cat_hurt")

                Assets.playSound("bluh", 0.5, 1.1)

                ball:setSpeed((-self.vx*DT)*2, (self:getNeededVelocity(0, ball.t, ball.g))/2)

                -- Start flash timer
                self.useTimer = self.stunFrames

                -- End stun
                self.timer:after(self.stunFrames, function ()
                    self.can_move = true
                    self.cat:setSprite("objects/meatballgame/cat_alt")
                    self.cat:play(0.8, true)
                end)
            end
        end

        -- If a ball passes below the arena, remove it
        -- Add to failcount
        if ball.y >= SCREEN_HEIGHT then
            if ball.tag == "good" and ball.x <= (self.plate.x - self.plate.width/2) then -- Add to failcount only if a meatball was dropped
                self.failCount = self.failCount + 1 
                self.counter:setSprite("objects/meatballgame/miss_counter_"..self.failCount)

                local text = self:spawnObject(Sprite("ui/battle/scoremsg/miss"), ball.x, Game.battle.arena.bottom)
                text:setOrigin(0.5)
                text:setLayer(BATTLE_LAYERS["top"])

                Assets.playSound("error", 0.6, 1.2)

                -- Slide the text away and fade it out
                text:slideTo(text.x, text.y - 50, 1/3, "out-cubic", function()
                    text:fadeOutAndRemove(0.5)
                end)
            end

            table.remove(self.ballsOut, i) -- Remove it from the table
            ball:remove() -- Remove it from the battle
        end

        -- If a ball passes behind the plate, remove the ball [shake the bowl?, play a sound?]
        -- Add to catchcount
        if ball.x >= (self.plate.x - self.plate.width/2) and ball.y <= (self.plate.y + 5) and ball.y >= (self.plate.y - 5) then
            table.remove(self.ballsOut, i) -- Remove it from the table
            ball:remove() -- Remove it from the battle

            Assets.playSound("egg", 0.8, 1)
            self.plate:shake(2)

            self.catchCount = self.catchCount + 1 -- Add to catchcount
        end

        -- If the minigame is over, stop the balls from moving
        if self.is_scoring then
            ball:setSpeed(0,0)
            ball.physics.gravity = 0
            ball.physics.spin = 0
        end
    end
    Object.endCache()

    if (self.catchCount >= self.winAmnt or self.failCount >= 3) and not self.is_scoring then
        self:score()
    end

end

-- Move the cat by a specified amount when you press "left" or "right"
function MeatballGame:moveCat()
    if Input.pressed("left", false) and self.cat.x > 195 then
        self.cat.x = self.cat.x - 117
    elseif Input.pressed("right", false) and self.cat.x < 424 then
        self.cat.x = self.cat.x + 117
    end
end

-- Spawn the balls with specified timing
function MeatballGame:spawnHandler()
    self.timer:script(function (wait)
        local type = "good"

        for i, v in ipairs(self.delays) do -- Loop through the table of all of the delays
            wait(v * self.timerMult) -- Wait for the specified delay
            
            -- If you used the soothe ACT on the ball then no bad balls will spawn
            -- Otherwise, bad balls have a 40% chance to replace normal meatballs
            if Game:getFlag("soothed_ball", false) == true then
                type = "good"
            else
                if love.math.random() <= 0.6 then type = "good"
                else type = "bad" end
            end
            
            if not self.is_scoring then -- If we're not scoring yet
                self:spawnBall(self.duration * self.timerMult, type) -- Spawn the ball in
            end
        end

        self:score() -- If you make it to the end of the list, just end the minigame early
    end)
end

---Spawns a ball in the building, does some physics to determine trajectory, then shoots the ball out the window
---@param t     number How long the the ball stays in the air for
---@param type  string "good" or "bad". The type of ball that will spawn
function MeatballGame:spawnBall(t, type)
    Assets.playSound("noise", 0.5, 1.1) -- Play sound effect

    local sprite = ""
    if type == "good" then sprite = "meatball"
    elseif type == "bad" then sprite = "badball"
    else print("No ball type given!") end

    local ball = self:spawnObject(Sprite("objects/meatballgame/"..sprite), Game.battle.arena.left + 13, Game.battle.arena.top + 103)
    ball:setScale(2)
    ball:setOrigin(0.5)
    ball:setLayer(BATTLE_LAYERS["bullets"])
    ball.collider = CircleCollider(ball, ball.width/2, ball.width/2, ball.width/2)
    ball.physics.match_rotation = true -- Needed to set spin
    ball.physics.spin = 0.02 + (love.math.random() * 0.2) -- Make it spin a random amount between 0.02 and 0.22 radians per frame

    ball.tag = type -- A little label to show what kind of ball this is
    ball.just_bounced = false
    ball.bounces = 0 -- Another label to show how many times the ball has been bounced 
    ball.t = t -- Another label for how long this ball should take for each arc

    table.insert(self.ballsOut, ball) -- Insert the meatball into the ballsOut table after spawning it

    self.dx = (self.plate.x - ball.x)/4 -- Horizontal displacement from the window to the end of the arc
    self.vx = self.dx/t + 8 -- Use that and time to determine horizontal component of velocity

    -- Had to make a damn dynamic system for figuring out the gravity on the ball based off how long it stays in the air :lunasplat:
    -- This nearly killed me
    local dyi = (Game.battle.arena.top + 75) - ball.y -- Vertical displacement from the start until the peak of the arc
    local dyf = self.arcMin - (Game.battle.arena.top + 75) -- Vertical displacement from the peak of the arc to just above the Player Cat

    ball.g = 2 * (dyf / ((t/2) * (t/2))) -- Use the second vertical displacement and time to determine the needed acceleration on the ball
    ball.physics.gravity = ball.g * DT * DT -- Set the gravity on the ball to that acceleration and use DT^2 to convert from pixels/second^2 to pixels/frame^2

    local vyi = (dyi / (t/2)) - (0.5 * ball.g * (t/2)) -- Use first vertical displacement, time, and gravity to determine what initial velocity is needed for the top of the arc to be at the right coordinate

    ball:setSpeed(self.vx*DT, vyi*DT) -- Finally, after all that bullshit, set the initial horizontal and vertical velocity for the ball, using DT to convert from pixels/second to pixels/frame
end

---Shoots the ball back into the air with speed depending on how many times the ball has been bounced already
---@param bounces       integer How many times the ball has been bounced
---@param t       number How many seconds the arc should take
---@param g       number The gravity the ball needs
---@return number vy
function MeatballGame:getNeededVelocity(bounces, t, g)
    local dy = 0 -- Vertical displacement of from the bottom to the peak of the arc
    local vyi = 0 -- Initial vertical velocity needed for the top of the arc to be at the right coordinates

    if bounces == 0 then
        dy = (Game.battle.arena.top + 78) - self.arcMin
        vyi = (dy / (t/2)) - (0.5 * g * (t/2))
    elseif bounces == 1 then
        dy = (Game.battle.arena.top + 115) - self.arcMin
        vyi = (dy / (t/2)) - (0.5 * g * (t/2))
    elseif bounces == 2 then
        dy = (Game.battle.arena.top + 161) - self.arcMin
        vyi = (dy / (t/2)) - (0.5 * g * (t/2))
    end

    return (vyi*DT)
end

function MeatballGame:score()
    self.is_scoring = true

    self.can_move = false

    local msg = "" -- What message to dislpay
    local snd = "error" -- What sound effect to play

    -- All the different self.scores
    if self.failCount == 0 and Game:getFlag("soothed_ball", false) == true then
        msg = "Perfect"
        snd = "snd_perfect"
    elseif self.failCount <= 1 then
        msg = "Great"
        snd = "snd_great"
    elseif self.failCount == 2 then
        msg = "Okay"
        snd = "snd_good"
    else
        if Utils.random() > 0.25 then
            msg = "Bad"
        else
            msg = ":("
        end
        snd = "error"
    end

    self:scoreMessage(msg, self.plate.x, self.plate.y, -10, nil, 50)
    Assets.playSound(snd, 0.6, 1.2)

    self.timer:after(1, function ()
        self.finished = true
    end)
end

function MeatballGame:onEnd()
    local score = 0

    if self.failCount == 0 and Game:getFlag("soothed_ball", false) == true then
        score = 6
    elseif self.failCount <= 1 then
        score = 5
    elseif self.failCount == 2 then
        score = 3
    else
        score = 0
    end

    CustScore:addPoints(score)
    if score == 0 then
        Stepscript:backStep("meatballcatch")
        --[[ if Game.battle:getEnemyBattler("shoebert") then
            Stepscript:backStep("shoemeatballcatch")
        else
            Stepscript:backStep("meatballcatch")
        end ]]
    end

    -- For the Shoebert recipe
    if Game.battle:getEnemyBattler("shoebert") then
        Game:setFlag("footlong_type", "meatball")
    end
end

return MeatballGame