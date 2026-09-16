local Mantle, super = Class(Wave, "errortest")

function Mantle:init()
    super.init(self)

    -- self:setArenaPosition(318, 102)
    -- self:setArenaSize(372, 284)
    self:setArenaSize(322, 212)

    Game.battle.battle_ui:transitionOut()
    Game.battle.tension_bar:hide()

    self.time = 2
    self.fader = nil
    self.board = nil
    self.vignette = nil
    self.text = nil
    self.monsters_killed = 0
    self.waitVar = 0
end

function Mantle:onStart()
    local fader = Rectangle(-32, -32, SCREEN_WIDTH + 32, SCREEN_HEIGHT + 32)
    fader.color = {0, 0, 0}
    fader.parallax_x = 0
    fader.parallax_y = 0
    fader.layer = BATTLE_LAYERS["below_arena"]
    Game.battle:addChild(fader)
    self.fader = fader

    local bg = Sprite("mantle/error", Game.battle.arena.left - 26, Game.battle.arena.top - 36)
    bg.layer = BATTLE_LAYERS["top"] - 10
    -- bg.color = {0,0,1}
    Game.battle:addChild(bg)
    self.board = bg

    local vignette = Sprite("mantle/vignette", 0, -10)
    vignette.layer = BATTLE_LAYERS["top"]
    Game.battle:addChild(vignette)
    self.vignette = vignette

    local text = Text("[font:8bit]NÃO ESTÁ ESQUECENDO", Game.battle.arena.x - 169, Game.battle.arena.y - 20)
    -- text:setOrigin(.5, .5)
    text.layer = BATTLE_LAYERS["top"] + 1
    Game.battle:addChild(text)

    local text2 = Text("[font:8bit]DE ALGO IMPORTANTE?", Game.battle.arena.x - 169, Game.battle.arena.y + 4)
    -- text2:setOrigin(.5, .5)
    text2.layer = BATTLE_LAYERS["top"] + 1
    Game.battle:addChild(text2)

    self.text = {text, text2}

    Assets.playSound("static", 1, 1.25)
    local static = Sprite("static", 0, 0)
    static.layer = BATTLE_LAYERS["top"] + 10
    static.scale_x = 2
    static.scale_y = 2
    static:play(5/60, true)
    Game.battle:addChild(static)
    Game.battle.music:pause()
    self.timer:after(.75, function()
        Assets.playSound("nocontroller")
        static:remove()
    end)

    -- Game.battle.mask.alpha = 0
    Game.battle.arena.color = {0, 0, 0}
    Game.battle:addFX(BoardFX(1), "board")

    Game.battle.arena.x = Game.battle.arena.x + 2

    -- Game.battle:swapSoul(Soul())
end

function Mantle:onEnd()
    Assets.stopSound("nocontroller", true)
    Game.battle:removeFX("board")
    -- Game.battle.music:play("ramb_boss")
    self.fader:remove()
    self.board:remove()
    self.vignette:remove()
    for _, t in ipairs(self.text) do
        t:remove()
    end

    Assets.playSound("static", 1, 1.5)
    local static = Sprite("static", 0, 0)
    static.layer = BATTLE_LAYERS["top"] + 10
    static.scale_x = 2
    static.scale_y = 2
    static:play(5/60, true)
    Game.battle:addChild(static)
    Game.battle.timer:after(.5, function()
        static:remove()
        Game.battle.music:resume()

        --[[Assets.playSound("ominoux")
        if Game.party[1] then
            if Game.party[1].stats.health >= 184 then
                Game.party[1].stats.health = Game.party[1].stats.health + 4
                Game.party[1].health = Game.party[1].health + 4
                Game.party[1].max_stats.health = Game.party[1].max_stats.health + 4
            else
                Game.party[1].stats.health = Game.party[1].stats.health + 3
                Game.party[1].health = Game.party[1].health + 3
                Game.party[1].max_stats.health = Game.party[1].max_stats.health + 3
            end
        end
        Game.battle.enemies[1]:addMercy(8)]]

    end)
end

function Mantle:update()
    if self.monsters_killed >= 53 then
        self.waitVar = self.waitVar + 1 * DTMULT;
        if (self.waitVar > 15) then
            self.time = 0;
            return
        end
    end
    super.update(self)
end

return Mantle
