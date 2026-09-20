local IceCreamConeGame, super = Class("LightMinigameWave")

function IceCreamConeGame:init()
    super.init(self, _s("minigame_popup-icecreamconegame", "CATCH!"), "horiz_layout_alt")

    self:setArenaSize(150,350)
    self:setArenaPosition(320,210)
    self.time = -1

    self.flavorSet = {"vanilla","chocolate","strawberry","cookiesncream","mint"}
    self.targetNumber = 6

    self.targetFlavors = {}
        for i=1, 1 do
            table.insert(self.targetFlavors, Game:getFlag("targetFlavour"))
        end

    self.flavors = self:generateFlavorsTable()

    self.readyForInput = true
    self.travelTime = 4

    self.centerX = (Game.battle.arena.left + Game.battle.arena.right) / 2
    self.centerY = (Game.battle.arena.bottom + Game.battle.arena.top) / 2

    self.laneWidth = 50
    self.lanePositions = {self.centerX - self.laneWidth, self.centerX, self.centerX + self.laneWidth} 

    self.endTimerStarted = false

    self.ending = false
end

function IceCreamConeGame:generateFlavorsTable()
    local f = {}
    for _,flavor in ipairs(self.flavorSet) do
        table.insert(f, flavor)
        --table.insert(f, flavor)
    end

    -- add duplicates of target flavors to table to increase odds of desired flavors showing up
    for _,flavor in ipairs(self.targetFlavors) do
        table.insert(f, flavor)
        table.insert(f, flavor)
    end

    return f
end

