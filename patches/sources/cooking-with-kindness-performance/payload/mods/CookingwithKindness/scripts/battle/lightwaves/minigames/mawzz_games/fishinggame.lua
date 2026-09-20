-- Code by Mose!

local FishingGame, super = Class("LightMinigameWave")

function FishingGame:init()
    super.init(self, _s("minigame_popup-fishinggame", "FISH UP\nTREASURE!"), "button")

    -- I hate that I had to make an object for this
    Game.battle:addChild(MawzzSounder("mawzz_fishuptreasure"))
    
    self.time = -1

    Game:setFlag("Results", "none")

    self:setArenaSize(202, 316)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 - 10)

    self.start_y = 26
    self.can_move = true

    self.fishes = {}
    self.bubbles = {}

    self.state = "PRE-CAST"

end

function FishingGame:onStart()
    -- Make background
    self.map = self:spawnObjectTo(Game.battle.arena.mask, Sprite("objects/mawzz_games/fishinggame/bg", 0, 4))
    self.map:setScale(2)
    self.map:setLayer(BATTLE_LAYERS["arena"])

    -- Make waves
    local waves = self:spawnObjectTo(self.map, Sprite("objects/mawzz_games/fishinggame/waves"))
    waves:setLayer(BATTLE_LAYERS["above_bullets"])

    -- Make player hook
    self.hook = self:spawnObjectTo(self.map, Sprite("objects/mawzz_games/fishinggame/hook", 50, self.start_y))
    self.hook:setOrigin(0.5)
    self.hook:setLayer(BATTLE_LAYERS["bullets"])
    self.hook.speed = 2
    self.hook.collider = Hitbox(self.hook, 0, 0, self.hook.width, self.hook.height)

    -- Make top fish
    self.fish_a = self:spawnObjectTo(self.map, Sprite("objects/mawzz_games/fishinggame/fish_a", 2, 64))
    self.fish_a:setLayer(BATTLE_LAYERS["soul"])
    self.fish_a:setOrigin(0.5, 0)
    self.fish_a:play(0.45)
    self.fish_a.speed = 1
    self.fish_a.dir = 1
    self.fish_a.collider = Hitbox(self.fish_a, 2, 2, self.fish_a.width - 4, self.fish_a.height - 4)
    self.fish_a.hooked = false
    table.insert(self.fishes, self.fish_a)

    -- Make middle fish
    self.fish_b = self:spawnObjectTo(self.map, Sprite("objects/mawzz_games/fishinggame/fish_b", 81, 92))
    self.fish_b:setLayer(BATTLE_LAYERS["soul"])
    self.fish_b:setOrigin(0.5, 0)
    self.fish_b:play(0.49)
    self.fish_b.speed = 1.25
    self.fish_b.dir = -1
    self.fish_b.collider = Hitbox(self.fish_b, 2, 2, self.fish_b.width - 4, self.fish_b.height - 4)
    self.fish_b.hooked = false
    table.insert(self.fishes, self.fish_b)

    -- Make shark
    self.shark = self:spawnObjectTo(self.map, Sprite("objects/mawzz_games/fishinggame/shark"), 6, 114)
    self.shark:setLayer(BATTLE_LAYERS["bullets"])
    self.shark:setOrigin(0.5, 0)
    self.shark:play(0.43)
    self.shark.speed = 0.75
    self.shark.dir = 1
    self.shark.collider = Hitbox(self.shark, 2, 2, self.shark.width - 4, self.shark.height - 4)
    table.insert(self.fishes, self.shark)

    -- Make chest
    self.chest = self:spawnObjectTo(self.map, Sprite("objects/mawzz_games/fishinggame/chest_floor", 46, 140))
    self.chest:setLayer(BATTLE_LAYERS["soul"])
    self.chest.collider = Hitbox(self.chest, 0, 0, self.chest.width, self.chest.height)

    -- Spawn bubbles, and also move existing ones a smidge
    local counter = 8
    self.timer:everyInstant(0.5, function ()
        for _, b in ipairs(self.bubbles) do
            b.x = b.x + math.random(-1,1)
        end

        if counter == 8 then
            counter = 0
            self.timer:after(math.random(0,3), function ()
                if math.random() > 0.5 then
                    self:spawnBigBubble()
                else
                    self:spawnSmallBubbles()
                end
            end)
        end

        counter = counter + 1
    end)
