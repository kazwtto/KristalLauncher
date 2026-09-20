-- Code by Mose!

local SurfingGame, super = Class("LightMinigameWave")

function SurfingGame:init()
    super.init(self, _s("minigame_popup-surfinggame", "   CATCH   \n   COINS!   "), "no_down_layout")

    -- I hate that I had to make an object for this
    Game.battle:addChild(MawzzSounder(TableUtils.pick({"mawzz_surf1", "mawzz_surf2"})))

    self.time = -1

    Game:setFlag("Results", "none")
    Game:setFlag("AddedMawzzGold", 0)

    self:setArenaSize(368, 250)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 - 10)

    self.countdown = 18 -- How long the minigame will last before scoring

    self.bal = 0 -- The balance of the surf board. Negative = Left, Positive = Right
    self.bal_min = -500
    self.bal_max = 500

    self.delta = 1 -- The amount to change the balance of the board by each frame

    self.pos = 0 -- The player's position relative to the board, for use in calculations

    self.can_move = true -- If the player can move (only gets set to false upon failure or completion)
    self.is_shaking = false -- If the board is already shaking

    self.coins = {} -- A table to hold all active coins
    self.coins_got = 0 -- How many coins the player has collected
    --self.coins_max = 20 -- How many coins you need to win

end

function SurfingGame:onStart()
    -- Make player heart
    self.heart = self:spawnObject(Sprite("player/heart_legs_surf"), self.arena_x + 1, self.arena_y)
    self.heart:setOrigin(0.5)
    self.heart:setScale(2)
    self.heart:setLayer(BATTLE_LAYERS["soul"])
    self.heart.speed = 2
    self.heart.is_jumping = false
    self.heart.collider = Hitbox(self.heart, 0, 0, self.heart.width, self.heart.height)

    -- Make surf board
    self.board = self:spawnObject(Sprite("objects/mawzz_games/surfinggame/board_3"), self.arena_x, self.arena_y)
    self.board:setOrigin(0.5,0)
    self.board:setScale(2)
    self.board:setLayer(BATTLE_LAYERS["below_soul"])
    self.board_left = self.board.x - self.board.width -- Left edge of the surfboard
    self.board_right = self.board.x + self.board.width -- Right edge of the surfboard

    -- Make wave
    self.bg = self:spawnObjectTo(Game.battle.arena.mask, Sprite("objects/mawzz_games/surfinggame/wave_alt", 0, 16))
    self.bg:setScale(2)
    self.bg:play(0.5)

