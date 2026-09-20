local SauceShmupGameBase, super = Class("LightMinigameWave", "sauceshmupgame_base")

local function compactActiveObjects(objects)
    local write = 1
    local count = #objects
    for read = 1, count do
        local object = objects[read]
        if object and object.parent and object.collider then
            if write ~= read then
                objects[write] = object
            end
            write = write + 1
        end
    end
    for i = write, count do
        objects[i] = nil
    end
end

function SauceShmupGameBase:init()
    super.init(self, _s("minigame_popup-sauceshmupgame_base", "SAUCE 'EM UP!"), "full_layout_x")
    
    Game:setFlag("Results", "none")

    self.time = -1
    
    self:setArenaSize(520,300)

    self:setArenaPosition(320,286)
    
    
    self.sauceTable = {{name = "ketchup", color = {1,0,0}, cooldown = 2, bullets = {
                            basic = {
                                sprite = "objects/saucinshmupgame/saucebottle/bullets/smalldrop", 
                                color = {1,0,0}, 
                                --initFunc = function(obj) end,
                                updateFunc = function(obj) 
                                    obj.x = obj.x + 16 
                                end
                            }
                        }},

                        {name = "mustard", color = {.98,.98,.10}, cooldown = 4, bullets = {
                            forward = {
                                sprite = "objects/saucinshmupgame/saucebottle/bullets/smalldrop", 
                                color = {.98,.98,.10},
                                initFunc = function(obj)
                                    obj.physics.direction = 0
                                    obj.physics.speed = 8
                                end,
                                updateFunc = function(obj) end
                            },
                            up = {
                                sprite = "objects/saucinshmupgame/saucebottle/bullets/smalldrop_diagonal", 
                                color = {.98,.98,.10},
                                initFunc = function(obj)
                                    obj.physics.direction = math.rad(-20)
                                    obj.physics.speed = 8
                                end,
                                updateFunc = function(obj) end
                            },
                            down = {
                                sprite = "objects/saucinshmupgame/saucebottle/bullets/smalldrop_diagonal", 
                                color = {.98,.98,.10},
                                initFunc = function(obj)
                                    obj.flip_y = true
                                    obj.physics.direction = math.rad(20)
                                    obj.physics.speed = 8
                                end
                                --updateFunc = function(obj) end
                            }
                        }},
                        {name = "relish", color = {0,.98,.20}, cooldown = 4, bullets = {
                            hasOrbit = {
                                sprite = "objects/saucinshmupgame/saucebottle/bullets/smalldrop", 
                                color = {0,.98,.20},
                                initFunc = function(obj)
                                    obj.orbital = obj:addChild(Sprite("objects/saucinshmupgame/saucebottle/bullets/smallball"))
                                    obj.orbital:setOrigin(0.5, 0.5)
                                    obj.orbital.color = obj.color

                                    obj.orbital.rad = 8
                                    obj.orbital.omega = .22
                                    obj.orbital.theta = Utils.random(0, 2*math.pi)

                                    obj.orbital.x = obj.width/2  + obj.orbital.rad*math.cos(obj.orbital.theta)
                                    obj.orbital.y = obj.height/2 + obj.orbital.rad*math.sin(obj.orbital.theta)
                                end,
                                updateFunc = function(obj)
                                    obj.x = obj.x + 7

                                    obj.orbital.theta = obj.orbital.theta + obj.orbital.omega*DTMULT
                                    
                                    obj.orbital.x = obj.width/2  + obj.orbital.rad*math.cos(obj.orbital.theta)
                                    obj.orbital.y = obj.height/2 + obj.orbital.rad*math.sin(obj.orbital.theta)
                                end
                            }
                        }},
                        {name = "mayo", color = {1,.98,.90}, cooldown = 3, bullets = {
                            diag = {
                                sprite = "objects/saucinshmupgame/saucebottle/bullets/smalldrop", 
                                color = {1,.98,.90},
                                initFunc = function(obj)
                                    obj.x0 = obj.x
                                    obj.y0 = obj.y
                                end,
                                updateFunc = function(obj)
                                    obj.x = obj.x + 7
                                    obj.y = obj.y0 + 12*math.sin((obj.x-obj.x0) / 12)
                                end
                            }
                        }},
                        
                        }

    
    self.enemies = {}
    self.enemyStatus = {}
    self.bosses = {}
    self.bossStatus = {}
    self.playerBullets = {}
    self.enemyBullets = {}
    self.jumpers = {}
    self.jumpSpeed = 2

    self.targetBossColors = {}
    self.distaste = {}
    self.mainBossColors = {}
    self.allBossColors = {}
    self.bossMarkers = {}

    self.endType = "none"
