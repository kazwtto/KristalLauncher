local FinalMawzzWave, super = Class("LightMinigameWave")

function FinalMawzzWave:init()
    super.init(self, _s("minigame_popup-final_wave", "GWAH HA HA!"), "horiz_layout",false)

    -- I hate that I had to make an object for this
    Game.battle:addChild(MawzzSounder("mawzz_finalwavelaugh"))

    self.time = -1

    Game:setFlag("Results", "none")
    self:setArenaSize(330, 300)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 - 10)

    self.total_needed = 99999 - Game:getFlag("MawzzGoldEarned",0) --Total G needed to win
    self.coin_amount = 219 --Amount of coins at the end

    self.base_value = math.floor(self.total_needed/self.coin_amount)
    self.coin_remainder = self.total_needed%self.coin_amount

    self.coins_collected = 0

    self.reached_top = false
    self.sliding = false

    self.in_water = true
    self.water_force = 0.6
    self.swim_power = -6
    self.movement_speed = 3

    self.grabbed_treasure = false
    self.spawned_shark = false
    self.coins_spawned = false

    self.warn_sound = Assets.newSound("snd_warn")

    self.whirlpools = {}

    self.seaweeds = {}

    self.hazards = {} --Things that kill you

    self.warning_signs = {}

    self.coin_stacks = {}

    self.bubbles = {}

    self.currently_warning = false

    --Water shader
    self.siner = 0
    self.water_shader = love.graphics.newShader([[
        extern float time; // seconds
        extern vec2 texture_dim;
        extern vec2 do_dim = vec2(1, 0);
        extern int thickness = 1;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
            vec2 chunk = vec2(floor(texture_coords.x * texture_dim.x / thickness) * thickness, floor(texture_coords.y * texture_dim.y / thickness) * thickness);
            if (do_dim.x > 0.0)
                texture_coords.x += sin(time + chunk.x / 30.0) * 2.0 / texture_dim.x;
            if (do_dim.y > 0.0)
                texture_coords.y += sin(time + chunk.y / 30.0) * 2.0 / texture_dim.y;
            return Texel(tex, texture_coords) * color;
        }
    ]])
    self.water_shader:send("texture_dim", {163, 150})
    self._cwk_water_line = Assets.getTexture("objects/mawzz_games/finalwave/top_waterline")

    -- Timeline system
    self.wave_timer = 0
    self.phase = 1

    self.timeline = {

    -- Phase 2 start (4s)
    {time = 4, action = function(self)
        

    end},

    -- Phase 3 start (10s)
    {time = 10, action = function(self)

        --Create coroutine for phase 3 (idk seemed easier than stacking timers its all on a strict schedule here)
        local co = coroutine.create(function()
            coroutine.yield(3)
            --457, 180
            local warning = self:makeWarning(457,self.soul.y)
            self.warn_sound:play()
            self.warn_sound:setLooping(true)
            self.currently_warning = true
            coroutine.yield(1)
            self.currently_warning = false
            self.warn_sound:setLooping(false)

            coroutine.yield(0.3)
            local hoarde = self:addChild(SharkHoarde(447, warning.y-10,"right"))
            warning:remove()

            coroutine.yield(1)
            local warning = self:makeWarning(180,self.soul.y)
            self.warn_sound:play()
            self.warn_sound:setLooping(true)
            self.currently_warning = true

            coroutine.yield(1)
            self.currently_warning = false
            self.warn_sound:setLooping(false)

            coroutine.yield(0.3)
            local hoarde = self:addChild(SharkHoarde(90, warning.y-10,"left"))
            hoarde:setOrigin(1,0)
            warning:remove()

            coroutine.yield(1)
            local warning = self:makeWarning(457,105)
            self.warn_sound:play()
            self.warn_sound:setLooping(true)

            coroutine.yield(0.2)
            self.warn_sound:setLooping(false)

            coroutine.yield(0.3)
            local warning2 = self:makeWarning(180,190)
            self.warn_sound:play()
            self.warn_sound:setLooping(true)

            coroutine.yield(0.2)
            self.warn_sound:setLooping(false)

            coroutine.yield(0.3)
            local warning3 = self:makeWarning(457,235)
            self.warn_sound:play()
            self.warn_sound:setLooping(true)

            coroutine.yield(0.4)
            self.warn_sound:setLooping(false)

            coroutine.yield(0.2)
            warning:remove()
            warning2:remove()
            warning3:remove()

            coroutine.yield(0.2)
            local hoarde = self:addChild(SharkHoarde(447,95,"right"))

            coroutine.yield(0.6)
            local hoarde = self:addChild(SharkHoarde(90,180,"left"))
            hoarde:setOrigin(1,0)

            coroutine.yield(0.6)
            local hoarde = self:addChild(SharkHoarde(447,225,"right"))

            coroutine.yield(1.2)
            local warning1 = self:makeWarning(457,105)
            local warning2 = self:makeWarning(180,151)
            self.warn_sound:play()
            self.warn_sound:setLooping(true)

            coroutine.yield(0.75)
            warning1:remove()
            warning2:remove()
            self.warn_sound:setLooping(false)

            coroutine.yield(0.25)
            local hoarde1 = self:addChild(SharkHoarde(447,95,"right"))
            local hoarde2 = self:addChild(SharkHoarde(90,141,"left"))
            hoarde2:setOrigin(1,0)

            coroutine.yield(1)
            local warning1 = self:makeWarning(180,105)
            local warning2 = self:makeWarning(457,235)
            self.warn_sound:play()
            self.warn_sound:setLooping(true)

            coroutine.yield(0.75)
            warning1:remove()
            warning2:remove()
            self.warn_sound:setLooping(false)

            coroutine.yield(0.25)
            local hoarde2 = self:addChild(SharkHoarde(170, 95,"left"))
            local hoarde1 = self:addChild(SharkHoarde(447,225,"right"))
            hoarde2:setOrigin(1,0)

            coroutine.yield(2)
            self.walls.finished = true
            self.walls:addTop()
        end)

        --Function to resume coroutine
        local function startCo()
            if co and coroutine.status(co) ~= "dead" then
                local ok, waitTime = coroutine.resume(co)
                if ok and waitTime then
                    self.timer:after(waitTime, startCo)
                end
            end
        end

        -- Start the coroutine
        startCo()
    end},
}
end