--[[     -- Make coin counter
    local c_icon = self:spawnObject(Sprite("objects/mawzz_games/surfinggame/coin"), Game.battle.arena:getRight() - 128, Game.battle.arena:getTop() + 8)
    c_icon:setScale(2)
    self.coin_counter = self:spawnObject(Text("[font:main, 32][style:menu]: "..self.coins_got.." / "..self.coins_max), c_icon.x + (c_icon.width * c_icon.scale_x) + 4, c_icon.y - 3) ]]

    -- Make timer-counter-down-er
    self.countdown_text = self:spawnObject(Text(""), 0, Game.battle.arena:getTop() + 4)
    self.countdown_text.align = "center"
    self.countdown_text:setText("[font:Sunny, 48][style:menu][color:yellow]"..self.countdown)
    self.countdown_text:setLayer(BATTLE_LAYERS["top"])

    -- This handles the counting down
    self.timer:every(1 * DTMULT, function () -- Every second
        if self.can_move then -- If the play can move (hasn't failed)
            self.countdown = self.countdown - 1 -- Decrease the timer by 1

            if self.countdown > 10 then -- If above 10 seconds, set the text as yellow
                self.countdown_text:setText("[font:Sunny, 48][style:menu][color:yellow]"..self.countdown)
            elseif self.countdown > 5 then -- If above 5 seconds, set the text as orange
                self.countdown_text:setText("[font:Sunny, 48][style:menu][color:#ff8800]"..self.countdown)
            else -- If at or below 5 seconds, set the text as red and make it shake
                self.countdown_text:setText("[font:Sunny, 48][style:menu][color:red]"..self.countdown)
                self.countdown_text:shake()
            end

            if self.countdown <= 0 and not self.is_scoring then -- If the countdown has reached 0, and if not already scoring, then score the player
                self:score()
            end
        else -- If the player can't move (has failed), then fade out the countdown
            self.countdown_text:fadeOutAndRemove(0.8)
        end
    end)

    self:spawnCoins()
end

function SurfingGame:update()
    super.update(self)

    if self.can_move then
        self:move()
        self:tiltBoard()
    end

    self.pos = self.heart.x - self.board.x -- Get the player's position relative to the board

    -- The delta is porportional to the natural log of the heart's position
    -- All of the hard-coded numbers were determined through Desmos to make a graph that I liked (0.00823 is so that y=0 when x=0, 63 makes the max delta value ~= 63)
    -- The function is: ln(x - 0.00823) + 63, where x = self.pos/10
    local d = 0
    if self.pos > 0 then
        d = math.log(math.exp(1), (self.pos/10) + -0.00823) + 63
    elseif self.pos < 0 then -- Need to make x negative if the position is negative
        d = math.log(math.exp(1), -(self.pos/10) + -0.00823) + 63
        d = d * -1
    end
    self.delta = MathUtils.roundToMultiple(d * 0.25, 0.1)

    if self.bal + self.delta > self.bal_min and self.bal + self.delta < self.bal_max then -- If the balance is within the bounds
        self.bal = self.bal + self.delta -- Update the balance of the board
    end

    for i, c in ipairs(self.coins) do -- Check the Coins table
        if self.heart.collider:collidesWith(c.collider) then -- If the heart collides with a coin
            self.coins_got = self.coins_got + 1 -- Increment coin tracker
            Assets.playSound("snd_ding", 0.5, 1.2) -- Play a sound
            c:remove() -- Remove the coin
            table.remove(self.coins, i) -- and remove it from the Coin table 
        end

        if c.x > Game.battle.arena.width or c.y > Game.battle.arena.height then -- If a coin has gone out of bounds, remove it
            c:remove()
            table.remove(self.coins, i)
        end
    end
end

-- Send the player and the surfboard flying in different directions, and end the minigame after a delay
function SurfingGame:fling()
    self.can_move = false

    local sign = MathUtils.sign(self.pos)

    self.board.physics.gravity = 1
    self.board:setSpeed(-10 * sign,-5)
    self.board.graphics.spin = -0.15 * sign

    self.heart.physics.gravity = 1
    self.heart:setSpeed(10 * sign,-20)
    self.heart.graphics.spin = 0.15 * sign

    self.board:setSprite("objects/mawzz_games/surfinggame/board_3")
    self.heart:setSprite("player/heart_legs_2")

    Assets.playSound("awkward", 0.75, 0.9)

    self.timer:after(2, function ()
        self:score()
    end)
end

-- Code for player movement
function SurfingGame:move()
    local moving_left = Input.down("left") and self.heart.x > self.board_left
    local moving_right = Input.down("right") and self.heart.x < self.board_right

    if moving_left or moving_right then
        if not self.heart.playing then
            if not self.heart:isSprite("player/heart_legs_surf") then
                self.heart:setSprite("player/heart_legs_surf")
            end
            self.heart:play(0.2, true)
        end

        if moving_left then
            self.heart:setSpeed(-self.heart.speed, self.heart.physics.speed_y)
        else
            self.heart:setSpeed(self.heart.speed, self.heart.physics.speed_y)
        end
    else
        self.heart:setSpeed(0, self.heart.physics.speed_y)
        if self.heart.playing then
            self.heart:stop()
        end
        if not self.heart:isSprite("player/heart_legs_surf_2") then
            self.heart:setSprite("player/heart_legs_surf_2")
        end
    end

    if (Input.pressed("confirm", false) or Input.pressed("up", false)) and not self.heart.is_jumping then
        self.heart.is_jumping = true
        self.heart.y = self.board.y - 1
        self.heart.physics.gravity = 1
        self.heart.physics.speed_y = -14

        Assets.playSound("snd_bottlebloop", 0.7, 1.1)
    end

    if (Input.released("confirm") or Input.released("up")) and self.heart.physics.speed_y < -4 then
        self.heart.physics.speed_y = -4
    end

    if self.heart.is_jumping and self.heart.y >= self.board.y then
        self.heart.is_jumping = false
        self.heart.physics.gravity = 0
        self.heart:setSpeed(self.heart.physics.speed_x, 0)
    end
end

function SurfingGame:score()
    self.is_scoring = true

    self.can_move = false

    if self.heart.is_jumping then -- If the player is jumping
        self.heart.physics.gravity = 0 -- Set their gravity to zero
        self.heart:setSpeed(0) -- Set their speed to zero
        self.heart:slideTo(self.heart.x, self.board.y, 0.5, "in-quad") -- And slide them back to the baord
    else -- Otherwise, just set speed to zero
        self.heart:setSpeed(0)
    end

    -- Create object for status text
    local text = self:spawnObject(Sprite("ui/battle/scoremsg/blank"), self.arena_x, self.arena_y)
    text:setScale(1)
    text:setOrigin(0.5)
    text:setLayer(BATTLE_LAYERS["top"])

    local msg = "blank" -- What message to dislpay
    local snd = "error" -- What sound effect to play
    local clr = "white"

    -- All the different self.scores
    if self.coins_got >= 30 then
        msg = "perfect"
        snd = "snd_perfect"
        clr = "yellow"
    elseif self.coins_got >= 15 then
        msg = "great"
        snd = "snd_great"
        clr = "green"
    else
        msg = "okay"
        snd = "snd_good"
        clr = "white"
    end

    if self.state == "GAMEOVER" then
        if MathUtils.random() > 0.25 then
            msg = "bad"
        else
            msg = "frown"
        end
        snd = "error"
        clr = "red"
    end

    -- Set text to appropriate message and play corresponding sound
    text:setSprite("ui/battle/scoremsg/"..msg)
    Assets.playSound(snd, 0.6, 1.2)
    local gold_got = self.coins_got * 3
    local coin = self:spawnObjectTo(text, Text("[font:main, 32][style:menu][color:"..clr.."] +"..gold_got.."G", text.width/8, text.height + 2))
    Game:addFlag("MawzzGoldEarned", gold_got)
    Game.lw_money = Game.lw_money + math.floor(gold_got/5) -- These were previously tied to coins_got, but I think that may have been a mistake, since you would only get refunded like 5 gold lmao
    Game:setFlag("MawzzBonus", math.floor(gold_got/5))

    -- Slide the text away and fade it out
    text:slideTo(text.x + MathUtils.random(-100, 100, 10), text.y - 50, 1/3, "out-cubic", function()
        text:fadeOutAndRemove(0.5)
        coin:fadeOutAndRemove(0.5)
    end)

    self.timer:after(1, function ()
        self.finished = true
    end)
end

-- Make the surf board shake when it has been at an extreme balance, if it shakes too long, fling the player
function SurfingGame:shakeBoard()
    self.is_shaking = true
    local t = 0

    Assets.playSound("rumble", 0.25, 1.4)

    self.timer:script(function (wait)
        while self.is_shaking and self.can_move do
            t = t + (DT * DTMULT)
            self.board:shake(TableUtils.pick({-t,t})/4, TableUtils.pick({-t,t})/4)

            if t >= 1.5 then
                self.is_shaking = false
                self:fling()
            end

            wait(DT * DTMULT)
        end
    end)
end

-- Spawns coins at slightly random intervals, sends them flying in a slightly random arc over the player
function SurfingGame:spawnCoins()
    self.timer:everyInstant(0.5, function () -- Every second, until the end of the wave
        self.timer:after(math.random() * 1.5, function () -- Wait an extra 0-2 seconds
            if self.can_move then -- If the player can move (aka: if the minigame isn't over)
        
                local coin = self:spawnObjectTo(Game.battle.arena.mask, Sprite("objects/mawzz_games/surfinggame/coin", 0, 0))
                coin:setScale(2)
                coin:setLayer(BATTLE_LAYERS["bullets"])

                coin.x = coin.width * coin.scale_x * -1 -- Just to the left of the arena
                coin.y = Game.battle.arena.height/3 + (math.random() * Game.battle.arena.height/3) -- TEMPORARY spawn in the middle

                coin.collider = Hitbox(coin, coin.width/4, coin.height/4, coin.width/2, coin.height/2) -- Give the coin a hitbox

                -- PHYSICS TIME BABY
                local t = 2 --+ math.random() -- The amount of time it takes to cross the arena is a random value between 1 and 2

                local vx = (Game.battle.arena.width / t) -- Find the x-velocity needed to cross the arena in that time (vx = dx/t)
                vx = ((2/3) * vx) + (math.random() * ((2/3) * vx))

                local dy = -coin.y + math.random(0,50)
                local g = 2 * (-dy / ((t/2) * (t/2)))
                coin.physics.gravity = g * DT * DT

                local vy = (dy / (t/2)) - (0.5 * g * (t/2))

                coin:setSpeed(vx * DT, vy * DT)

                coin:play(0.0008 * vx)
                coin:setFrame(math.random(1,4))

                table.insert(self.coins, coin)

            end
        end)
    end)
end

-- Updates the surf board's sprite and the players position to represent the balance of the board
function SurfingGame:tiltBoard()
    if self.bal >= self.bal_max - 20 or self.bal <= self.bal_min + 20 then -- The 20s account for bal being stopped before it reaches max or min
        if not self.is_shaking and self.can_move then
            self:shakeBoard()
        end
    else
        self.is_shaking = false
    end

    if not self.heart.is_jumping then
        local board_sprite
        local heart_offset
        if self.bal > 250 then
            board_sprite = "objects/mawzz_games/surfinggame/board_5"
            heart_offset = 4
        elseif self.bal > 50 then
            board_sprite = "objects/mawzz_games/surfinggame/board_4"
            heart_offset = 2
        elseif self.bal < -250 then
            board_sprite = "objects/mawzz_games/surfinggame/board_1"
            heart_offset = 4
        elseif self.bal < -50 then
            board_sprite = "objects/mawzz_games/surfinggame/board_2"
            heart_offset = 2
        else
            board_sprite = "objects/mawzz_games/surfinggame/board_3"
            heart_offset = 0
        end

        if not self.board:isSprite(board_sprite) then
            self.board:setSprite(board_sprite)
        end
        self.heart.y = self.board.y + heart_offset
    end
end

function SurfingGame:onEnd()
    
    Game:setFlag("CurrentMinigame", "surf")
    Stepscript:backStep("surfing")
end

return SurfingGame
