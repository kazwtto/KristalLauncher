local StirGame, super = Class(LightWave)

function StirGame:init()
    super.init(self, _s("minigame_popup-stirgame", "STIR!"), "full_layout_alt")

    self:setArenaSize(300,300)
    self:setArenaPosition(320,240)
    self.time = 10
    
    self.ellipseRatio = 3.2
    
    -- todo: add soup stuff to pot
    --  - stuff will orbit with slower angular velocity when nearer to the center
    --  - bubbles spawn and pop at random spots
    --  
    -- add arrow key prompts to clarify controls/help with timing
    --  - 
    -- todo: fix enemy dialogue causing issues at start of wave before arena resizes
end

function StirGame:onStart()

    Game.battle.soul.visible = false

    local centerX = (Game.battle.arena.left + Game.battle.arena.right) / 2
    local bottomY = Game.battle.arena.bottom
    
    self.pot = self:spawnObject(Sprite("objects/stirringgame/newpot", centerX, bottomY))
    self.pot:setLayer(BATTLE_LAYERS["above_arena"])
    self.pot:setOrigin(0.5, 1)
    self.pot:setScale(2,2)

    self.maskObj = self.pot:addChild(Sprite("objects/stirringgame/potmask"))
    self.maskObj.visible = false
    self.mask = MaskFX(self.maskObj)

    self.waves = self:spawnWaves(1, centerX, bottomY - 140, .75)
    self.waves:addFX(self.mask)

    self.spoon = self:spawnObject(StirSpoon(centerX, bottomY - 120, 44, self.ellipseRatio))
    self.spoon:setLayer(BATTLE_LAYERS["below_soul"])


    -- Every 0.33 seconds...
    self.bubbles = {}
    self.timer:every(1/3, function()
        --local x = Utils.random(centerX - 64, centerX + 64)
        local y = Utils.random(bottomY - 100, bottomY - 6)
        local r = Utils.random(32,56)
        local theta = Utils.random(0,2*math.pi)
        --local n = 1 + 2*Utils.random(3,7,1)
        local n = 1

        local bubble = self:spawnObject(SoupBubble(centerX, y, r, r/self.ellipseRatio, 1, n, theta, bottomY - 140))
        bubble:setLayer(BATTLE_LAYERS["below_soul"])

        table.insert(self.bubbles, bubble)
    end)
end

function StirGame:spawnWaves(layer,x,y,xv)
    local wave = self:spawnObject(Sprite("objects/stirringgame/soupwave", x, y))
    wave:setLayer(BATTLE_LAYERS["arena"] + layer)
    wave:setScale(2,2)
    wave:setOrigin(0,1)
    wave.wrap_texture_x = true

    wave.physics.speed_x = xv

    return wave
end

function StirGame:update()
    -- Code here gets called every frame
    local bubble_write = 1
    for bubble_read = 1, #self.bubbles do
        local bubble = self.bubbles[bubble_read]
        if bubble.parent then
            self.bubbles[bubble_write] = bubble
            bubble_write = bubble_write + 1
            local r = 1 - math.abs(bubble.rx - self.spoon.rx) / self.spoon.rx
            bubble.velocity = r*self.spoon.velocity
        end
    end
    for i = #self.bubbles, bubble_write, -1 do
        self.bubbles[i] = nil
    end

    super.update(self)
end

--function StirGame:onArenaExit()
function StirGame:onEnd()
    Game.battle.encounter:setFlag("LastTurnStirrin", true)
    Game.battle.encounter:setFlag("StirScore", 2*math.abs(self.spoon.theta) / math.pi)
end

return StirGame