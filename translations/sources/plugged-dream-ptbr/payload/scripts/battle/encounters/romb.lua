local MyEncounter, super = Class(Encounter)

function MyEncounter:init()
    super.init(self)

    self.romb = self:addEnemy("romb", 500, 200)

    self.text = "* Uma última aventura aguarda.[wait:5] \n* (Aperte [bind:confirm] para destruir projéteis [color:purple]roxos[color:reset] com a lâmina.)"
    self.music = "ramb_boss"

    self.background = false
    self.no_end_message = true
    self.default_xactions = false

    self.phase = 1
    self.phase_previous = 1
    self.turn = 1

    for _, follower in ipairs(Game.world.followers) do
        follower:setColor(0.25, 0.25, 0.25)
    end
end

function MyEncounter:onBattleInit()
    super.onBattleInit(self)

    for _, party in ipairs(Game.battle.party) do
        party.sprite:setColor(0.25, 0.25, 0.25)
        party.overlay_sprite:setColor(0.25, 0.25, 0.25)
    end
    for _, enemy in ipairs(Game.battle.enemies) do
        enemy:setColor(0.25, 0.25, 0.25)
    end
end

function MyEncounter:createSoul()
    return GridSoul()
end

function MyEncounter:getPartyPosition(index)
    local x, y = 0, 0
    if index == 1 then
        x = 130
        y = 295
    elseif index == 2 then
        x = 85
        y = 298
    elseif index == 3 then
        x = 40
        y = 301
    else
        x = -1
        y = -1
    end
    return x, y
end

function MyEncounter:checkProgress(mercy, health)
    if self.romb.mercy >= mercy then return true end
    if self.romb.health <= health then return true end
    return false
end

function MyEncounter:onActionsEnd()
    if not self:checkProgress(100, 0) then
        self.phase_previous = self.phase
        if self.turn == math.huge then
            if self:checkProgress(75, self.romb.max_health*0.25) then
                self.turn = 1
                self.phase = 4
            elseif self:checkProgress(50, self.romb.max_health*0.5) then
                self.turn = 1
                self.phase = 3
            elseif self:checkProgress(25, self.romb.max_health*0.75) then
                self.turn = 1
                self.phase = 2
            end
        end
        self.phase_previous = self.phase

        if self.romb.connected == true then
            if self.romb.connect_progress == 1 then
                Game.battle.enemies[1].wave_override = "mantle_1"
            elseif self.romb.connect_progress == 2 then
                Game.battle.enemies[1].wave_override = "mantle_2"
            elseif self.romb.connect_progress == 3 then
                Game.battle.enemies[1].wave_override = "mantle_3"
            elseif self.romb.connect_progress == 4 then
                Game.battle.enemies[1].wave_override = "mantle_4"
            elseif self.romb.connect_progress == 5 then
                Game.battle.enemies[1].wave_override = "mantle_5"
            elseif self.romb.connect_progress == 6 then
                Game.battle.enemies[1].wave_override = "mantle_6"
            elseif self.romb.connect_progress == 7 then
                Game.battle.enemies[1].wave_override = "mantle_7"
            elseif self.romb.connect_progress == 8 then
                Game.battle.enemies[1].wave_override = "mantle_8"
            elseif self.romb.connect_progress == 9 then
                Game.battle.enemies[1].wave_override = "mantle_9"
            elseif self.romb.connect_progress == 10 then
                Game.battle.enemies[1].wave_override = "mantle_10"
            elseif self.romb.connect_progress == 11 then
                Game.battle.enemies[1].wave_override = "mantle_11"
            else
                Game.battle.enemies[1].wave_override = "mantle_0"
            end
        else
            if self.phase == 1 then
                do -- Useless block because it used to be "if not self.loop == true then...", like what does that even mean?
                    if self.turn == 1 then
                        Game.battle.enemies[1].wave_override = "romb/wireshake"
                    elseif self.turn == 2 then
                        Game.battle.enemies[1].wave_override = "romb/plugs"
                    elseif self.turn == 3 then
                        Game.battle.enemies[1].wave_override = "romb/extensioncord"
                    elseif self.turn == 4 then
                        Game.battle.enemies[1].wave_override = "romb/killpurple"
                        self.turn = math.huge
                    else
                        Game.battle.enemies[1].wave_override = Utils.pick{"romb/wireshake", "romb/plugs", "romb/extensioncord", "romb/killpurple"}
                    end
                end
            elseif self.phase == 2 then
                do -- Useless block because it used to be "if not self.loop == true then...", like what does that even mean?
                    if self.turn == 1 then
                        Game.battle.enemies[1].wave_override = "romb/electribox"
                    elseif self.turn == 2 then
                        Game.battle.enemies[1].wave_override = "romb/secondplayer_easy"
                    elseif self.turn == 3 then
                        Game.battle.enemies[1].wave_override = "romb/plugs2"
                    elseif self.turn == 4 then
                        Game.battle.enemies[1].wave_override = "romb/killpurple2"
                        self.turn = math.huge
                    else
                        Game.battle.enemies[1].wave_override = Utils.pick{"romb/extensioncord", "romb/electribox", "romb/secondplayer", "romb/plugs2", "romb/killpurple2"}
                    end
                end
            elseif self.phase == 3 then
                do -- Useless block because it used to be "if not self.loop == true then...", like what does that even mean?
                    if self.turn == 1 then
                        Game.battle.enemies[1].wave_override = "romb/wireshake2"
                    elseif self.turn == 2 then
                        Game.battle.enemies[1].wave_override = "romb/extensioncord2"
                    elseif self.turn == 3 then
                        Game.battle.enemies[1].wave_override = "romb/electribox_plugs"
                    elseif self.turn == 4 then
                        Game.battle.enemies[1].wave_override = "romb/killpurple3"
                        self.turn = math.huge
                    else
                        Game.battle.enemies[1].wave_override = Utils.pick{"romb/wireshake2", "romb/electribox_plugs", "romb/extensioncord2", "romb/killpurple3"}
                    end
                end
            elseif self.phase == 4 then
                do -- Useless block because it used to be "if not self.loop == true then...", like what does that even mean?
                    if self.turn == 1 then
                        if self.romb.ngp == false then
                            Game.battle.enemies[1].wave_override = "romb/finale"
                        else
                            Game.battle.enemies[1].wave_override = Utils.pick{"romb/wireshake2", "romb/electribox_plugs", "romb/electribox"}
                        end
                    elseif self.turn == 2 then
                        Game.battle.enemies[1].wave_override = Utils.pick{"romb/secondplayer", "romb/extensioncord", "romb/extensioncord2"}
                    elseif self.turn == 3 then
                        Game.battle.enemies[1].wave_override = Utils.pick{"romb/plugs", "romb/electribox_plugs", "romb/plugs2"}
                    elseif self.turn == 4 then
                        Game.battle.enemies[1].wave_override = Utils.pick{"romb/killpurple2", "romb/killpurple3"}
                        self.turn = math.huge
                    else
                        Game.battle.enemies[1].wave_override = Utils.pick{"romb/wireshake2", "romb/electribox_plugs", "romb/extensioncord2", "romb/killpurple3"}
                    end
                end
            end
        end
    end
end

function MyEncounter:onTurnEnd()
    if self.romb.connected == false then
        self.turn = self.turn + 1
    else
        self.romb.connected = false
    end
end

return MyEncounter
