-- Code by Snrona and Mose!

local FootlongSliceGame, super = Class("LightMinigameWave")

function FootlongSliceGame:init()
    super.init(self, _s("minigame_popup-footlongslicegame", "    SLICE THAT    \n    HOAGIE ROLL!    "), "button")

    self.time = -1
    self.baseRange = 70
    self.perfectRange = 20

    self:setArenaPosition(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2)
    self:setArenaSize(500, 225)

    self.is_knife_usable = false

    self.siner = 0

    self.score = 0
end

function FootlongSliceGame:onStart()
    self.knife = self:spawnSprite("objects/footlonggames/knife", Game.battle.arena:getRight(), self.arena_y)
    self.knife:setLayer(BATTLE_LAYERS["soul"])
    self.knife:setScale(-2, 2)
    self.knife:setOrigin(1, 0.5)
    self.knife.alpha = 0

    self:knifeIntro() -- Move the knife into place

    self.bread = self:spawnSprite("objects/footlonggames/bread_alt", Game.battle.arena:getLeft() + 5, Game.battle.arena:getBottom() - 30)
    self.bread:setLayer(BATTLE_LAYERS["below_soul"])
    self.bread:setScale(4)
    self.bread:setOrigin(0, 0.5)
    self.bread_moving = true
    self.bread.has_split = false
    self.line = self:spawnObject(Sprite("objects/footlonggames/marker_line"))
    --self.line:setScale(2)
    --self.line:setLayer(BATTLE_LAYERS["soul"])
end

function FootlongSliceGame:update()
    super.update(self)

    if Input.pressed("confirm") and self.bread_moving and self.is_knife_usable then --and self.useTimer == 0
        self.useTimer = 3
        self:throw()
    end

    if self.bread_moving == true then
        self.siner = self.siner + (DT * DTMULT)
        self.bread.y = self.bread.y - (5.9 * math.sin(2.3 * self.siner))
    end

    local knife_in_bread_y = self.knife.y > self.bread.y - (self.bread.height * (self.bread.scale_y/2)) and self.knife.y < self.bread.y + (self.bread.height * (self.bread.scale_y/2))
    if self.knife.arrow then
        local desired_r = knife_in_bread_y and 0 or 1
        local desired_b = knife_in_bread_y and 0 or 1
        local color = self.knife.arrow.color
        if color[1] ~= desired_r or color[2] ~= 1 or color[3] ~= desired_b then
            if knife_in_bread_y then
                self.knife.arrow:setColor(0,1,0)
            else
                self.knife.arrow:setColor(1,1,1)
            end
        end
    end

    if knife_in_bread_y then
        if self.bread.x >= (self.knife.x - self.knife.width) and not self.bread.has_split then
            self.knife:shake(-4)
            self:splitBread(self.knife.y - self.bread.y)
        end
    end

    --self.line.x, self.line.y = self.bread.x, self.bread.y
end

function FootlongSliceGame:knifeIntro()
    self.timer:after(0.2, function ()
        self.timer:tween(0.8, self.knife, {x = self.arena_x + 40, alpha = 1}, "out-cubic", function ()
            self.knife.arrow = self:spawnObjectTo(self.knife, Sprite("objects/footlonggames/arrow", self.knife.width, 0))
            self.knife.arrow:setOrigin(1,0)
            self.knife.arrow:setScale(0.5)
            self.knife.arrow.alpha = 0

            self.timer:tween(0.5, self.knife.arrow, {x = self.knife.width + 8, alpha = 1}, "out-cubic", function ()
                self.is_knife_usable = true
            end)
        end)
    end)
end

function FootlongSliceGame:throw()
    Assets.playSound("heavyswing", 0.5, 1.1)

    self.bread_moving = false
    if self.knife.arrow then self.knife.arrow:fadeOutAndRemove(0.2) end

    self.bread:slideTo(SCREEN_WIDTH * 1.2, self.bread.y, 1, "out-quad", function()
        self:scoring(MathUtils.roundToMultiple(math.abs(self.knife.y - self.bread.y), 0.1))
        self.bread:remove()
        --self:respawn()
    end)
end

function FootlongSliceGame:scoring(diff)
    local msg = "blank" -- What message to dislpay
    local snd = "error" -- What sound effect to play

    -- All the different self.scores
    if diff > self.bread.height * (self.bread.scale_y/2) then
        if Utils.random() > 0.25 then
            msg = "Bad"
        else
            msg = ":("
        end
        snd = "error"
        self.score = 0
    elseif diff <= 8 then
        msg = "Perfect"
        snd = "snd_perfect"
        self.score = 5
    elseif diff <= 12 then
        msg = "Great"
        snd = "snd_great"
        self.score = 4
    elseif diff <= 16 then
        msg = "Okay"
        snd = "snd_good"
        self.score = 2
    else
        msg = "Okay"
        snd = "snd_good"
        self.score = 1
    end

    self:scoreMessage(msg)
    Assets.playSound(snd, 0.6, 1.2)

    self.timer:after(1, function ()
        self.finished = true
    end)
