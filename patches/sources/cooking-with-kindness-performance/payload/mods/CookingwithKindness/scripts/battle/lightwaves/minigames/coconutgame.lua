local CoconutGame, super = Class("LightMinigameWave")

function CoconutGame:init()
    super.init(self, _s("minigame_popup-coconutgame", "COCONUT!"), "horiz_layout")

    self.time = 10
    self:setArenaSize(500,140)
    

    self.step = 0
    
    -- todo: fix enemy dialogue causing issues at start of wave before arena resizes
end

function CoconutGame:onStart()
    -- Every 0.33 seconds...
    self.printed = false
    
    local centerX = (Game.battle.arena.left + Game.battle.arena.right) / 2
    --local centerY = (Game.battle.arena.bottom + Game.battle.arena.top) / 2
    local centerY = Game.battle.arena.bottom - 4
    
    self.maskObj = self:spawnObject(Sprite("objects/coconutgame/mask"))
    self.maskObj:setLayer(BATTLE_LAYERS["above_soul"])
    self.maskObj.x = Game.battle.arena.left
    self.maskObj.y = Game.battle.arena.top
    self.maskObj:setScale(Game.battle.arena.right-Game.battle.arena.left, Game.battle.arena.bottom-Game.battle.arena.top)
    self.maskObj.visible = false

    self.mask = MaskFX(self.maskObj)

    self.birb = self:spawnObject(CoconutBird(centerX+6, Game.battle.arena.top))
    self.birb:setLayer(BATTLE_LAYERS["above_arena"])


    self.treeIsland, self.coconut = self:spawnTreeIsland(4,Game.battle.arena.left + 12)
    self.rockIsland, self.rock    = self:spawnRockIsland(4,Game.battle.arena.right - 102)
    
    
    local spout = self:spawnObject(CoconutWaterspout(centerX - 40, centerY))
    spout:setLayer(BATTLE_LAYERS["below_soul"]) 
    
    self.obstacleSources = {spout}


    self.bgWaves = self:spawnWaves(1,4,3,1)
    self.fgWaves = self:spawnWaves(6,0,0,.8)


    self.birb:addFX(self.mask)
    self.coconut:addFX(self.mask)
    
    self.bgWaves:addFX(self.mask)
    self.fgWaves:addFX(self.mask)

    for _,obstacle in ipairs(self.obstacleSources) do
        obstacle:addFX(self.mask)
    end
end

function CoconutGame:spawnTreeIsland(layer,x)
    local island = self:spawnObject(Sprite("objects/coconutgame/treeIsland", x, Game.battle.arena.bottom))
    island:setLayer(BATTLE_LAYERS["arena"] + layer)
    island:setScale(2,2)
    island:setOrigin(0,1)

    local tree = island:addChild(Sprite("objects/coconutgame/palmTree", 17, 6))
    tree:setLayer(BATTLE_LAYERS["arena"] + layer - 1)
    tree:setOrigin(0.5,1)

    local coconut = self:spawnObject(Sprite("objects/coconutgame/coconut", island.x + 56, island.y - 34))
    coconut:setLayer(BATTLE_LAYERS["arena"] + layer)
    coconut:setScale(2,2)
    coconut:setOrigin(0.5,0.5)
    coconut:setHitbox(0,0,coconut.width,coconut.height)

    return island, coconut
end

function CoconutGame:spawnRockIsland(layer,x)
    local island = self:spawnObject(Sprite("objects/coconutgame/rockIsland", x, Game.battle.arena.bottom))
    island:setLayer(BATTLE_LAYERS["arena"] + layer)
    island:setScale(2,2)
    island:setOrigin(0,1)

    local rock = island:addChild(Sprite("objects/coconutgame/rock", 20, 6))
    rock:setLayer(BATTLE_LAYERS["arena"] + layer - 1)
    rock:setOrigin(0.5,1)
    rock:setHitbox(0,0,18,11)

    return island, rock
end

function CoconutGame:spawnWaves(layer,x,y,xv)
    local wave = self:spawnObject(Sprite("objects/coconutgame/wave", x, Game.battle.arena.bottom - y))
    wave:setLayer(BATTLE_LAYERS["arena"] + layer)
    wave:setScale(2,2)
    wave:setOrigin(0,1)
    wave.wrap_texture_x = true

    wave.physics.speed_x = xv

    return wave
end

function CoconutGame:update()
    -- Code here gets called every frame
    self.birb:handleInput()
    
    if not self.printed then 
        self.printed = true
        Kristal.Console:log("wave update!")
    end

    Object.startCache()
    if not self.birb.isHit then
        for _,obstacle in ipairs(self.obstacleSources) do
            for _,obj in ipairs(obstacle.children) do
                if obj:collidesWith(self.birb) then
                    self.birb:hit()
                end
            end
        end
    end
    
    if self.step == 0 then
        -- draw arrow pointing to coconut
        
        if self.birb:collidesWith(self.coconut) then
            self.step = 1
            self.birb:getCoconut(self.coconut)
        end
    elseif self.step == 1 then
        -- draw thing to indicate drop area

        -- when bird drops coconut, go to next step
        if self.birb.hasCoconut == nil then
            self.step = 2
        end
    elseif self.step == 2 then
        if self.coconut:collidesWith(self.rock) then
            self.coconut:explode()
        end
    end
    Object.endCache()

    super.update(self)
end

--function CoconutGame:onArenaExit()
function CoconutGame:onEnd()
    --Game.battle.encounter:setFlag("LastTurnStirrin", true)
    --Game.battle.encounter:setFlag("StirScore", 2*math.abs(self.objSpoon.theta) / math.pi)
end

return CoconutGame