end

function SauceShmupGameBase:onStart()
     
     

    self.centerX = (Game.battle.arena.left + Game.battle.arena.right) / 2
    self.centerY = (Game.battle.arena.top + Game.battle.arena.bottom) / 2

    self.player = self:spawnObject(SauceShmupBottle(self.centerX, self.centerY, self.sauceTable, self))
    self.player:setLayer(BATTLE_LAYERS["above_arena"])

    self.current_text = self:spawnObject(Text("Current: " .. self.sauceTable[self.player.currentSauceIndex].name, Game.battle.arena.left + 8, Game.battle.arena.top + 14, 300, 32, {color=self.sauceTable[self.player.currentSauceIndex].color}))
    self.current_text:setOrigin(0, 0.5)
    self._cwk_current_sauce_index = self.player.currentSauceIndex

    self.lives = {}
    for i = 1, 4 do
        local life = self:spawnObject(SauceShmupLife(Game.battle.arena.left + 16, Game.battle.arena.top + i*12 + 30))
        life.colorSprite.color = self.sauceTable[1].color
        table.insert(self.lives, life)
    end

    self.controls = self:spawnObject(ControlsDisplay(Game.battle.arena.left + 16, Game.battle.arena.top + 110, "button", false))
    self.controls:setOrigin(0.5)
    self.controls:setScale(1.4)
    self.controls_text = self:spawnObject(Text("Shoot", self.controls.x+self.controls.width, self.controls.y, 200, 32))
    self.controls_text:setOrigin(0, 0.5)

    self.controls2 = self:spawnObject(ControlsDisplay(Game.battle.arena.left + 16, Game.battle.arena.top + 134 + self.controls.height-11, "button_x", false))
    self.controls2:setOrigin(0.5)
    self.controls2:setScale(1.4)
    self.controls_text2 = self:spawnObject(Text("Swap", self.controls.x+self.controls2.width, self.controls2.y, 200, 32))
    self.controls_text2:setOrigin(0, 0.5)

    -- Make mask above the arena (this is just for the lava lol)
    local mask_obj = self:spawnObject(Sprite("objects/saladtossgame/mask"), Game.battle.arena:getTopLeft())
    mask_obj:setScale(Game.battle.arena:getSize())
    mask_obj:setLayer(BATTLE_LAYERS["bottom"])
    mask_obj.visible = false
    self.mask = MaskFX(mask_obj)

    if Game:getFlag("magmaSauce", false) then
        self.current_text.y = Game.battle.arena.bottom - 16
        self.controls.y = Game.battle.arena.bottom - 66
        self.controls_text.y = self.controls.y
        self.controls2.y = Game.battle.arena.bottom - 46
        self.controls_text2.y = self.controls2.y
        self:lavaHandler()
    end

    -- local enemy = self:spawnObject(Tankoyaki(self.centerX + 90, self.centerY, self))
    -- enemy:setLayer(BATTLE_LAYERS["above_arena"])
    -- table.insert(self.enemies, enemy)

    -- enemy = self:spawnObject(CherryDrone(self.centerX + 120, self.centerY + 70, 1, self))
    -- enemy:setLayer(BATTLE_LAYERS["above_arena"])
    -- table.insert(self.enemies, enemy)

    -- enemy = self:spawnObject(CherryDrone(self.centerX + 120, self.centerY - 70, -1, self))
    -- enemy:setLayer(BATTLE_LAYERS["above_arena"])
    -- table.insert(self.enemies, enemy)

    -- enemy = self:spawnObject(UnidentifiedBurgerObject(self.centerX + 100, self.centerY, self))
    -- enemy:setLayer(BATTLE_LAYERS["above_arena"])
    -- table.insert(self.enemies, enemy)

    --self:spawnEnemy(Tankoyaki(self.centerX + 90, "bottom", self))

    --self:spawnEnemy(HotdogLauncher(self.centerX + 90, self.centerY + 10, self))
    
    --self:spawnEnemy(CherryDrone(self.centerX + 120, self.centerY + 70, 1, self))
    --self:spawnEnemy(CherryDrone(self.centerX + 120, self.centerY - 70, -1, self))
    
    --self:spawnEnemy(UnidentifiedBurgerObject(self.centerX + 100, self.centerY, self), true, {"ketchup", "relish"})
