-- Code written by Mose

local DogWalkGame, super = Class("LightPhysicsWave")

-- TODO:
-- REWRITE THE WHOLE DAMN THING ToT
-- Balance
-- Ending celebration dance
-- Polish

function DogWalkGame:init()
    super.init(self, _s("minigame_popup-dogwalkgame", "DODGE COALS!"), "horiz_layout")

    Game:setFlag("Results", "none")

    self.time = -1

    self:setArenaSize(600,300)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 50)

    self.world:setGravity(0,1500)

    self.topspeed = 250
    self.canMove = true

    self.hurdles = {}
    self.hurdle_cooldown = 1
    self.stackCount = 0
    self.stackMax = 3
    self.use_old_hurdles = true -- Toggle this to switch between old and new hurdle sprites

    self.floorSpeed = -6
    self.floorSpecks = {}

    self.jumpers = {}
    self.jumpSpeed = 1.32    

    self.lifeMeter = {}
    self.lives = 3
    self.invincible = false
    self.iFrames = 30/30

    self.useTimer = 0
    self.useFlashTimer = 0

    self.flagIsHere = false
    self.playing_animation = false
    self.duration = 18

    self.xPosList = {}
    self.yPosList = {}

end

function DogWalkGame:onStart()
    super.onStart(self)

    -- Spawn floor
    self.floor = self:newStaticObject(Sprite("objects/dogwalkgame/floor"), self.arena_x, self.arena_y + 100, "rectangle", 1, _, 0.5, _)
    self.floor.fixture:setFriction(1)

    -- Spawn sun
    local dog = math.random()
    if dog < 0.07 then
        self.sun = self:spawnObject(Sprite("objects/dogwalkgame/sun_god_alt"))
        self.sun.god = true
    else
        self.sun = self:spawnObject(Sprite("objects/dogwalkgame/sun_alt"))
    end
    self.sun.x = Game.battle.arena.right - 42
    self.sun.y = Game.battle.arena.top + 42
    self.sun:setScale(4)
    self.sun:setOrigin(0.5)

    -- Spawn life count
    for i = 1, self.lives do
        local life = self:spawnObject(Sprite("ui/battle/icons/heart_small"), (Game.battle.arena.left + 8) + ((i-1)*32), Game.battle.arena.top + 12)
        life:setScale(3)
        table.insert(self.lifeMeter, i, life)
    end

    -- Spawn player
    self.heart = self:newDynamicObject(Sprite("player/heart_legs_string"), Game.battle.arena.left + 60, self.arena_y + 73, "rectangle", 2, _, 0.5, _, 0, 1, 0)
    self.heart.body:setFixedRotation(true)
    self.heart:play(0.25, true)
    self.heart:setLayer(BATTLE_LAYERS["bullets"])
    self.heart.collider = Hitbox(self.heart, 1, 1, self.heart.width - 2, self.heart.height - 2)

    -- Spawn dog
    self.dog = self:spawnObject(Sprite("objects/dogwalkgame/dog"), self.heart.x - 70, self.heart.y)
    self.dog:setScale(2)
    self.dog:setOrigin(0.5)
    self.dog:play(0.2, true)
    self.xPosList = {self.dog.x, self.dog.x, self.dog.x}
    self.yPosList = {self.dog.y, self.dog.y, self.dog.y}

    -- Spawn floor textures
    self:specks()

    -- Spawn jumpers
    self:jumperHandler()

    -- After duration seconds, reach the end
    self:flagAppears()

    -- Make mask above the arena
    local mask_obj = self:spawnObject(Sprite("objects/saladtossgame/mask"), Game.battle.arena:getTopLeft())
    mask_obj:setScale(Game.battle.arena:getSize())
    mask_obj:setLayer(BATTLE_LAYERS["bottom"])
    mask_obj.visible = false
    self.mask = MaskFX(mask_obj)

    -- Add the mask to all the objects
    self.heart:addFX(self.mask)
    self.dog:addFX(self.mask)

end

