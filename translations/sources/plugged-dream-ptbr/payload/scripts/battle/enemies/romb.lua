local Romb, super = Class(EnemyBattler)

function Romb:init()
    super.init(self)

    self.name = "RAMBHACK"
    self:setActor("romb")

    self.max_health = 5500
    self.health = 5500
    self.money = 0
    if Mod.flags.DIFFICULTY == "CASUAL" then
        self.attack = 8
        self.defense = -16
    else
        self.attack = 12
        self.defense = -12
    end

    self.exit_on_defeat = false
    self.auto_spare = true
    self.spare_points = 0
    self.tired_percentage = 0

    self.shake_progress = 0
    self.connect_progress = 0
    self.connected = false
    self.ngp = false

    self.idle_moves = true
    self.old_x = self.x
    self.old_y = self.y
    self.ease = false
    self.ease_timer = 0
    self.timer = 0

    self.tired = true
    self.comment = "(Cansado)"

    self.waves = {
        "romb/wireshake",
        "romb/wireshake2",
        "romb/plugs",
        "romb/plugs2",
        "romb/extensioncord",
        "romb/extensioncord2",
        "romb/electribox",
        "romb/electribox_plugs",
        "romb/secondplayer",
        "romb/killpurple",
        "romb/killpurple2",
        "romb/killpurple3",
    }

    defeat_type = "fatal"

    self.dialogue = {
        "...",
    }

    self.check = "Acredite em mim, [wait:5]não há por que chorar. [wait:10]\n* Nada."

    self.text = {
        "* Aperte [bind:confirm] para usar a espada.",
        "* A respiração acelera junto com a lâmina.",
        "* Cheiro de plástico queimado.",
        "* Dá para ouvir vozes abafadas saindo do plugue.",
        "* Os fios estão todos embolados.",
        "* Sem controle conectado. [wait:8]\n* Sem cabeça conectada. [wait:8]\n* Sem rosto conectado.",
        "* O ar crepita com liberdade.",
        "* Um último jogo.",
        "* A criatura olha pro céu.[wait:5].[wait:5].[wait:5] \n* Não há nada lá em cima.",
        "* A criatura não consegue ver nada.[wait:5] \n* Nada além de você.",
        "* A criatura tampa os ouvidos conforme o chiado aumenta.",
        "* A criatura está com sede de sangue.[wait:10] \n* (Não literalmente.)",
        "* Dá para ouvir vozes do plugue. [wait:5]\n* São muitas.",
        "* Está se divertindo?",
    }
    self.low_health_text = "* A criatura tenta gritar, [wait:5]mas não consegue."

    -- NOME do ato DEVE ser o id original (usado em onAct/onActStart/removeAct)
    -- Apenas a descrição é display text e pode ser traduzida
    self:registerAct("Shake", "Induzir \nPiedade", "kris")
    self:registerAct("X-Slash", "Dano \nFísico", "kris", 35)
end

function Romb:onActStart(battler, name)
    if name == "Shake" and self.shake_progress < 3 then
        battler:setActSprite("acts/werewire/wiggle/kris", -2, -7, 4/30, true)
    else
        super.onActStart(self, battler, name)
    end
end