function IceCreamConeGame:onStart()

    self.cone = self:spawnObject(IceCreamCone(self.centerX,Game.battle.arena.bottom - 8))
    self.cone:setLayer(BATTLE_LAYERS["above_arena"])

    self.scoops = {}
    self.stack = {scoops = {},
                  cone = self.cone,
                  top = self.cone,
                  topY = self.cone.y - self.cone.coneOffset,
                  lane = 2}

    self.scoopTimer = self.timer:every(2/5, function()
        if MathUtils.random() < 1 then
            -- Get position in board at least 5 units from edges:
            local lane = TableUtils.pick({1,2,3})
            local x = self.lanePositions[lane]
            local y = Game.battle.arena.top - 50
            
            local flavor = TableUtils.pick(self.flavors)

            local scoop = self:spawnObject(IceCreamConeScoop(x, y, lane, flavor, self.stack))
            scoop:setLayer(BATTLE_LAYERS["below_soul"])
            table.insert(self.scoops, scoop)
        end
    end)


    -- lane lines:
    local x1 = (self.lanePositions[1] + self.lanePositions[2])/ 2
    local x2 = (self.lanePositions[2] + self.lanePositions[3])/ 2
    local y1 = Game.battle.arena.bottom - 30
    local y2 = Game.battle.arena.top    + 30

    local laneBar1 = self:spawnObject(Sprite("objects/icecreamconegame/mask_alt",x1,y1))
    laneBar1:setScale(2,y2-y1)
    laneBar1:setLayer(BATTLE_LAYERS["arena"])
    local laneBar2 = self:spawnObject(Sprite("objects/icecreamconegame/mask_alt",x2,y1))
    laneBar2:setScale(2,y2-y1)
    laneBar2:setLayer(BATTLE_LAYERS["arena"])

    if Game:getFlag("preferanceRevealed") == true then
        -- target flavor display:
        local displayX = 450
        local displayY = 300
        local displayText = self:spawnObject(Sprite("objects/icecreamconegame/targetindicator_placeholder",displayX,displayY))
        displayText:setScale(2,2)
        displayText:setLayer(BATTLE_LAYERS["below_soul"])

        local scoopDisplayHeight = 22 + 8
        local xPrime = displayX + 60
        local yPrime = displayY - (#self.targetFlavors + 1)*scoopDisplayHeight/2
        for i,flavor in ipairs(self.targetFlavors) do
            local scoop = self:spawnObject(Sprite("objects/icecreamconegame/scoop_"..flavor,xPrime,yPrime + scoopDisplayHeight*i))
            scoop:setScale(2,2)
            scoop:setLayer(BATTLE_LAYERS["below_soul"])
        end
    end

    -- Show controls
    self.controls = self:spawnObject(ControlsDisplay(self.cone.x, self.cone.y - 20, "horiz_layout_alt"))
    self.controls:setOrigin(0.5)
    self.controls:setScale(1.4)
    self.controls:setLayer(BATTLE_LAYERS["top"])
    self.timer:after(2, function ()
        self.controls:remove()
    end)
end

function IceCreamConeGame:update()
    local write = 1
    for read = 1, #self.scoops do
        local scoop = self.scoops[read]
        if scoop.parent then
            if write ~= read then
                self.scoops[write] = scoop
            end
            write = write + 1
        end
    end
    for i = #self.scoops, write, -1 do
        self.scoops[i] = nil
    end

    if self.readyForInput then
        -- Get input and convert to a number for easy indexing into dPad stuff:
        local button = 0
        if Input.pressed("right") then
            button =  1
        end
        if Input.pressed("left") then
            button = -1
        end

        if button ~= 0 then
            self.readyForInput = false

            if Utils.between(self.stack["lane"] + button, 0, 4) then
                local w = 0
                local n = #self.stack["scoops"]
                local weight = 1
                if n <= 2 then
                    local table = {.25, .6}
                    weight = table[n]
                end

                for i,scoop in ipairs(self.stack["scoops"]) do
                    w = w + 1/(2*(n-i+1))
            
                    scoop:startSpringBack(-weight*scoop.width*button*w)
                end
            end

            self.stack["lane"] = Utils.clamp(self.stack["lane"] + button, 1, 3)
            self.cone:slideTo(self.lanePositions[self.stack["lane"]], self.cone.y, self.travelTime/30, 'linear', function()
                self.readyForInput = true
            end)
        end
    end

    if #self.stack["scoops"] >= self.targetNumber and not self.ending then
        self.timer:cancel(self.scoopTimer)
        self.readyForInput = false
        for _, scoop in ipairs(Game.battle.children) do
            if scoop:includes(IceCreamConeScoop) then
                scoop.collider.x = 10000
                scoop.physics.speed_y = 0
            end
        end
        self.ending = true
        self:preEnd()
    end

    super.update(self)
end

function IceCreamConeGame:preEnd()
    local score = 0
    local targetCounts = {}
    
    for i,targetFlavor in ipairs(self.targetFlavors) do
        targetCounts[i] = 0
        for _,scoop in ipairs(self.stack["scoops"]) do
            if scoop.flavor == targetFlavor then
                targetCounts[i] = targetCounts[i] + 1
            end
        end
        score = score + 1 + targetCounts[i]
    end

    self:score(score)

    Game.battle.encounter:setFlag("iceCreamConeScore", score)

    if Kristal.getLibConfig("moist-lib","debug_prints") then
        Kristal.Console:log(score)
        print("Ice Cream Score: "..score)
    end

    self.timer:after(1, function ()
        self.finished = true
    end)
end

function IceCreamConeGame:score(score)
    local msg = ""
    local snd = "error"

    if score >= 6 then
        msg = "Perfect"
        snd = "snd_perfect"
        CustScore:addPoints(5)
        Game.battle:getEnemyBattler("licket").metrecs = true
        
        
        if Kristal.getLibConfig("moist-lib","debug_prints") then
            Kristal.Console:log("All good flavour")
            print("All good flavour")
        end
    elseif score >= 5 then
        msg = "Great"
        snd = "snd_great"
        CustScore:addPoints(4)
        Game.battle:getEnemyBattler("licket").metrecs = true

        if Kristal.getLibConfig("moist-lib","debug_prints") then
            Kristal.Console:log("Mostly Good Flavour")
            print("Mostly Good Flavour")
        end
    elseif score >= 4 then
        msg = "Great"
        snd = "snd_great"
        CustScore:addPoints(3)
        Game.battle:getEnemyBattler("licket").metrecs = true
        
        if Kristal.getLibConfig("moist-lib","debug_prints") then
            Kristal.Console:log("Half Good Flavour")
            print("Half Good Flavour")
        end        
    elseif score >= 3 then
        msg = "Okay"
        snd = "snd_good"
        CustScore:addPoints(2)
        
        if Kristal.getLibConfig("moist-lib","debug_prints") then
            Kristal.Console:log("Some Good Flavour")
            print("Some Good Flavour")
        end
    else
        CustScore:addPoints(1)
        if MathUtils.random() > 0.25 then
            msg = "Bad"
        else
            msg = ":("
        end
        snd = "error"

        if Kristal.getLibConfig("moist-lib","debug_prints") then
            Kristal.Console:log("Bad Flavour")
            print("Bad Flavour")
        end
    end

    self:scoreMessage(msg, 320, 200)
    Assets.playSound(snd, 0.6, 1.2)
end

return IceCreamConeGame