function FinalMawzzWave:onStart()

    --Player soul
    
    self.soul = self:spawnObject(Soul(), 320, 240)
    self.soul:setColor(0,1,0)
    self.soul.sprite:setSprite("player/heart")
    self.soul.noclip = false
    self.soul.can_move = false
    self.soul.paused = false
    self.soul.slope_correction = true
    self.soul.physics.gravity = self.water_force
    
    --Shark. His name is, once again, Tommy
    --self.shark = self:addChild(FinalWaveShark(175,186))
    --self.shark:setParent(Game.battle.arena.mask)

    --Walls
    self.walls = self:addChild(FinalWaveWalls(0,0))
    self.walls:setParent(Game.battle.arena.mask)

    --Treasure
    self.treasure = self:addChild(Treasure(Game.battle.arena.left+150,Game.battle.arena.bottom-44))

    for i = 1,2 do
        self.seaweed = self:addChild(Sprite("objects/mawzz_games/finalwave/seaweed",17+200*i,269))
        self.seaweed:setScale(2)
        self.seaweed:play(0.25)
        table.insert(self.seaweeds,self.seaweed)
    end
    
    --50/50 coin flip to spawn a bubble every second
    self.timer:everyInstant(1, function()
        if self.in_water then
            if love.math.random(1,2) == 1 then 
                local bubble = self:spawnBubble() 
                table.insert(self.bubbles,bubble)
            end
        end
    end)
end