function Romb:onAct(battler, name)
    if name == "Shake" then
        self.shake_progress = self.shake_progress + 1
        if self.shake_progress == 1 then
            self.defense = -8
            self:addMercy(3)
            Game.battle:startActCutscene("romb", "shake1")
        elseif self.shake_progress == 2 then
            self.defense = -4
            self:addMercy(3)
            Game.battle:startActCutscene("romb", "shake2")
        elseif self.shake_progress == 3 then
            self.defense = 2
            self:addMercy(2)
            Game.battle:startActCutscene("romb", "shake3")
            self:removeAct("Shake")
            self:removeAct("X-Slash")
            self:registerAct("Connect", "Usar\nControle", "kris", 35)
            self:registerAct("CheatHeal", "Curar com \no Controle", "kris", 35)
            self:registerAct("X-Slash", "Dano \nFísico", "kris", 35)
        else
            Game.battle:startActCutscene("romb", "shake4")
        end
    elseif name == "Connect" then
        if self.connect_progress == 0 then
            Game.battle:startActCutscene("romb", "connect1")
        elseif self.connect_progress == 1 then
            Game.battle:startActCutscene("romb", "connect2")
        elseif self.connect_progress == 2 then
            Game.battle:startActCutscene("romb", "connect3")
        elseif self.connect_progress == 3 then
            Game.battle:startActCutscene("romb", "connect4")
        elseif self.connect_progress == 4 then
            Game.battle:startActCutscene("romb", "connect5")
        elseif self.connect_progress == 5 then
            Game.battle:startActCutscene("romb", "connect6")
        elseif self.connect_progress == 6 then
            Game.battle:startActCutscene("romb", "connect7")
        elseif self.connect_progress == 7 then
            Game.battle:startActCutscene("romb", "connect8")
        elseif self.connect_progress == 8 then
            Game.battle:startActCutscene("romb", "connect9")
        elseif self.connect_progress == 9 then
            Game.battle:startActCutscene("romb", "connect10")
        elseif self.connect_progress == 10 then
            Game.battle:startActCutscene("romb", "connect11")
        elseif self.connect_progress == 11 then
            Game.battle:startActCutscene("romb", "mercy")
        else
            Game.battle:startActCutscene("romb", "connect1")
        end
        self.connect_progress = self.connect_progress + 1
        self.dialogue_override = ''
    elseif name == "CheatHeal" then
        Game.battle:startActCutscene("cheatheal")
    elseif name == "X-Slash" then
        local user = "kris"
        local user_index = Game.battle:getPartyIndex(user)
        local user_battler = Game.battle:getPartyBattler(user)
        local spell = Registry.createSpell("xslash")
        local target = self
        local menu_item = {
            data = spell,
            tp = 0,
        }
        Game.battle:pushAction("SPELL", target, menu_item, user_index)
        Game.battle:markAsFinished(nil, {user})

        self.attack = self.attack - .5
        self.defense = self.defense - .5
    end
    return super.onAct(self, battler, name)
end

function Romb:spawnSpeechBubble(...)
    local text, options = ...

    if (type(text) == "string" or type(text) == "table") and #text == 0 then
        return nil
    end

    if not Game.battle.cutscene then
        local x, y = self.sprite:getRelativePos(0, self.sprite.height/2, Game.battle)
        if self.dialogue_offset then
            x = x + self.dialogue_offset[1]
            y = y + self.dialogue_offset[2]
        end

        local textbox = WerewireTextbox(x, y)
        Game.battle:addChild(textbox)
        return textbox
    else
        return super.spawnSpeechBubble(self, text, options)
    end
end

--[[function Romb:getNameColors()
    local result = {}
    local tiredcol = {0, 0.7, 1}
    table.insert(result, tiredcol)

    return result
end]]

function Romb:update()
    super.update(self)

    if self.idle_moves == true then
        if not self.done_state and Game.battle:getState() ~= "TRANSITION" then
            self.timer = self.timer + DTMULT
            self.x = 500

            local amplitude = 8
            local speed = 0.035
            self.y = 200 + math.sin(self.timer * speed) * amplitude
        end
    end
end

function Romb:onDefeat(damage, battler)
    -- Game.world.music:stop()
    -- self:defeat("VIOLENCED")

    self.idle_moves = false
    if Game.battle.battle_ui.attacking then
        Game.battle.battle_ui:endAttack()
    end

    Game.battle:setState("CUTSCENE")

    Game.battle:startActCutscene("romb", "fight")

    Game.battle:resetAttackers();
    Game.battle.processing_action = false

    Game.battle.should_finish_action = false
    Game.battle.on_finish_keep_animation = nil
    Game.battle.on_finish_action = nil
end

return Romb