end

function FishingGame:update()
    super.update(self)

    if self.can_move and Input.pressed("confirm", false) then
        if self.state == "PRE-CAST" then
            self.state = "CASTING"
            Assets.playSound("noise", 0.5)
        elseif self.state == "PRE-REEL" then
            self.state = "REELING"
            Assets.playSound("noise", 0.5)
        end
    end

    if self.state == "CASTING" then
        self:cast()
    elseif self.state == "REELING" then
        self:reel()
    end

    self:moveBubbles()
    self:moveFishes()
end

function FishingGame:cast()
    self.hook.y = self.hook.y + self.hook.speed * DTMULT

    for i, f in ipairs(self.fishes) do
        if self.hook.collider:collidesWith(f.collider) then
            if f == self.shark then
                self:snapLine()
            else
                self:hookItem(f, true, i)
            end
        end
    end

    if self.hook.collider:collidesWith(self.chest.collider) then
        self:hookItem(self.chest)
    end
end

function FishingGame:hookItem(item, is_fish, index)
    self.state = "PRE-REEL"

    self.hook.y = self.hook.y + self.hook.speed * 2

    Assets.playSound("bell_bounce_short", 0.5)

    self.item_caught = item
    item.hooked = true
    item:setParent(self.hook)
    item.x, item.y = 0, 4
    item:shake()
    item:stop()

    local text = self:spawnObjectTo(self.hook, Text("[font:main,8]REEL IT IN!"))
    text.rotation = math.rad(20)
    self.timer:tween(1, text, {x = text.x + 6, y = text.y - 6}, "out-cubic")
    self.timer:after(0.5, function ()
        text:fadeOutAndRemove(0.5)
    end)

    if is_fish then table.remove(self.fishes, index) end
end

function FishingGame:move()
    if Input.down("up") and self.hook.y > 0 then
        self.hook.y = self.hook.y - self.hook.speed * DTMULT
    end
    if Input.down("down") and self.hook.y < self.map.height then
        self.hook.y = self.hook.y + self.hook.speed * DTMULT
    end
end

function FishingGame:moveBubbles()
    local bubble_write = 1
    for bubble_read = 1, #self.bubbles do
        local bubble = self.bubbles[bubble_read]
        if bubble.parent then
            self.bubbles[bubble_write] = bubble
            bubble_write = bubble_write + 1
        end
    end
    for i = #self.bubbles, bubble_write, -1 do
        self.bubbles[i] = nil
    end

    for _, b in ipairs(self.bubbles) do
        b.y = b.y - 0.5

        if b.y < 75 then
            b:fadeOutAndRemove(0.5)
        end
    end
end

function FishingGame:moveFishes()
    for _, f in ipairs(self.fishes) do
        if not f.hooked then
            f.x = f.x + (f.speed * f.dir * DTMULT)

            if f.dir == 1 and f.x > self.map.width - 5 then
                f.dir = f.dir * -1
                f:setScale(f.scale_x * -1, 1)
            elseif f.dir == -1 and f.x < 5 then
                f.dir = f.dir * -1
                f:setScale(f.scale_x * -1, 1)
            end
        end
    end
end

function FishingGame:reel()
    self.hook.y = self.hook.y - self.hook.speed * DTMULT

    if self.hook.y == 42 then
        Assets.playSound("splash", 0.75, 0.9)
    end

    for _, f in ipairs(self.fishes) do
        if self.hook.collider:collidesWith(f.collider) then
            self:snapLine()
        end
    end

    if self.hook.y == self.start_y then
       self.state = "SCORING" 
       self:score()
    end
end

function FishingGame:snapLine()
    self.state = "GAMEOVER"

    self.hook:shake()

    self.timer:tween(4, self.hook, {y = self.hook.y + 50, rotation = self.hook.rotation + 1}, "linear")

    self:score()