end

function FootlongSliceGame:splitBread(y_diff)
    Assets.playSound("laz_c", 0.4, 1.1)

    -- Make some crumbs
    self.timer:script(function (wait)
        for i=1, 5, 1 do
            local crumb = self:spawnObjectTo(self.knife, Sprite("objects/footlonggames/mask", self.knife.width * 0.75, 0))
            crumb.physics.gravity = 1
            crumb:setSpeed(math.random(-10,10), 0)
            self.timer:after(2, function ()
                crumb:remove()
            end)
            wait(0.01)
        end
    end)

    self.bread.has_split = true
    self.bread:setSprite("objects/footlonggames/bread_empty")

    local part_top = Sprite("objects/footlonggames/bread_alt", 0, 0)
    part_top:setParent(self.bread)

    -- Make a mask for the top half
    local mask_top = Sprite("objects/footlonggames/mask", 0, (part_top.height/2) + (y_diff/self.bread.scale_y))
    mask_top:setScale(part_top.width, -part_top.height)
    mask_top.visible = false
    part_top:addChild(mask_top)
    part_top:addFX(MaskFX(mask_top))

    local part_bot = Sprite("objects/footlonggames/bread_alt", 0, 0)
    part_bot:setParent(self.bread)

    -- Make a mask for the bottom half
    local mask_bot = Sprite("objects/footlonggames/mask", 0, (part_bot.height/2) + (y_diff/self.bread.scale_y))
    mask_bot:setScale(part_bot.width, part_bot.height)
    mask_bot.visible = false
    part_bot:addChild(mask_bot)
    part_bot:addFX(MaskFX(mask_bot))

    -- Send them flying at slightly different speeds
    part_top:setSpeed(0, -0.1)
    part_bot:setSpeed(0, 0.75)
end

--[[ function FootlongSliceGame:slice()
    self.knife_moving = false

    --self.knife:setSprite("objects/fruitfractiongame/knife_down")
    Assets.playSound("snd_chop_7")

    local text = self:spawnObject(Sprite("objects/fruitfractiongame/txt/blank"))
    text:setScale(1.66, 1.66)
    text:setOrigin(0.5, 0.5)
    text:setLayer(BATTLE_LAYERS["top"])
    text.x = Game.battle.soul.x
    text.y = Game.battle.soul.y

    --Game.battle.timer:tween(0.25, self.reticle, {scale_adder = 2, color = {0.5, 0.5, 0.5}}, "out-expo")

    if Utils.between(self.knife.y, self.bread.y - self.perfectRange, self.bread.y + self.perfectRange, true) == true then
        text:setSprite("objects/fruitfractiongame/txt/perfect")
        Assets.playSound("snd_perfect", 0.6, 1.2)
        CustScore:addPoints(5)
    elseif Utils.between(self.knife.y, self.bread.y - self.baseRange, self.bread.y + self.baseRange, true) == true then
        text:setSprite("objects/fruitfractiongame/txt/great")
        Assets.playSound("snd_great", 0.6, 1.2)
        CustScore:addPoints(3)
    else
        if Utils.random() > 0.5 then
            text:setSprite("objects/fruitfractiongame/txt/bad")
        else
            text:setSprite("objects/fruitfractiongame/txt/frown")
        end
        Assets.playSound("error", 0.6, 1.2)
        CustScore:addPoints(0)
    end
    text:slideTo(text.x + Utils.random(-100, 100, 10), text.y - 100, 1 / 3, "out-cubic", function()
        text:fadeOutAndRemove(0.5)
    end)
    Game.battle.timer:after(1, function() self:respawn() end)
    Game.battle.timer:after(0.9, function() self.knife_moving = true end)
end ]]

--[[ function FootlongSliceGame:respawn()
    Game.battle.timer:after(1, function()
        self.bread = self:spawnSprite("objects/footlonggames/bread_alt", Game.battle.arena:getLeft() + 5, Game.battle.arena:getBottom() - 30)
        --self.bread:setLayer(BATTLE_LAYERS["below_soul"])
        self.bread:setScale(4)
        self.bread:setOrigin(0, 0.5)
        self.is_knife_usable = true
        self.bread_moving = true
        self.siner = 0
        --self.knife:setSprite("objects/fruitfractiongame/knife")
        --Game.battle.timer:tween(0.25, self.reticle, {scale_adder = 1, color = {1, 1, 1}}, "out-expo")
    end)
end ]]

function FootlongSliceGame:onEnd()
    CustScore:addPoints(self.score)
    if self.score == 0 then
        Stepscript:backStep("breadslice")
    end
end

--[[ function FootlongSliceGame:draw()
    love.graphics.setColor(Utils.hexToRgb("#bfbfbf"))
    love.graphics.setLineWidth(1)
    if self.bread then
        love.graphics.line(Game.battle.arena:getLeft(), self.arena_y, self.arena_x + 24, self.arena_y)
    end
end ]]

return FootlongSliceGame