function DogWalkGame:update()
    super.update(self)

    self.floorSpeed = self.floorSpeed * (1.001 * DTMULT)

    -- Spawn hurdles after cooldown
    if self.hurdle_cooldown <= 0 then
        self:hurdleHandler()
        self.hurdle_cooldown = love.math.random(1,1.5)
    end

    self.hurdle_cooldown = self.hurdle_cooldown - (DT * DTMULT)

    -- Move the player heart
    if self.canMove then
        self:moveInput(self.heart, 3000, 1140)
    end

    if not self.playing_animation then
        self:moveDog()
    end

    -- Hit detection only matters while damage can actually be taken.
    if not self.invincible then
        Object.startCache()
        for _, h in ipairs(self.hurdles) do
            if h.parent and h.collider and self.heart.collider:collidesWith(h.collider) then
                self:hit()
                break
            end
        end
        if not self.invincible then
            for _, j in ipairs(self.jumpers) do
                if j.parent and j.collider and self.heart.collider:collidesWith(j.collider) then
                    self:hit()
                    break
                end
            end
        end
        Object.endCache()
    end

    -- SOUL flashing effect while invulnerable
    if self.useTimer > 0 then
        self.useTimer = Utils.approach(self.useTimer, 0, DT)
        self.useFlashTimer = self.useFlashTimer + DT
        if (math.floor(self.useFlashTimer / (4/30)) % 2) == 1 then
            if self.heart.color[1] ~= 0.5 or self.heart.color[2] ~= 0.5 or self.heart.color[3] ~= 0.5 then
                self.heart:setColor(0.5, 0.5, 0.5)
            end
        else
            if self.heart.color[1] ~= 1 or self.heart.color[2] ~= 1 or self.heart.color[3] ~= 1 then
                self.heart:setColor(1, 1, 1)
            end
        end
    else
        self.useFlashTimer = 0
        if self.heart.color[1] ~= 1 or self.heart.color[2] ~= 1 or self.heart.color[3] ~= 1 or self.heart.alpha ~= 1 then
            self.heart:setColor(1, 1, 1, 1)
        end
    end

    if self.lives == 0 and not self._cwk_fail_timer_started then
        self._cwk_fail_timer_started = true
        self.canMove = false
        self.world:setGravity(0,0)
        self.heart.body:setLinearVelocity(0,0)
        self.heart:stop()
        self.dog:stop()
        self.timer:after(0.25, function ()
            self.finished = true
            Stepscript:backStep("dogwalk")
        end)
    end

end

function DogWalkGame:scoreText(lives)
    local msg = ""
    local snd = "error"

    if lives >= 3 then
        msg = "Perfect"
        snd = "snd_perfect"
    elseif lives == 2 then
        msg = "Great"
        snd = "snd_great"
    elseif lives == 1 then
        msg = "Okay"
        snd = "snd_good"
    else
        if MathUtils.random() > 0.25 then
            msg = "Bad"
        else
            msg = ":("
        end
        snd = "error"
    end
    
    self:scoreMessage(msg, self.heart.x, self.heart.y)
    Assets.playSound(snd, 0.6, 1.2)
end

-- Spawns, moves, and despawns hurdles
function DogWalkGame:hurdleHandler()
    if self.stackCount < self.stackMax and not self.finished and not self.flagIsHere then
        self.stackCount = self.stackCount + 1

        local height = TableUtils.pick({"short_","mid_","high_"})
        local variant = math.random(1,2)
        local stack
        if self.use_old_hurdles then
            stack = self:spawnObject(Sprite("objects/dogwalkgame/stack/"..height.."old_"..variant), Game.battle.arena.right + 10, self.floor.y + 2)
            stack:setScale(4)
        else
            stack = self:spawnObject(Sprite("objects/dogwalkgame/stack/"..height..variant), Game.battle.arena.right + 10, self.floor.y + 2)
            stack:setScale(2)
        end
        stack:setOrigin(0.5, 1)
        stack:addFX(self.mask)
        stack.collider = Hitbox(stack, 1, 1, stack.width - 2, stack.height - 2)

        stack:setSpeed(self.floorSpeed,0)

        table.insert(self.hurdles, stack)
    end
    -- Remove hurdles
    for i, h in pairs(self.hurdles) do
        if h.x < Game.battle.arena.left - 10 then
            table.remove(self.hurdles, i)
            h:remove()
            self.stackCount = self.stackCount - 1
        end
    end
end

