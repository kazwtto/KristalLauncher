local Mantle, super = Class(Wave, "mantle_10")

function Mantle:init()
    super.init(self)

    -- self:setArenaPosition(318, 102)
    -- self:setArenaSize(372, 284)
    self:setArenaSize(322, 212)

    Game.battle.battle_ui:transitionOut()
    Game.battle.tension_bar:hide()

    self.time = -1
    self.fader = nil
    self.board = nil
    self.vignette = nil
    self.text = nil
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

    local text = Text("[font:8bit]SEM CONTROLE", Game.battle.arena.x - 109, Game.battle.arena.y - 20)
    -- text:setOrigin(.5, .5)
    text.layer = BATTLE_LAYERS["top"] + 1
    Game.battle:addChild(text)

    local text2 = Text("[font:8bit]CONECTADO", Game.battle.arena.x - 79, Game.battle.arena.y + 4)
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
        static.visible = false

        --[[self.timer:after(2, function()
            text:remove()
            Assets.playSound("static", 1, 1.25)
            static.visible = true

            self.timer:after(.75, function()
                self.board.color = {.96, .96, .96}
                local text = Text("[font:8bit]NO HEAD IS", Game.battle.arena.x - 89, Game.battle.arena.y - 20)
                text.layer = BATTLE_LAYERS["top"] + 1
                Game.battle:addChild(text)

                Assets.playSound("nocontroller", 1, .97)
                static.visible = false

                self.timer:after(2.15, function()
                    text:remove()
                    Assets.playSound("static", 1, 1.25)
                    static.visible = true

                    self.timer:after(.75, function()
                        self.board.color = {.93, .93, .93}
                        local text = Text("[font:8bit]NO BODY IS", Game.battle.arena.x - 89, Game.battle.arena.y - 20)
                        text.layer = BATTLE_LAYERS["top"] + 1
                        Game.battle:addChild(text)

                        Assets.playSound("nocontroller", 1, .94)
                        static.visible = false]]

                        self.timer:after(2.25, function()
                            text:remove()
                            text2:remove()
                            Assets.playSound("static", 1, 1.25)
                            static.visible = true

                            self.timer:after(.75, function()
                                self.board.color = {.87, .87, .87}
                                static.visible = false

                                self.timer:after(1.5, function()
                                    static.visible = false
                                    Game.battle:addFX(BoardFX(2), "board1")

                                    local text = Text("[font:8bit]VOCÊ", Game.battle.arena.x - 26, Game.battle.arena.y - 12)
                                    text.layer = BATTLE_LAYERS["top"] + 1
                                    Game.battle:addChild(text)

                                    Assets.playSound("hurt", 2)
                                    Assets.playSound("impact")
                                    Assets.playSound("static", .4, 1.25)
                                    self.board.color = {.67, .67, .67}

                                    self.timer:after(.75, function()
                                        Game.battle:addFX(BoardFX(3), "board2")
                                        Assets.stopSound("static")
                                        text:remove()

                                        local text1 = Text("[font:8bit]VOCÊ", Game.battle.arena.x - 26, Game.battle.arena.y - 20)
                                        text1.layer = BATTLE_LAYERS["top"] + 1
                                        Game.battle:addChild(text1)
                                        local text2 = Text("[font:8bit]ESTÁ", Game.battle.arena.x - 26, Game.battle.arena.y)
                                        text2.layer = BATTLE_LAYERS["top"] + 1
                                        Game.battle:addChild(text2)

                                        Assets.playSound("hurt", 3)
                                        Assets.playSound("impact")
                                        Assets.playSound("static", .8, 1.25)
                                        self.board.color = {.47, .47, .47}

                                        self.timer:after(.75, function()
                                            Game.battle:addFX(BoardFX(4), "board3")
                                            Assets.stopSound("static")
                                            text1:remove()
                                            text2:remove()

                                            local text1 = Text("[font:8bit]VOCÊ", Game.battle.arena.x - 26, Game.battle.arena.y - 32)
                                            text1.layer = BATTLE_LAYERS["top"] + 1
                                            Game.battle:addChild(text1)
                                            local text2 = Text("[font:8bit]ESTÁ", Game.battle.arena.x - 26, Game.battle.arena.y - 12)
                                            text2.layer = BATTLE_LAYERS["top"] + 1
                                            Game.battle:addChild(text2)
                                            local text3 = Text("[font:8bit]DESCONECTADO", Game.battle.arena.x - 96, Game.battle.arena.y + 8)
                                            text3.layer = BATTLE_LAYERS["top"] + 1
                                            Game.battle:addChild(text3)

                                            Assets.playSound("hurt", 4)
                                            Assets.playSound("impact")
                                            Assets.playSound("static", 1.4)
                                            self.board.color = {.27, .27, .27}

                                            self.timer:after(1, function()
                                                self:spawnBullet("mantle/shelterkey", 18, SCREEN_HEIGHT - 18)
                                                self.board.visible = false
                                                self.vignette.visible = false
                                                self.text = {text1, text2, text3}

                                                Assets.stopSound("hurt")
                                                Assets.stopSound("impact")
                                                Assets.stopSound("static")
                                                Game.battle:removeFX("board")
                                                Game.battle:removeFX("board1")
                                                Game.battle:removeFX("board2")
                                                Game.battle:removeFX("board3")

                                                self.board.color = {0, 0, 0}
                                                self:setArenaPosition(math.huge, math.huge)

                                                self.timer:after(15, function()
                                                    self.time = 1
                                                end)

                                                --[[self.timer:after(1.5, function()
                                                    Assets.playSound("greatshine", 1, .5)
                                                    Assets.playSound("secret_normal", 1.75)
                                                end)]]
                                            end)
                                        end)
                                    end)
                                end)
                            end)
                        end)
                    --[[end)
                end)
            end)
        end)]]
    end)

    -- Game.battle.mask.alpha = 0
    Game.battle.arena.color = {0, 0, 0}
    Game.battle:addFX(BoardFX(1), "board")

    Game.battle.arena.x = Game.battle.arena.x + 2

    Game.battle:swapSoul(Soul())
end

function Mantle:onEnd()
    Assets.stopSound("getkey", true)
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

        Assets.playSound("ominoux")
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
        Game.battle.enemies[1]:addMercy(8)
    end)
end

function Mantle:update()
    super.update(self)
end

return Mantle