function FinalMawzzWave:update()
    super.update(self)

    self:handleMovement()

    local bubble_write = 1
    for bubble_read = 1, #self.bubbles do
        local b = self.bubbles[bubble_read]
        local remove_bubble = not b.parent
        if not remove_bubble then
            if self.walls.finished then
                remove_bubble = b.y < 180
            else
                remove_bubble = b.y < Game.battle.arena.top
            end
        end
        if remove_bubble then
            if b.parent then b:remove() end
        else
            self.bubbles[bubble_write] = b
            bubble_write = bubble_write + 1
        end
    end
    for i = #self.bubbles, bubble_write, -1 do
        self.bubbles[i] = nil
    end
    
    if self.reached_top then
        if self.shark then
            self.shark.state = "paused"
        end
    end

    if self.soul.paused == false and self.spawned_shark == true then
        self:updateTimeline()
    end
    
    if self.soul:collidesWith(self.treasure) and not self.grabbed_treasure then
        self:grabTreasure()
    end

    if self.walls.finished == true then
        if self.soul:collidesWith(self.walls.top) then
            if self.reached_top == false then
                self:makeSplash()
                self.reached_top = true
                self.soul.paused = true
                self.soul.can_move = false
                self.in_water = false
                self.soul.physics.speed_y = 0
                self.soul.physics.speed_x = 0
                self.soul.physics.gravity = 0
                self:playEndingCutscene()
            end

            if self.coins_spawned and not self.sliding then
                self.sliding = true
                if self.in_water then
                    self.soul:slideToSpeed(self.soul.x,166,8,function()
                        self:makeSplash()
                        self.in_water = false
                        self.sliding = false
                        self.soul.can_move = false
                        self.soul.physics.speed_y = -6
                        self.soul.physics.gravity = 0.3
                    end)
                else
                    self.soul:slideToSpeed(self.soul.x,196,8,function()
                        self:makeSplash()
                        self.in_water = true
                        self.sliding = false
                        self.soul.can_move = false
                        self.soul.physics.gravity = self.water_force
                    end)
                end
            end
        end
    end

    if self.grabbed_treasure and not self.spawned_shark and self.soul.y < 240 then
        self.soul.paused = true
        self.soul.physics.speed_y = 0
        self.soul.physics.speed_x = 0
        self.soul.physics.gravity = 0
        self:playSharkCutscene()
    end 

    if self.currently_warning then
        for i,v in ipairs(self.warning_signs) do
            v.y = self.soul.y
        end
    end

    if #self.hazards > 0 then
        for index, h in ipairs(self.hazards) do
            if self.coins_spawned then
                table.remove(self.hazards, index)
                h:remove()
            end

            if h:collidesWith(self.soul) then
                local current_health = Game.battle.party[1].chara:getHealth()
                local hazard_damage = h.damage_amount

                if current_health <= 15 then
                    hazard_damage = h.damage_amount - 1
                end

                if self.soul.inv_timer <= 0 then
                    self.soul.inv_timer = 1
                    Game.battle:hurt(hazard_damage, true)
                end
            end

            if h.name ~= "SharkHoarde" and (h.x > 515 or h.x < 120 or h.y > 400 or h.y < 60) then
                h.collidable = false
                h:remove()
            end
        end

        -- Removed hazards can otherwise stay referenced for the remainder of the wave.
        local hazard_write = 1
        for hazard_read = 1, #self.hazards do
            local hazard = self.hazards[hazard_read]
            if hazard.parent then
                self.hazards[hazard_write] = hazard
                hazard_write = hazard_write + 1
            end
        end
        for i = #self.hazards, hazard_write, -1 do
            self.hazards[i] = nil
        end
    end

    if self.coins_spawned then
        local soul_x, soul_y = self.soul:getScreenPos()

        -- Keep the original stack order (and its removal timing), since collection
        -- order affects sound pitch RNG, earned-value order and popup placement.
        for stack_index, stack in ipairs(self.coin_stacks) do
            if #stack.coins <= 0 then
                table.remove(self.coin_stacks, stack_index)
            end

            if #stack.coins > 0 then
                local stack_x = stack:getScreenPos()
                -- A stack is 30 px from its neighbours. 64 px is a conservative
                -- horizontal broad phase for the 26 px-wide scaled coins + soul.
                if math.abs(stack_x - soul_x) <= 64 then
                    for coin_index = #stack.coins, 1, -1 do
                        local coin = stack.coins[coin_index]
                        local coin_x, coin_y = coin:getScreenPos()
                        -- The real collider remains authoritative. These limits are
                        -- wider than the transformed 13x6 coin (scale 2) + soul.
                        if math.abs(coin_x - soul_x) <= 48 and math.abs(coin_y - soul_y) <= 32
                        and coin:collidesWith(self.soul) then
                            coin:remove()
                            table.remove(stack.coins, coin_index)
                            stack:realignCoins()
                            Assets.stopAndPlaySound("snd_ding", 0.25, love.math.random(1.1,1.05))
                            self.coins_collected = self.coins_collected + 1

                            local value = self.base_value
                            if self.coins_collected <= self.coin_remainder then
                                value = value + 1
                            end
                            Game:setFlag("MawzzGoldEarned",Game:getFlag("MawzzGoldEarned",0)+value)

                            local g_text = Game.battle:addChild(Text("[font:main, 32][style:menu][color:yellow] +"..value.."G", self.soul.x, self.soul.y))
                            g_text:slideTo(g_text.x + MathUtils.random(-100, 100, 10), g_text.y - 50, 1/3, "out-cubic", function()
                                g_text:fadeOutAndRemove(0.5)
                            end)
                        end
                    end
                end
            end
        end

        if #self.coin_stacks <= 0 then
            self.finished = true
            self.walls:remove()
        end
    end
    
