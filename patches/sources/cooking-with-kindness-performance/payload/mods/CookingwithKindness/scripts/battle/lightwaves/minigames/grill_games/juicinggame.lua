-- Code written by Holton

local JuicingGame, super = Class("LightMinigameWave")



function JuicingGame:init()
    super.init(self, _s("minigame_popup-juicinggame", "JUICE!"), "button")

    Game:setFlag("Results", "none")

    self.time = -1

    self:setArenaSize(200,300)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 10)

    self:setSoulPosition(10000,10000)

    self.squeezable = true

    self.is_shaking = false

    self._cwk_fruit_sprites = {
        "objects/juicinggame/fruit_1",
        "objects/juicinggame/fruit_2",
        "objects/juicinggame/fruit_3",
        "objects/juicinggame/fruit_4"
    }
end

function JuicingGame:onStart()
    self.center_x, self.center_y = Game.battle.arena:getCenter()

    -- Create fruit
    self.fruit = self:spawnObject(Sprite("objects/juicinggame/fruit_1"), self.center_x, Game.battle.arena:getTop() + 100)
    self.fruit:setOrigin(0.5, 1)
    self.fruit:setScale(3)
    self.fruit:setLayer(BATTLE_LAYERS["soul"])
    self.fruit.state = 1
    -- Create cup
    self.cup = self:spawnObject(Sprite("objects/juicinggame/cup_1"), self.center_x, Game.battle.arena:getBottom() - 18)
    self.cup:setOrigin(0.5, 1)
    self.cup:setScale(4)
    self.cup:setLayer(BATTLE_LAYERS["soul"])
    self.cup.adj_height = self.cup.scale_y * self.cup.height
    -- Create flow
    self.flow = self:spawnObject(Sprite("objects/juicinggame/flow"), self.center_x, self.fruit.y - 10)
    self.flow:setOrigin(0.5, 0)
    self.flow:setScale(4)
    self.flow:setLayer(self.cup.layer - 2)
    self.flow:play(0.25, true)
    self.flow.visible = false
    -- Create juice
    self.juice = self:spawnObject(Sprite("objects/juicinggame/juice"), self.center_x, self.cup.y)
    self.juice:setOrigin(0.5, 1)
    self.juice:setScale(self.cup.width * self.cup.scale_x, 0)
    self.juice:setLayer(self.cup.layer - 1)
end

function JuicingGame:update()
    super.update(self)

    if self.squeezable == true then
        self:squeeze()
    end
end

function JuicingGame:squeeze()
    -- Make fruit appear to be squeezed and begin to fill the glass with juice
    if Input.down("confirm") then
        self.flow.visible = true
        local squeezed_sprite = self._cwk_fruit_sprites[self.fruit.state + 1]
        if not self.fruit:isSprite(squeezed_sprite) then
            self.fruit:setSprite(squeezed_sprite)
        end
        self.juice.scale_y = self.juice.scale_y + 0.5

        -- Increment fruit state for each third of the glass filled with juice
        if self.juice.scale_y == self.cup.adj_height / 3 or self.juice.scale_y == (self.cup.adj_height / 3) * 2 then
            self.fruit.state = self.fruit.state + 1
            Assets.playSound("noise", 0.6)
            local fruit_sprite = self._cwk_fruit_sprites[self.fruit.state]
            if not self.fruit:isSprite(fruit_sprite) then
                self.fruit:setSprite(fruit_sprite)
            end
        elseif self.juice.scale_y == self.cup.adj_height then
            self:scoring()
        end

        -- Shake fruit when nearing the end of the game
        if self.fruit.state == 3 and self.is_shaking == false then
            self:fruitShake()
        end
    else
        self.flow.visible = false
        local fruit_sprite = self._cwk_fruit_sprites[self.fruit.state]
        if not self.fruit:isSprite(fruit_sprite) then
            self.fruit:setSprite(fruit_sprite)
        end
    end  

    if Input.pressed("confirm", false) then
        Assets.playSound("noise", 0.6)
    end

end

function JuicingGame:fruitShake()
    self.is_shaking = true
    self.timer:everyInstant(0.1, function ()
        self.fruit:shake(1, 0)
        if not self.squeezable then
            return false
        end
    end)
end

function JuicingGame:scoring()   
    self.squeezable = false 

    self.flow:remove()

    self.fruit:setRotationOrigin(0.5)
    self.fruit.physics.gravity = 1
    self.fruit:setSpeed(-15, -20)
    self.fruit.graphics.spin = -0.5

    self:scoreMessage("Nice Squeeze!", nil, nil, nil, nil, nil, nil, SCORECOLORS.yellow)
    Assets.playSound("snd_perfect", 0.6, 1.2)

    self.timer:after(1, function () -- End the wave
        self.finished = true
    end)
end

function JuicingGame:onEnd()
    Game:setFlag("Results", "drink")
end

return JuicingGame