function DogWalkGame:specks()
    self.timer:everyInstant(1/3, function ()
        if not self.finished and not self.flagIsHere then
            local delay = math.random()
            self.timer:after(delay * 0.5, function ()
                if not self.finished and not self.flagIsHere then

                    local variant = math.random(1,3)
                    local height = math.random(self.floor.y + 4, self.floor.y + 34)
                    local speck = self:spawnObject(Sprite("objects/dogwalkgame/floor_textures/speck_"..variant), Game.battle.arena.right + 10, height)
                    speck:setScale(2)
                    speck:setOrigin(0.5, 0)
                    speck:addFX(self.mask)

                    speck:setSpeed(self.floorSpeed,0)

                    table.insert(self.floorSpecks, speck)
                end
            end)
            -- Remove specks
            for i, s in pairs(self.floorSpecks) do
                if s.x < Game.battle.arena.left - 10 then
                    table.remove(self.floorSpecks, i)
                    s:remove()
                end
            end
        end
    end)
end

-- Spawns, moves, and despawns jumpers
function DogWalkGame:jumperHandler()
    if Game:getFlag("magmaSauce", false) == true then
        self.timer:every(3, function ()
            if self.heart.y < self.arena_y + 74 and not self.finished and not self.flagIsHere then
                --local variant = math.random(1,3)
                --local jumper = self:spawnObject(Sprite("objects/dogwalkgame/jump/white_"..variant), self.heart.x, Game.battle.arena.bottom + 60)
                local jumper = self:spawnObject(Sprite("objects/dogwalkgame/lava"), self.heart.x, Game.battle.arena.bottom + 60)
                jumper:play(0.25)
                jumper:setScale(4)
                jumper:setOrigin(0.5)
                jumper:addFX(self.mask)
                jumper.collider = Hitbox(jumper, 1, 1, jumper.width - 2, jumper.height - 2)

                table.insert(self.jumpers, jumper)

                -- Flash warning
                local warning = self:spawnObject(Sprite("ui/battle/icons/warning"), jumper.x, Game.battle.arena.bottom - 24)
                warning:setScale(4)
                warning:setOrigin(0.5)
                warning:play(0.1, true)
                local playWarning = true

                self.timer:every(0.1, function ()
                    if playWarning then
                        Assets.playSound("snd_warn", 0.4)
                    else
                        return false
                    end
                end)

                --[[ self.timer:every(0.5, function ()
                    jumper.rotation = jumper.rotation + math.rad(90)
                end) ]]

                -- Make jumper jump
                self.timer:after(0.9, function ()
                    warning:remove()
                    playWarning = false
                    jumper:slideTo(jumper.x, Game.battle.arena.top + 60, self.jumpSpeed, "out-quad", function ()
                        jumper.rotation = math.pi

                        jumper:slideTo(jumper.x, Game.battle.arena.bottom + 61, self.jumpSpeed, "in-quad", function ()

                            -- Remove jumpers that have fallen below the arena
                            for i, j in pairs(self.jumpers) do
                                if j.x < Game.battle.arena.bottom + 60 then
                                    table.remove(self.jumpers, i)
                                    j:remove()
                                end
                            end
                        end)
                    end)
                end)
            end
        end)
    end
end

-- Overriding the LightPhysicsWave move function
function DogWalkGame:moveInput(obj, vel, acc)
    local x, y = obj.body:getLinearVelocity()

    if Input.down("confirm") and y == 0 then
        Assets.playSound("snd_bottlebloop", 0.7, 1.1)
        obj.body:applyLinearImpulse(0, -acc)
    end

    if Input.up("confirm") and y < 0 then
        obj.body:applyLinearImpulse(0, -y)
    end

    if Input.down("left") then
        obj.body:applyForce(-vel, 0)
    elseif Input.down("right") then
        obj.body:applyForce(vel, 0)
    end

    if math.abs(x) > self.topspeed then
        obj.body:applyLinearImpulse(x * -0.5, 0)
    end

end

-- Updates the dog's position to the hearts position three frames ago
function DogWalkGame:moveDog()
    self.dog.x = self.xPosList[1]
    table.remove(self.xPosList, 1)
    self.xPosList[3] = self.heart.x - 70

    self.dog.y = self.yPosList[1]
    table.remove(self.yPosList, 1)
    self.yPosList[3] = self.heart.y
end