end

function FinalMawzzWave:updateTimeline()

    self.wave_timer = self.wave_timer + DT

    if self.phase <= #self.timeline
    and self.wave_timer >= self.timeline[self.phase].time then

        local event = self.timeline[self.phase]
        event.action(self)

        self.phase = self.phase + 1
    end

end

function FinalMawzzWave:handleMovement()

    if not self.soul.paused then
        if Input.down("left") then
            self.soul.physics.speed_x = -self.movement_speed
        elseif Input.down("right") then
            self.soul.physics.speed_x = self.movement_speed
        else
            self.soul.physics.speed_x = 0
        end
    
        if self.in_water then
            if Input.pressed("confirm") then
                self.soul.physics.speed_y = self.swim_power
            end
        end
        
        if self.in_water then
            self.soul.physics.speed_y = MathUtils.clamp(self.soul.physics.speed_y,-6,2.3)
        else
            self.soul.physics.speed_y = MathUtils.clamp(self.soul.physics.speed_y,-6,5.3)
        end
    end
    
end

function FinalMawzzWave:grabTreasure()

    Assets.playSound("item")
    self.grabbed_treasure = true
    self.treasure:setParent(self.soul)
    self.treasure:setPosition(-24,8)

end

function FinalMawzzWave:spawnBubble()

    local bubble = self:spawnObjectTo(self, Bubble("objects/mawzz_games/divinggame/bubble"), self.soul.x, self.soul.y)
    bubble:setScreenPos(self.soul.x,self.soul.y)
    return bubble
end

function FinalMawzzWave:makeWarning(x,y)
    local warning = self:addChild(Sprite("objects/warning",x,y))
    warning:setScale(3)
    warning:setOrigin(0.5,0.5)
    warning:play(0.1)
    table.insert(self.warning_signs,warning)
    return warning
end

function FinalMawzzWave:makeSplash()
    Assets.playSound("splash")
    local splash = self:addChild(Sprite("particles/splash",self.soul.x,self.soul.y))
    splash:setOrigin(0.5,1)
    splash:setScale(2)
    splash:play(DT, false, function() splash:remove() end)
end

function FinalMawzzWave:playSharkCutscene()
    Assets.playSound("rumble")
    self.spawned_shark = true
    Game.battle.camera:shake(1,1,0.02)

    self.timer:after(0.42, function ()
        Game.battle.music:setVolume(0.7)
        Game.battle.music:play("mawzzboss_finale")
    end)
    
    self.timer:after(2, function()
        self.shark = self:addChild(FinalWaveShark(175,233,self.soul))
        table.insert(self.hazards,self.shark)
        self.shark:setParent(Game.battle.arena.mask)
        self.timer:tween(0.2, self.shark, {y = 186}, "linear", function()
            self.soul.paused = false
            self.soul.physics.gravity = self.water_force
        end)
        
        Assets.playSound("splash")
        Assets.playSound("screenshake")
        Assets.playSound("impact")
        Game.battle.camera:shake(2,2,0.05)
        self.walls.floor:remove()
        for i,v in ipairs(self.seaweeds) do v:remove() end
        --[[for i = 1,4 do
            local debris = self:addChild(Sprite("objects/mawzz_games/finalwave/debris"..i,172+50*i,365))
            debris:setScale(3)
        end]]
        self.walls.walls_moving = true

        --186
        

        
    end)
