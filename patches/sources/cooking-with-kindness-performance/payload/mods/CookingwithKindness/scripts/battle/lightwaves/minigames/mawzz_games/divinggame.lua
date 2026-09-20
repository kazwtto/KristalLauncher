--Code by Sharks!

local DivingGame, super = Class("LightMinigameWave")

function DivingGame:init()
    super.init(self, _s("minigame_popup-divinggame", "FIND THE\nTREASURE!"), "horiz_layout")

    -- I hate that I had to make an object for this
    Game.battle:addChild(MawzzSounder("mawzz_findthetreasure"))

    self.time = -1
    Game:setFlag("Results", "none")
    self:setArenaSize(350, 300)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 - 10)

    self.grabbed_treasure = false --Tracks whether the treasure has been grabbed or not

    self.in_water = true
    self.sliding = false

    self.water_force = 0.47 --How strong the water pulls you down
    self.swim_power = -6 --How strong you swim up
    self.movement_speed = 3 --How fast you move left and right

    --shark
    self.point_samples = {} --Table of the sampled points
    self.reroute = {0,0} --reroute point.
    self.shark_mov_speed = 0
    self.shark_angle_target_x = 0
    self.shark_angle_target_y = 0

    self.bubbles = {}

    --Water shader
    self.siner = 0
    self.shader = love.graphics.newShader([[
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
    self.shader:send("texture_dim", {163, 15})
    self._cwk_water_line = Assets.getTexture("objects/mawzz_games/divinggame/diving_waterline")
    self._cwk_wall_layering = Assets.getTexture("objects/mawzz_games/divinggame/wall_layering")
end

function DivingGame:onStart()
    super.onStart(self)

    --The minigame's map
    self.map = DiveGameMap(-424, 5)
    self:addChild(self.map)
    self.map:setParent(Game.battle.arena.mask)

    --The soul player
    self.soul = self:spawnObject(Soul(), 320, 240)
    self.soul:setColor(0,1,0)
    self.soul.sprite:setSprite("player/heart")
    self.soul.noclip = false
    self.soul.can_move = false
    self.soul.slope_correction = true
    self.soul.physics.gravity = self.water_force
    self.soul.stunTime = 0
    self.soul.paused = false

    -- Create swim text
    self.button = self:spawnObject(Sprite("objects/buttons/swim_text"), Game.battle.arena:getRight() - 3, Game.battle.arena:getBottom() - 1)
    self.button:setScale(2)
    self.button:setOrigin(1, 1)

    -- Create swim button
    self.swim_button = self:spawnObject(ControlsDisplay(self.button.x-self.button.width*2, self.button.y, "button", false))
    self.swim_button:setOrigin(1, 1)
    self.swim_button:setScale(1.4)

    --The camera's static region
    self.cam_region = {
        left = 320 - 30,
        right = 320 + 30,
        top = 240 - 60,
        bottom = 240 + 60
    }

    --50/50 coin flip to spawn a bubble every second
    self.timer:everyInstant(1, function()
        if self.in_water then
            local b = love.math.random(1,2)

            if b == 1 then
                local bubble = self:spawnBubble()
                table.insert(self.bubbles,bubble)
            end
        end
    end)

    --Sample the nodes
     self.timer:every(0.3, function()
        if self.sharkspawned then
            local x,y = self.soul:getRelativePosFor(self.map)
            table.insert(self.point_samples, {x,y})
            table.insert(self.map.node_pos, {x,y})
        end
    end)
end

function DivingGame:update()
    super.update(self)

    if not self.sliding then
        self:handleMovement()
        self:handleCamera()
    end
    
    --Stun timer and flicker
    if self.soul.stunTime > 0 then 
        self.soul.physics.speed_x = 0
        self.soul.stunTime = self.soul.stunTime - 1 * DTMULT
    end

    if self.soul.stunTime % 2 == 1 then
        self.soul:fadeTo(0.6, 0.05)
    else
        self.soul:fadeTo(1, 0.05)
    end


    --Remove bubbles that are too high and release their references.
    local bubble_write = 1
    for bubble_read = 1, #self.bubbles do
        local b = self.bubbles[bubble_read]
        if not b.parent or b.y < 37 then
            if b.parent then b:remove() end
        else
            self.bubbles[bubble_write] = b
            bubble_write = bubble_write + 1
        end
    end
    for i = #self.bubbles, bubble_write, -1 do
        self.bubbles[i] = nil
    end

    --Lets the player go up and down slopes
    if self.soul.last_collided_x == 1 and self.soul.last_collided_y == 1 then
        self.soul.y = self.soul.y - 1
    elseif self.soul.last_collided_x == -1 and self.soul.last_collided_y == 1 then
        self.soul.y = self.soul.y - 1
    end

    --Grabs the treasure if collided with chest
    if self.soul:collidesWith(self.map.treasure) and not self.grabbed_treasure then
        self:grabTreasure()
    end

    --BOOM!!!!!!!!!! Update: no longer boom it's a stun now :(
    if self.soul.stunTime <= 0 then
        Object.startCache()
        for _, v in ipairs(self.map.bombs) do
            if v.parent and v:collidesWith(self.soul) then
                self:stunPlayer(v)
                break
            end
        end
        Object.endCache()
    end
    
    --If you have the treasure and are colliding with the waterline, you're winner!!!!!.
    if self:isHittingWaterLine() then

        if self.grabbed_treasure then
            Assets.playSound("snd_perfect")
            local coin = Game.battle:addChild(Text("[font:main, 32][style:menu][color:yellow] +150G", self.soul.x, self.soul.y))
            Game:addFlag("MawzzGoldEarned", 150)
            Game.lw_money = Game.lw_money + 30
            Game:setFlag("MawzzBonus", math.floor(30))

            -- Slide the text away and fade it out
            coin:slideTo(coin.x + MathUtils.random(-100, 100, 10), coin.y - 50, 1/3, "out-cubic", function()
                coin:fadeOutAndRemove(0.5)
            end)

            self.finished = true
        end

        --Do a water jump/dive
        if not self.grabbed_treasure and not self.sliding then
            if self.in_water then
                self.sliding = true
                self.soul:slideToSpeed(self.soul.x,self.soul.y-18,8,function()
                    self:splash()
                    self.sliding = false
                    self.soul.physics.gravity = self.water_force
                    self.soul.physics.speed_y = -6
                    self.soul.physics.gravity = 0.3
                    self.in_water = false
                end)
            else
                self.sliding = true
                self.soul:slideToSpeed(self.soul.x,self.soul.y+18,8,function()
                    self:splash()
                    self.soul.physics.gravity = self.water_force
                    self.sliding = false
                    self.in_water = true
                end)
                
            end
            
        end
    end

    --Shark :) 

    if self.sharkspawned == true then

        if self.soul:collidesWith(self.shark) and not self.shark.got_player then
            self.soul.paused = true
            self.soul.physics.gravity = 0
            self.soul.physics.speed_x = 0
            self.soul.physics.speed_y = 0
        
            self.shark.got_player = true
            self.shark:setSprite("objects/mawzz_games/divinggame/tommy_shark_2")
        
            --Slide to the players position, accounting for scale and rotation
            local px, py = self.soul:getRelativePosFor(self.map)

            local rot = MathUtils.angle(self.shark.x, self.shark.y, px, py) + math.pi
            
            self.shark.rotation = rot
            
            local ox = 12 - (self.shark.width * self.shark.origin_x) --Position offsets
            local oy = 20 - (self.shark.height * self.shark.origin_y)
            
            local sx = ox * self.shark.scale_x
            local sy = oy * self.shark.scale_y
            
            local rx = sx * math.cos(rot) - sy * math.sin(rot) --Make position and offsets match the rotation of the shark
            local ry = sx * math.sin(rot) + sy * math.cos(rot)
            
            local tx = px - rx
            local ty = py - ry
            
            self.shark:slideToSpeed(tx, ty, 10, function()
                self.timer:script(function(wait)
                    wait(0.1)
                    self.shark:setSprite("objects/mawzz_games/divinggame/tommy_shark_1")
                    self.soul.visible = false
                    Assets.playSound("damage")
                    Game.battle.camera:shake()
                    wait(0.2)
                    self.finished = true
                end)
            end)
        end

        -- Flip sprite depending on rotation
        if math.cos(self.shark.rotation) > 0 then
            self.shark.scale_y = 2
        else
            self.shark.scale_y = -2
        end

        --Rubberband the shark's speed so it speeds up when you do
        local vx = self.soul.physics.speed_x
        local vy = self.soul.physics.speed_y
        
        local player_speed = math.max(0,-vy)
        
        local target_speed = 3.5+(player_speed ^ 1.3)*0.9

        target_speed = MathUtils.clamp(target_speed,3.5,5.5)
        
        self.shark_mov_speed = MathUtils.approach(self.shark_mov_speed,target_speed,0.3 * DTMULT)
        
        --If there are 3 or more nodes, do pathfinding!
        if #self.point_samples >= 3 and self.shark.got_player == false then
    
            local A = self.point_samples[1]
            local B = self.point_samples[2]
            local C = self.point_samples[3]
    
            local target
    
            --Whether the path from A to C is blocked by collision or not
            local blocked = self:lineHitsWall(A[1], A[2], C[1], C[2])
    
            if not blocked then
                target = C
            else
                target = B
            end
    
            self.shark.target_x = target[1]
            self.shark.target_y = target[2]
    
            local angle = MathUtils.angle(self.shark.x,self.shark.y,self.shark.target_x,self.shark.target_y)
    
            self.shark.physics.direction = angle
            self.shark.physics.speed = self.shark_mov_speed
    
            self.shark.rotation = MathUtils.approachAngle(self.shark.rotation,angle + math.pi,0.5)
    
            local dist = Utils.dist(self.shark.x,self.shark.y,self.shark.target_x,self.shark.target_y)
    
            if dist < 8 then
    
                if target == C then
                    --Remove A & B
                    table.remove(self.point_samples, 1)
                    table.remove(self.point_samples, 1)
                else
                    --Remove only A
                    table.remove(self.point_samples, 1)
                end
    
            end
    
        else
            -- No path points left
            self.shark.physics.speed = 0
        end
    end
end

function DivingGame:lineHitsWall(x1, y1, x2, y2)
    local hit_count = 0
    local xcount = 0
    local ycount = 0
    for i = 1, #self.map.edges do
        local edge_group = self.map.edges[i]
        for v = 1, #edge_group do
            local edge = edge_group[v]
            local hitX = Utils.getLineIntersect(x1, y1, x2, y2, edge[1][1], edge[1][2], edge[2][1], edge[2][2], true, true)
            if hitX then
                hit_count = hit_count + 1
                xcount = xcount + hitX
                ycount = ycount + hitX
            end
        end
    end

    if hit_count > 0 then
        return true, xcount / hit_count, ycount / hit_count
    end
    return false
end

function DivingGame:handleCamera()

    --When the player leaves the camera's static region, move the camera to catch up
    local x, y = self.soul.x, self.soul.y
    local left, right, top, bottom = self.cam_region.left, self.cam_region.right, self.cam_region.top, self.cam_region.bottom

    local overflow_x, overflow_y = 0, 0

    --Player reaches top of static region, move camera up to catch up
    if y < top then
        overflow_y = top - y
        self.soul.y = top
        self.map.y = self.map.y + overflow_y
    end
    
    --Player reached bottom of static region, move camera down to catch up
    if y > bottom then
        overflow_y =  y - bottom
        self.soul.y = bottom
        self.map.y = self.map.y - overflow_y
    end

    --Player reaches left of static region, move camera left to catch up
    if x < left then
        overflow_x =  left - x
        self.soul.x = left
        self.map.x = self.map.x + overflow_x
    end

    --Player reaches right of static region, move camera right to catch up
    if x > right then
        overflow_x =  x - right
        self.soul.x = right
        self.map.x = self.map.x - overflow_x
    end
end

function DivingGame:handleMovement()
    
    if self.soul.stunTime <= 0 and self.soul.paused == false then
        --Move
        if Input.down("left") then
            self.soul.physics.speed_x = -self.movement_speed
        elseif Input.down("right") then
            self.soul.physics.speed_x = self.movement_speed
        else
            self.soul.physics.speed_x = 0
        end

        --Swim
        if self.in_water then
            if Input.pressed("confirm") then
                self.soul.physics.speed_y = self.swim_power
                self.swim_button.flash = false
                self.timer:after(0.25, function()
                    self.swim_button.flash = true
                end)
            end
        end
    end

    if not self.soul.paused then
        if self.in_water then
            self.soul.physics.speed_y = MathUtils.clamp(self.soul.physics.speed_y,-6,2.3)
        else
            self.soul.physics.speed_y = MathUtils.clamp(self.soul.physics.speed_y,-6,5.3)
        end
    end
    

end

function DivingGame:grabTreasure()

    --Attach the treasure to the player
    Assets.playSound("item")
    self.grabbed_treasure = true
    self.map.treasure:setParent(self.soul)
    self.map.treasure:setPosition(-24,8)

    --Grabbing the treasure makes you swim less high and weight pulls you down more
    --self.swim_power = -4
    self.water_force = 0.6

    self:spawnTheShark()
end

function DivingGame:spawnTheShark()

    local x,y = self.soul:getRelativePosFor(self.map)

    Assets.playSound("m_laugh2")

    --The shark. His name is Tommy :)

    self.shark = self.map:addChild(Sprite("objects/mawzz_games/divinggame/tommy_shark",71,803))
    self.shark:play(0.15)
    self.shark:setScale(2)
    self.shark:setOrigin(0.5,0.5)
    self.shark.collider = CircleCollider(self.shark, 10,20,10)
    self.shark.scale_y = -2
    self.shark.rotation = math.rad(90)
    self.shark.physics.direction = math.rad(90)
    self.shark.physics.speed = 0
    self.shark.target_x = x
    self.shark.target_y = y
    self.shark.got_player = false

    Game.battle.camera:shake()
    Assets.playSound("splash")
    Assets.playSound("screenshake")
    for i = 1,4 do
        local debris = Sprite("objects/mawzz_games/divinggame/debris"..i,love.math.random(23,101),770)
        debris:setOrigin(0.5,0.5)
        debris:setScale(2)
        self.map:addChild(debris)
        debris.physics.match_rotation = true
        debris.physics.spin = love.math.random(0.01,0.03)
        debris:slideTo(debris.x + love.math.random(-10,10),debris.y-love.math.random(30,60),0.5,"out-cubic", function()
            debris.physics.speed_y = 1
        end)
    end

    self.map.floor_sprite:remove()

    self.timer:tween(1, self.shark, {y = 740, rotation = math.rad(180)}, "out-cubic", function()
        self.sharkspawned = true

    end)

end

function DivingGame:spawnBubble()

    --Spawns a bubble at the players location
    local bubble = self:spawnObjectTo(self.map, Bubble("objects/mawzz_games/divinggame/bubble"), self.soul.x, self.soul.y)
    bubble:setScreenPos(self.soul.x,self.soul.y)
    return bubble
end

function DivingGame:splash()
    Assets.playSound("splash")
    local splash = Sprite("particles/splash")
    splash:setPosition(self.soul:getRelativePosFor(self.map))
    splash:setOrigin(0.5,1)
    splash:setScale(2)
    self.map:addChild(splash)
    splash:play(DT, false, function() splash:remove() end)
end

function DivingGame:stunPlayer(bomb)
    if self.soul.stunTime > 0 then return end
    Assets.playSound("bomb")
    Assets.playSound("break1")

    --Get the angle of the player compared to the bomb, slide them in that direction, then stun them
    local bx, by = bomb:getScreenPos()
    local sx, sy = self.soul:getScreenPos()

    local angle = MathUtils.angle(bx, by, sx, sy)

    local dist = 20
    local dx = math.cos(angle) * dist
    local dy = math.sin(angle) * dist

    self.soul.stunTime = 30

    self.soul:slideTo(self.soul.x + dx, self.soul.y + dy, 0.1, "linear", function()
    end)
end

function DivingGame:isHittingWaterLine()

    if self.soul:collidesWith(self.map.win_collider) then
        return true
    else
        return false
    end

end

function DivingGame:draw()
    super.draw(self)

    --Draw the waterline at the top with the cool water shader
    local map = self.map
    
    if map then

        local water_line = self._cwk_water_line
        local layering = self._cwk_wall_layering
        local arena = Game.battle.arena
        local x, y = map:getScreenPos()

        local ax, ay = arena:getScreenPos()
        local aw, ah = arena.width, arena.height

        ax = ax - (aw / 2)
        ay = ay - (ah / 2)

        love.graphics.setScissor(ax, ay, aw, ah)

        love.graphics.setShader(self.shader)

        self.shader:send("time", Kristal.getTime())

        Draw.draw(
            water_line,
            x+335,
            y+34,
            0,
            map.scale_x*2,
            map.scale_y*2,
            map.origin_x,
            map.origin_y
        )

        love.graphics.setShader()

        Draw.draw(
        layering,
        x+323,
        y+25,
        0,
        map.scale_x*2,
        map.scale_y*2,
        map.origin_x,
        map.origin_y
        )
        love.graphics.setScissor()
    end

   --[[if self.sharkspawned == true then
        self.shark.collider:drawFor(self, 1,0,0,1)
   end]]
end

function DivingGame:onEnd()
    self.map:remove()
    Stepscript:backStep("treasuredive")
    Game:setFlag("CurrentMinigame", "diving")
end


return DivingGame