end

function FishingGame:spawnBigBubble()
    local bubble = self:spawnObjectTo(self.map, Sprite("objects/mawzz_games/fishinggame/bubble_1", 64, 152))
    bubble.x = bubble.x + math.random(0, 20)
    bubble:setOrigin(0.5)
    bubble:setScale(TableUtils.pick({-1, 1}), 1)
    table.insert(self.bubbles, bubble)
end

function FishingGame:spawnSmallBubbles()
    self.timer:script(function (wait)
        local start = 8 + math.random(0,32)
        for i=1, 3 do
            local bubble = self:spawnObjectTo(self.map, Sprite("objects/mawzz_games/fishinggame/bubble_2", start, 152))
            bubble.x = bubble.x + math.random(-4,4)
            bubble:setOrigin(0.5)
            table.insert(self.bubbles, bubble)
            wait(0.5)
        end
    end)
end

function FishingGame:score()
    -- Create object for status text
    local text = self:spawnObject(Sprite("ui/battle/scoremsg/blank"), self.map:localToScreenPos(self.hook.x, self.hook.y))
    text:setScale(1.66)
    text:setOrigin(0.5)
    text:setLayer(BATTLE_LAYERS["top"])

    local msg = "blank" -- What message to dislpay
    local snd = "error" -- What sound effect to play

    -- All the different self.scores
    if self.item_caught == self.chest then
        msg = "perfect"
        snd = "snd_perfect"
    elseif self.item_caught == self.fish_b then
        msg = "great"
        snd = "snd_great"
    elseif self.item_caught == self.fish_a then
        msg = "okay"
        snd = "snd_good"
    end

    if self.state == "GAMEOVER" then
        if MathUtils.random() > 0.25 then
            msg = "bad"
        else
            msg = "frown"
        end
        snd = "error"
    end

    -- Set text to appropriate message and play corresponding sound
    text:setSprite("ui/battle/scoremsg/"..msg)
    Assets.playSound(snd, 0.6, 1.2)

    local res = "none"
    local G = 0
    local clr = "white"

    if self.item_caught == self.chest then
        res = "chest"
        G = 50
        clr = "yellow"
    elseif self.item_caught == self.fish_b then
        res = "big_fish"
        G = 20
        clr = "green"
    elseif self.item_caught == self.fish_a then
        res = "normal_fish"
        G = 10
        clr = "white"
    end

    if self.state == "GAMEOVER" then
        res = "game_over"
        clr = "red"
        G = 0
    end

    G = G*2

    Game:setFlag("Results", res)
    Game:setFlag("CurrentMinigame", "fishing")
    Game:addFlag("MawzzGoldEarned", G)
    Game.lw_money = Game.lw_money + math.floor(G/5)
    Game:setFlag("MawzzBonus", math.floor(G/5))

    local coin = self:spawnObjectTo(text, Text("[font:main, 32][style:menu][color:"..clr.."] +"..G.."G", text.width/8, 0 - 2 - 32))
    -- Slide the text away and fade it out
    text:slideTo(text.x + MathUtils.random(-100, 100, 10), text.y - 50, 1/3, "out-cubic", function()
        text:fadeOutAndRemove(0.5)
        coin:fadeOutAndRemove(0.5)
    end)

    self.timer:after(1, function ()
        self.finished = true
    end)
end

function FishingGame:onEnd()
    Stepscript:backStep("fishing")
end

function FishingGame:draw()
    if self.hook and self.state ~= "GAMEOVER" then
        local _, map_y = Game.battle.arena:localToScreenPos(self.map.x, self.map.y)
        local hook_x, hook_y = self.map:localToScreenPos(self.hook.x, self.hook.y)

        local x_1, y_1 = self.arena_x, map_y + 28
        local x_2, y_2 = hook_x + 1, hook_y - 10

        love.graphics.setLineWidth(2)
        love.graphics.setColor(1,1,1)
        love.graphics.line(x_1, y_1, x_2, y_2)
    end
end

return FishingGame