end

function FinalMawzzWave:playEndingCutscene()

    Assets.playSound("splash")
    Game.battle.music:stop()

    self.shark.state = "paused"

    self.timer:tween(0.5, self.soul, {x = 320, y = 130}, "linear", function()
        self.shark.state = "paused"
        self.timer:after(1, function()
            self.timer:tween(1, self.treasure, {y = self.treasure.y-50}, "linear", function()
                Assets.playSound("noise")
                self.treasure.sprite:setSprite("objects/mawzz_games/divinggame/treasure_opened")

                self.timer:after(1, function()
                    self.treasure.treasurebottomlayer = Sprite("objects/mawzz_games/divinggame/treasure_bottom_layer",0,8)
                    self.treasure.treasurebomb = Sprite("objects/mawzz_games/divinggame/bomb",-3,-3)
                    self.treasure:addChild(self.treasure.treasurebomb)
                    self.treasure:addChild(self.treasure.treasurebottomlayer)
                    Assets.playSound("item")

                    self.timer:tween(1, self.treasure.treasurebomb, {y = self.treasure.treasurebomb.y-25}, "linear", function()
                        --self.treasure.treasurebomb.physics.speed_y = 9
                        self.timer:after(0.2, function ()
                            Assets.playSound("snd_fall_short")
                            self.timer:tween(0.5, self.treasure.treasurebomb, {y = self.treasure.treasurebomb.y + 130}, "in-back", function()
                                self.shark:explode()
                                self.treasure.treasurebomb:remove()
                                self.treasure:remove()
    
                                self.soul.paused = false
                                self.soul.physics.gravity = 0.3
    
                                self.walls:addFloor()
                                self:addCoinStacks()
                                self.coins_spawned = true
                                Game:setFlag("MawzzBonus", 0)
                            
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)

end

function FinalMawzzWave:addCoinStacks()

    table.insert(self.coin_stacks, self:addChild(CoinStack(189,355,40)))
    table.insert(self.coin_stacks, self:addChild(CoinStack(219,355,32)))
    table.insert(self.coin_stacks, self:addChild(CoinStack(249,355,25)))
    table.insert(self.coin_stacks, self:addChild(CoinStack(279,355,10)))
    table.insert(self.coin_stacks, self:addChild(CoinStack(309,355,18)))
    table.insert(self.coin_stacks, self:addChild(CoinStack(339,355,28)))
    table.insert(self.coin_stacks, self:addChild(CoinStack(369,355,23)))
    table.insert(self.coin_stacks, self:addChild(CoinStack(399,355,13)))
    table.insert(self.coin_stacks, self:addChild(CoinStack(429,355,30)))

end

function FinalMawzzWave:draw()
    super.draw(self)

    if self.walls and self.walls.finished and self.walls.top then
        local top = self.walls.top

        if top.texture then

            local water_line = self._cwk_water_line
            local arena = Game.battle.arena

            local ax, ay = arena:getScreenPos()
            local aw, ah = arena.width, arena.height

            ax = ax - (aw / 2)
            ay = ay - (ah / 2)

            love.graphics.setScissor(ax, ay, aw, ah)

            local x, y = top:getScreenPos()

            love.graphics.setShader(self.water_shader)

            self.water_shader:send("time", Kristal.getTime())

            Draw.draw(
                water_line,
                x,
                y,
                0,
                top.scale_x,
                top.scale_y,
                top.origin_x,
                top.origin_y
            )

            love.graphics.setShader()

            Draw.draw(
                top.texture,
                x,
                y,
                0,
                top.scale_x,
                top.scale_y,
                top.origin_x,
                top.origin_y
            )

            love.graphics.setScissor()
        end
    end
end

return FinalMawzzWave