end

function SauceShmupGameBase:lavaHandler()
    self.timer:every(3.5, function ()
        if not self.endTimer then
            local jumper = self:spawnObject(Sprite("objects/dogwalkgame/lava"), self.player.x, Game.battle.arena.top - 60)
            jumper:play(0.25)
            jumper:setScale(4)
            jumper:setOrigin(0.5)
            jumper.rotation = math.pi
            jumper:addFX(self.mask)
            jumper.collider = Hitbox(jumper, 1, 1, jumper.width - 2, jumper.height - 2)

            table.insert(self.jumpers, jumper)

            jumper.hitFunc = function()
                jumper:remove()
            end

            -- Flash warning
            local warning = self:spawnObject(Sprite("ui/battle/icons/warning"), jumper.x, Game.battle.arena.top + 24)
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

            -- Make jumper jump
            self.timer:after(0.9, function ()
                warning:remove()
                playWarning = false
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
        end
    end)
end

function SauceShmupGameBase:spawnEnemy(enemy, isBoss, targetColor, distaste)
    self:spawnObject(enemy)
    enemy:setLayer(BATTLE_LAYERS["above_arena"])
    table.insert(self.enemies, enemy)
    table.insert(self.enemyStatus, true)

    if isBoss then
        table.insert(self.bosses, enemy)
        table.insert(self.bossStatus, true)
        table.insert(self.targetBossColors, targetColor)
        table.insert(self.distaste, distaste)
        enemy.bossID = #self.bosses

        self:addMarker(enemy.bossID, targetColor)

        local onHitExtraOld = enemy.onHitExtra
        enemy.onHitExtra = function(obj, bullet)
            onHitExtraOld(obj, bullet)
            if obj.hp <= 0 then
                obj.board.mainBossColors[obj.bossID] = obj:getMainColor()
                obj.board.allBossColors[obj.bossID] = obj:getAllColors()
                obj.board:setBossDefeated(obj.bossID)
            end
        end
    end
end

function SauceShmupGameBase:setBossDefeated(n)
    self.bossStatus[n] = false
    local bossesLeft = false
    for i = 1, #self.bossStatus do
        if self.bossStatus[i] then
            bossesLeft = true
            break
        end
    end
    if not bossesLeft then
        for i = 1, #self.enemyStatus do
            if self.enemyStatus[i] then
                self:setEndTimer("all clear")
                return
            end
        end
        self:setEndTimer("boss clear")
    end
end

function SauceShmupGameBase:setEnemyDefeated(n)
    self.enemyStatus[n] = false

    if self.endType == "boss clear" then
        for i = 1, #self.enemyStatus do
            if self.enemyStatus[i] then
                return
            end
        end
        self:setEndTimer("all clear")
    end
end

function SauceShmupGameBase:setEndTimer(state)
    local table = {
        ["all clear"] = 0.75,
        ["boss clear"] = 5.0,
        ["player death"] = 0.75
    }
    if self.endType ~= "none" then
        --[[ if self.endType == "boss clear" then
            Game.battle.timer:cancel(self.endTimer)

            self:score()
            self.endType = state
            self.endTimer = Game.battle.timer:after(table[state], function() self.finished = true end)    
        end ]]
    else
        self:score()
        self.endType = state
        self.endTimer = Game.battle.timer:after(table[state], function() self.finished = true end)
    end
end

function SauceShmupGameBase:searchTableForColor(name)
    for i = 1, #self.sauceTable do
        if self.sauceTable[i].name == name then
            return self.sauceTable[i].color
        end
    end
    Kristal.Console:log("No sauce named "..name.." found in table!")
    return {1, 1, 1}
end

function SauceShmupGameBase:addMarker(id, col)
    local marker = self:spawnObject(Sprite("objects/saucinshmupgame/targetmarker"))
    if type(col) == "string" then
        marker.color = self:searchTableForColor(col)
    elseif type(col) == "table" then
        -- add color mask for each color in the table
        marker.colors = {}
        marker.cycleTime = 0.5
        for i = 1, #col do
            marker.colors[i] = self:searchTableForColor(col[i])
        end
    end
    marker.timer = 0
    marker.siner = #self.bossMarkers * math.pi / 6
    table.insert(self.bossMarkers, marker)

    marker.fadeTime = 0.5
    marker.scaleModDecayTime = 1/3
    
    marker.scaleModSine = 0.1*math.sin(marker.siner)
    marker.scaleModAppear = 1.5
    marker.spinSpeed = 0.4

    marker:setOrigin(0.5, 0.5)
    marker.x = self.bosses[id].x
    marker.y = self.bosses[id].y
end

function SauceShmupGameBase:showMarkers()
    for id, marker in ipairs(self.bossMarkers) do
        if self.bossStatus[id] then
            marker.alpha = 1
            marker.scaleModAppear = math.max(.3, marker.scaleModAppear)
        end
    end
end

function SauceShmupGameBase:updateMarkers()
    for id, marker in ipairs(self.bossMarkers) do
        if self.bossStatus[id] then
            marker.x = self.bosses[id].x + (self.bosses[id].markerOffsetX or 0)
            marker.y = self.bosses[id].y + (self.bosses[id].markerOffsetY or 0)

            marker.timer = marker.timer + DT
            marker.siner = marker.siner + DT
            marker.scaleModSine = 0.1*math.sin(marker.siner)
            marker:setScale(2 + marker.scaleModSine + marker.scaleModAppear)
            marker.rotation = marker.rotation + 2*math.pi*DT*marker.spinSpeed

            marker.scaleModAppear = math.max(0, marker.scaleModAppear - DT / marker.scaleModDecayTime)

            if marker.colors then
                -- cylce through colors:
                marker.color = marker.colors[1 + (math.floor(marker.timer / marker.cycleTime) % #marker.colors)]
            end

            if marker.scaleModAppear == 0 then
                marker.alpha = marker.alpha - DT / marker.fadeTime
            end
        end
    end
end

function SauceShmupGameBase:updateControlSprites()
    if Input.down("confirm") then
        self.controls.blink = false
    else
        self.controls.blink = true
    end

    if Input.down("cancel") then
        self.controls.blink = false
    else
        self.controls.blink = true
    end
end

function SauceShmupGameBase:tableContains(tab, val)
    for _, tabVal in pairs(tab) do
        if tabVal == val then return true end
    end
    return false
end

function SauceShmupGameBase:update()
    compactActiveObjects(self.playerBullets)
    compactActiveObjects(self.enemyBullets)
    compactActiveObjects(self.jumpers)

    Object.startCache()
    for i = 1, #self.enemies do
        local enemy = self.enemies[i]
        if enemy.parent and enemy.collider then
            for j = 1, #self.playerBullets do
                local bullet = self.playerBullets[j]
                if bullet.collider and bullet:collidesWith(enemy) then
                    enemy:onHit(bullet)
                    Object.uncache(enemy)
                    Object.uncache(bullet)
                end
            end
        end
    end

    for i = 1, #self.enemyBullets do
        local bullet = self.enemyBullets[i]
        if bullet.collider and self.player.collider and bullet:collidesWith(self.player) then
            self.player:onHit(bullet)
            Object.uncache(self.player)
            Object.uncache(bullet)
        end
    end

    for i = 1, #self.jumpers do
        local lava = self.jumpers[i]
        if lava.collider and self.player.collider and lava:collidesWith(self.player) then
            self.player:onHit(lava)
            Object.uncache(self.player)
            Object.uncache(lava)
        end
    end
    Object.endCache()

    self:updateMarkers()
    self:updateControlSprites()

    if self._cwk_current_sauce_index ~= self.player.currentSauceIndex then
        self._cwk_current_sauce_index = self.player.currentSauceIndex
        local sauce = self.sauceTable[self.player.currentSauceIndex]
        self.current_text:setText("Current: " .. sauce.name)
        self.current_text:setTextColor(unpack(sauce.color))
    end

    if self.endTimer then
        for i, v in ipairs(self.jumpers) do
            v:remove()
            table.remove(self.jumpers, i)
        end
    end

    super.update(self)
end

function SauceShmupGameBase:score()
    for i = 1, #self.bossStatus do
        if self.bossStatus[i] then
            self.mainBossColors[i] = self.bosses[i]:getMainColor()
            self.allBossColors[i] = self.bosses[i]:getAllColors()
        end
    end
    
    local score = 5
    -- if any bosses left, subtract two points.
    for i = 1, #self.bossStatus do
        if self.bossStatus[i] then
            score = score - 2
            break
        end
    end

    -- if all bosses were defeated, subtract a point if there are still two or more enemies left.
    -- else, two points were already subtracted, so spare the player and move on to other scoring.
    --[[if score == 5 then
        local enemiesLeft = 0
        for i = 1, #self.bossStatus do
            if self.enemyStatus[i] then
                enemiesLeft = enemiesLeft + 1
            end
            if enemiesLeft > 1 then
                score = score - 1
                break
            end
        end
    end]]

    -- subtract one point for each hit the player took, minus one free hit.
    score = score - MathUtils.clamp(self.player.hits - 1, 0, 2)

    -- subtract up to two points if sauce type used on boss didn't match.
    local wrongSauce = false
    local missingSauce = false
    local badSauce = false
    local flag = {}
    
    -- check if any wrong sauces were used, subtract 2 points if they were.
    for i = 1, #self.bosses do
        -- if target for this boss is just one string, stuff it into a table to make the iterator work
        if type(self.targetBossColors[i]) == "string" then
            self.targetBossColors[i] = {self.targetBossColors[i]}
        end
        for ind, sauce in ipairs(self.allBossColors[i]) do
            if not self:tableContains(self.targetBossColors[i], sauce) then
                wrongSauce = true
                if self:tableContains(self.distaste[i], sauce) then
                    badSauce = true
                    score = score - 2
                end
                --break (I don't know why there was a break here, but i removed it and the minigame works fine)
            end
        end
    end

    -- if no wrong sauces, check if all right sauces were used. subtract 1 point for each one missing.
    -- used to be an if statement checking for "not wrongSauce", but this caused some obvious issues
    local checks = {}
    local sum = 0
    
    -- if target for this boss is just one string, stuff it into a table to make the iterator work
    if type(self.targetBossColors[1]) == "string" then
        self.targetBossColors[1] = {self.targetBossColors[1]}
    end
    checks[1] = {}
    if self.targetBossColors[1] then
        for ind, target in ipairs(self.targetBossColors[1]) do
            checks[1][ind] = self:tableContains(self.allBossColors[1], target)
            if not checks[1][ind] then
                missingSauce = true
                flag[#flag + 1] = self.targetBossColors[1][ind]
                Kristal.Console:log("did not detect "..self.targetBossColors[1][ind])
            else
                Kristal.Console:log("detected "..self.targetBossColors[1][ind])
                sum = math.max(sum + 2, 0)
            end
        end
    end
    if missingSauce then Game:setFlag("MissingSauce", flag) end
    score = score - (2 - sum)

    -- for i = 1, #self.bosses do
    --     if self.mainBossColors[i] ~= self.targetBossColors[i] then
    --         colorPenalty = math.min(2, colorPenalty + 1)
    --     end
    --     if self.mainBossColors[i] == self.targetBossColors[i] then
    --         rightSauce = math.min(2, rightSauce + 1)
    --     end
    -- end
    -- score = score - colorPenalty
    -- if rightSauce == 2 then
    --     Game:setFlag("Results", "Right Sauce")
    --     Kristal.Console:log("Right Sauce")
    --     if colorPenalty > 0 then
    --         Game:setFlag("Results", "Wrong Sauce")
    --         Kristal.Console:log("Wrong Sauce")
    --     end
    -- end
    -- if colorPenalty > 0 then
    --         Game:setFlag("Results", "Wrong Sauce")
    --         Kristal.Console:log("Wrong Sauce")
    --     end
    -- if rightSauce < 2 and colorPenalty == 0 then
    --     Game:setFlag("Results", "Missing Sauce")
    --     Kristal.Console:log("Missing Sauce")
    -- end

    if score < 0 then score = 0 end
    --Kristal.Console:log("Where is sauce?????")

    Kristal.Console:log(math.max(1, score))
    CustScore:addPoints(math.max(1, score))

    --[[ -- Make the sprite that will display the score message
    local text = self:spawnObject(Sprite("ui/battle/scoremsg/blank"), self.player.x,self.player.y)
    text:setScale(1.66)
    text:setOrigin(0.5)
    text:setLayer(BATTLE_LAYERS["top"]) ]]

    local msg = "" -- What message to dislpay
    local snd = "error" -- What sound effect to play
    local res = "blank" -- What to set the "Results" flag to

    print("Score: " .. score)

    -- Behold my fucked up and evil if-else chain
    -- Somehow this is more straightforward than what was here before, I promise
    -- I just pray this works
    if (wrongSauce and badSauce) or missingSauce or self.player.has_died then -- Start with the bad, if the player got a bad sauce, or is missing a sauce, or died
        -- This first bit is to set the appropriate flags according to how we got here, and log the reasons, prioritizing death, then missingSauce (you're welcome to swap these)
        if self.player.has_died then -- If the player died
            res = "sauceFail"
            Kristal.Console:log("Sauce Failed.")
        elseif missingSauce then -- If one or more of the sauces are missing
            res = "missingSauce"
            local s = "Missing " .. flag[1]
            if #flag > 1 then
                for i = 2, #flag do
                    s = s .. ", " .. flag[i]
                end
            end
            s = s .. "."
            Kristal.Console:log(s)
        elseif wrongSauce then -- If the wrong sauce has been used
            res = "wrongSauce"
            Kristal.Console:log("Wrong sauce.")
        end

        msg = "Bad"
        snd = "error"

        -- This bit is here because Grillby and Vulkin have different fail states
        if Game.battle:getEnemyBattler("grillby") then -- For grillby, if any of the things in the above if statement are true, backstep
            Stepscript:backStep("burgsauceshmup")
        elseif Game.battle:getEnemyBattler("vulkin") and self.player.has_died then -- For vulkin, we only want to backstep if the player dies
            Stepscript:backStep("vulkinsauceshmup")
        end
    else
        Game:setFlag("AllowedToVeggie", true) -- If none of the things in the first if are true, let the player continue in the Grillboss
        if wrongSauce and not badSauce then -- If you got a sauce wrong, but it wasn't a badSauce, then just Okay
            msg = "Okay"
            snd = "snd_good"
            res = "sauceOK"
            Kristal.Console:log("sauceOk.")
        elseif not wrongSauce and not missingSauce and not badSauce then -- If you got all the sauces right, then Great or Perfect depending on score
            if score > 4 then
                msg = "Perfect"
                snd = "snd_perfect"
                res = "sauceGreat"
                Kristal.Console:log("sauceGreat.")
                CustScore:addPoints(5)
            elseif score <= 4 then
                msg = "Great"
                snd = "snd_great"
                res = "sauceGood"
                Kristal.Console:log("sauceGood.")
                CustScore:addPoints(4)
            end
        end
    end

    -- Finally, you can set the score message, play a sound, and set the results flag
    --text:setSprite("ui/battle/scoremsg/"..msg)
    self:scoreMessage(msg, self.player.x, self.player.y)
    Assets.playSound(snd, 0.6, 1.2)
    Game:setFlag("Results", res)

    Kristal.Console:log(Game:getFlag("Results"))

    --[[ if not wrongSauce and not missingSauce and not badSauce and Game:getFlag("Results") ~= "sauceFail" then
        if score > 4 then
            text:setSprite("ui/battle/scoremsg/perfect")
            Assets.playSound("snd_perfect", 0.6, 1.2)
            Game:setFlag("Results", "sauceGreat")
            Kristal.Console:log("sauceGreat.")
            CustScore:addPoints(5)
        elseif score <= 3 then
            text:setSprite("ui/battle/scoremsg/great")
            Assets.playSound("snd_great", 0.6, 1.2)
            Game:setFlag("Results", "sauceGood")
            Kristal.Console:log("sauceGood.")
            CustScore:addPoints(4)
        end
    end

    if wrongSauce and not badSauce then
        text:setSprite("ui/battle/scoremsg/okay")
        Assets.playSound("snd_good", 0.6, 1.2)
        Game:setFlag("Results", "sauceOK")
        Kristal.Console:log("sauceOk.")
    end

    if Game.battle:getEnemyBattler("grillby") then
        if Game:getFlag("Results") == "missingSauce" or Game:getFlag("Results") == "sauceFail" then
            Assets.playSound("error")
            if MathUtils.random() > 0.25 then
                text:setSprite("ui/battle/scoremsg/bad")
            else
                text:setSprite("ui/battle/scoremsg/frown")
            end
            Stepscript:backStep("burgsauceshmup")
        else
            Game:setFlag("AllowedToVeggie", true)
        end
    else
        if Game:getFlag("Results") == "missingSauce" or Game:getFlag("Results") == "sauceFail" or badSauce then
            Assets.playSound("error")
            if MathUtils.random() > 0.25 then
                text:setSprite("ui/battle/scoremsg/bad")
            else
                text:setSprite("ui/battle/scoremsg/frown")
            end
        end
        if Game:getFlag("Results") == "sauceFail" then
            Stepscript:backStep("vulkinsauceshmup")
        end
    end ]]
    
    --[[ text:slideTo(text.x + MathUtils.random(-100, 100, 10), text.y - 100, 1/3, "out-cubic", function()
        text:fadeOutAndRemove(0.5)
    end) ]]
end

return SauceShmupGameBase