function DogWalkGame:hit()
    -- Start invulnerablility
    self.invincible = true

    if self.lives > 0 then
        -- Shake hearts
        for _, l in pairs(self.lifeMeter) do
            l:slideTo(l.x - 1, l.y + 1, 1/30, "linear", function ()
                l:slideTo(l.x + 1, l.y - 1, 1/30, "linear")        
            end)
        end

        self.lifeMeter[self.lives]:fadeOutAndRemove(0.01)
        table.remove(self.lifeMeter,self.lives)
        self.lives = self.lives - 1

        if self.lives > 0 then 
            Assets.playSound("hurt", 0.6)
        else
            self:scoreText(0)
        end
    end

    -- Start flash timer
    self.useTimer = self.iFrames

    -- End invulnerability
    self.timer:after(self.iFrames, function ()
        self.invincible = false
    end)
end

-- End of minigame "cutscene"
function DogWalkGame:flagAppears()
    self.timer:after(self.duration, function ()
        if not self.finished then
            self.flagIsHere = true

            -- Wait a sec for everything to pass
            self.timer:after(1.5, function ()

                -- Spawn flag and move it to left side of screen
                self.flag = self:spawnObject(Sprite("objects/dogwalkgame/flag"), Game.battle.arena.right + 10, self.floor.y + 2)
                self.flag:setScale(4)
                self.flag:setOrigin(0.5, 1)
                self.flag:play(0.25, true)

                -- Big ugly block of code just to move a god damn object to a certain point
                -- My ultimate hubris; thinking I could make a plug-and-play physics system and still move a kristal object normally
                -- So much pain and suffering to get to this point
                -- When will I learn
                self.timer:after(1.5, function ()

                    self.canMove = false
                    self.invincible = true

                    self.world:setGravity(0,0)
                    self.heart.body:setLinearDamping(0)
                    self.floor.fixture:setFriction(0)

                    self.heart.body:setLinearVelocity(0,0)

                    local initX = self.heart.body:getX()
                    local finalX = self.arena_x + 75
                    local time = 1.5
                    self.heart.body:setLinearVelocity((finalX-initX)/time, 0)
                    self.heart.body:setY(self.arena_y + 73) 
                    self.timer:after(time, function ()
                        self.heart.body:setLinearVelocity(0,0)
                        self.heart:stop()
                        self.dog:stop()
                    end)
                end)

                self.flag:slideTo(Game.battle.arena.left + 150, self.flag.y, 3, "linear", function ()
                    if self.sun.god then
                        self.sun:setSprite("objects/dogwalkgame/sun_god_wink_alt")
                    end

                    self:scoreText(self.lives)

                    self.playing_animation = true

                    -- Start dog and SOUL celebration animation
                    self.timer:script(function (wait)
                        for i=1, 4 do
                            self.timer:tween(0.2, self.dog, {y = self.dog.y - 10}, "out-quad", function ()
                                self.timer:tween(0.2, self.dog, {y = self.dog.y + 10}, "in-quad")
                                self.dog.flip_x = not self.dog.flip_x
                            end)
                            wait(0.4)
                        end
                    end)
                    

                    self.timer:after(2, function ()
                        self.finished = true
                    end)
                end)

            end)
        end
    end)
end

function DogWalkGame:draw()

    love.graphics.setLineWidth(2)

    if self.dog and self.heart then
        love.graphics.line(self.dog.x + 24, self.dog.y + 2, self.heart.x - 16, self.heart.y - 8)
    end

end

function DogWalkGame:onEnd()
    
    for _, h in pairs(self.hurdles) do
        h:remove()
    end

    for _, s in pairs(self.floorSpecks) do
        s:remove()
    end

    for _, j in pairs(self.jumpers) do
        j:remove()
    end

    -- Return how many lives you had left by the end
    Game:setFlag("Results", self.lives)
    local score = self.lives
    if score == 1 then
        score = 2
    end
    if Game:getFlag("magmaSauce", false) == true then
        score = score*2
        Game.battle:getEnemyBattler("vulkin").metrecs = true
    end
    if score < 3 then
        score = score + 1
    end
    CustScore:addPoints(score)
    if self.lives == 0 then
        Stepscript:backStep("dogwalk")
    end


end

return DogWalkGame