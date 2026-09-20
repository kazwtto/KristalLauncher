---@class LightBattle : LightBattle
local LightBattle, super = HookSystem.hookScript(LightBattle)

local MENU_WAVE_STATES = {
    ACTIONSELECT = true,
    MENUSELECT = true,
    ENEMYSELECT = true,
    PARTYSELECT = true,
    FLEEING = true,
    FLEEFAIL = true,
}

local FADE_RESET_STATES = {
    TURNDONE = true,
    DEFENDINGEND = true,
    ACTIONSELECT = true,
    ACTIONS = true,
    VICTORY = true,
    TRANSITIONOUT = true,
    BATTLETEXT = true,
    FLEEING = true,
    FLEEFAIL = true,
    BUTNOBODYCAME = true,
}

function LightBattle:init()
    super.init(self)
    self.once = true

    self._cwk_child_layers = setmetatable({}, {__mode = "k"})
    self._cwk_child_is_battler = setmetatable({}, {__mode = "k"})

end

function LightBattle:sortChildren()
    table.stable_sort(self.children, function(a, b)
        return a.layer < b.layer or (a.layer == b.layer and (a:includes(Battler) and b:includes(Battler)) and a.y < b.y)
    end)
end

function LightBattle:updateChildren()
    local needs_rebuild = next(self.children_to_remove) ~= nil
    local needs_sort = needs_rebuild
    local current_layer = nil
    local last_battler_y = nil

    for _, child in ipairs(self.children) do
        local old_layer = self._cwk_child_layers[child]
        local is_battler = self._cwk_child_is_battler[child]

        if is_battler == nil then
            is_battler = child:includes(Battler)
            self._cwk_child_is_battler[child] = is_battler
        end

        if old_layer == nil or old_layer ~= child.layer then
            needs_sort = true
        end

        if current_layer ~= child.layer then
            current_layer = child.layer
            last_battler_y = nil
        end

        if is_battler then
            if last_battler_y ~= nil and child.y < last_battler_y then
                needs_sort = true
            end
            last_battler_y = child.y
        end

        self._cwk_child_layers[child] = child.layer
    end

    if needs_rebuild then
        self:updateChildList()
    elseif needs_sort then
        self:sortChildren()
    end

    -- magical-glass sets this to true unconditionally every frame.
    -- Real structural/layer changes are detected above, so don't let that
    -- unconditional flag force updateChildList()/stable_sort every frame.
    self.update_child_list = false

    for _, effect in ipairs(self.draw_fx) do
        effect:update()
    end
    for _, child in ipairs(self.children) do
        if child.active and child.parent == self and Game.battle == self then
            child:fullUpdate()
        end
    end
end


function LightBattle:draw()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", -8, -8, SCREEN_WIDTH + 16, SCREEN_HEIGHT + 16)

    local fully_covered = self.state == "TRANSITION" and self.fader and self.fader.alpha >= 1

    if fully_covered then
        self:drawChildren(self.fader.layer)
    else
        if self.encounter.background then
            self.encounter:drawBackground()
        end
        self:drawChildren()
    end

    self.encounter:draw()

    if DEBUG_RENDER then
        self:drawDebug()
    end
end

function LightBattle:startActCutscene(group, id, dont_finish)
    local action = self:getCurrentAction()
    local cutscene
    if type(id) ~= "string" then
        dont_finish = id
        cutscene = self:startCutscene(group, self.party[action.character_id], action.target)
    else
        cutscene = self:startCutscene(group, id, self.party[action.character_id], action.target)
    end
    return cutscene:after(function()
        if not dont_finish then
            self:finishAction(action)
        end
        self:setState("ACTIONSELECT", "CUTSCENE")
    end)
end

function LightBattle:setActText(text, dont_finish)
    self:battleText(text, function()
        if not dont_finish then
            self:finishAction()
        end
        if self.should_finish_action then
            self:finishAction(self.on_finish_action)
            self.on_finish_action = nil
            self.should_finish_action = false
        end
        if self.enemies[1].id == "mawzz" then
            self:setState("ACTIONSELECT")
            self.dont_end_turn = true
        else
            self:setState("ACTIONS", "BATTLETEXT")
        end
        return true
    end)
end

function LightBattle:finishAction(action)
    action = action or self.current_actions[self.current_action_index]

    local battler = self.party[action.character_id]
    
    local function finish()
        self.processed_action[action] = true

        if self.processing_action == action then
            self.processing_action = nil
        end

        local all_processed = self:allActionsDone()

        if all_processed then
            for _,iaction in ipairs(Utils.copy(self.current_actions)) do
                local ibattler = self.party[iaction.character_id]

                if self.enemies[1].id == "mawzz" then
                    self.dont_end_turn = true
                end

                Utils.removeFromTable(self.current_actions, iaction)
                self:tryProcessNextAction()

                if iaction.action == "DEFEND" then
                    ibattler.defending = false
                end

                Kristal.callEvent(MG_EVENT.onLightBattleActionEnd, iaction, iaction.action, ibattler, iaction.target)
                if self.enemies[1].id == "mawzz" then
                    if action.action ~= "ITEM" then
                        self:setState("ACTIONSELECT") 
                    end
                end
            end
        else
            -- Process actions if we can
            self:tryProcessNextAction()
        end
    end
    
    if battler.delay_turn_end then
        Game.battle.timer:after(1, function() finish() end)
    else
        finish()
    end
end

--[[function LightBattle:spawnSoul(x, y)
    local bx, by = self:getSoulLocation()
    if self.waves[1].showSoul then
        x = x or bx
        y = y or by
    else
        x = 1000000
        y = 1000000
    end
    local color = {self.encounter:getSoulColor()}
    if not self.soul then
        self.soul = self.encounter:createSoul(x, y, color)
        self.soul.alpha = 1
        self.soul.sprite:set("player/heart_light")
        self:addChild(self.soul)
    end
end]]

function LightBattle:onStateChange(old,new)
    if self.encounter.beforeStateChange then
        local result = self.encounter:beforeStateChange(old,new)
        if result or self.state ~= new then
            return
        end
    end

    --Kristal.Console:log(new)
    
    
    if old == "MENUSELECT" and new ~= "MENUSELECT" then
            if Game.battle.item_desc_box then

                if Game.battle.item_desc_pop_up then
                    Game.battle.timer:cancel(Game.battle.item_desc_pop_up)
                end
    
                Game.battle.item_desc_pop_out = Game.battle.timer:tween(0.75, Game.battle.item_desc_box, {y = 275}, "out-cubic", function()
                    Game.battle.item_desc_box.visible = false
                end)
            end          

    end

    if new == "ACTIONSELECT" then
        self.arena.layer = LIGHT_BATTLE_LAYERS["ui"] + 1

        if not self.soul then
            self:spawnSoul()
        end

        self:toggleSoul(true)
        self.soul.can_move = false

        if self.current_selecting < 1 or self.current_selecting > #self.party then
            self:nextTurn()
            if self.state ~= "ACTIONSELECT" then
                return
            end
        end
        
        self.fader:fadeIn(function()
            self.soul.layer = LIGHT_BATTLE_LAYERS["soul"]
        end, {speed=5/30})

        self.battle_ui.encounter_text.text.line_offset = 5
        self.battle_ui:clearEncounterText()
        self.battle_ui.encounter_text:setText("[shake:"..MagicalGlassLib.light_battle_shake_text.."]" .. "[noskip][wait:1][noskip:false]" ..self.battle_ui.current_encounter_text)

        local party = self.party[self.current_selecting]
        party.chara:onLightActionSelect(party, false)
        self.encounter:onCharacterTurn(party, false)
        
        if not self.started then
            self.started = true

            if self.encounter.music then
                self.music:play(self.encounter.music)
            end
            
            for _,action_box in ipairs(Game.battle.battle_ui.action_boxes) do
                if action_box.battler == party then
                    action_box:update()
                    break
                end
            end
        end

    elseif new == "BUTNOBODYCAME" then
        self.current_selecting = 0
        if not self.soul then
            self:spawnSoul()
        end

        self.soul.can_move = false
        
        self.fader:fadeIn(nil, {speed=5/30})

        self.battle_ui.encounter_text.text.line_offset = 5
        self.battle_ui:clearEncounterText()
        self.battle_ui.encounter_text:setText("[noskip][wait:1][noskip:false]"..self.battle_ui.current_encounter_text)

        if not self.started then
            self.started = true

            if self.encounter.music then
                self.music:play(self.encounter.music)
            end
        end

    elseif new == "ACTIONS" then
        self.battle_ui:clearEncounterText()
        if self.state_reason ~= "DONTPROCESS" then
            self:tryProcessNextAction()
        end
    elseif new == "MENUSELECT" then
        self.battle_ui:clearEncounterText()
        if self.menuselect_cursor_memory[self.state_reason] and Utils.containsValue(self:menuSelectMemory(), self.state_reason) then
            self.current_menu_x = self.menuselect_cursor_memory[self.state_reason].x
            self.current_menu_y = self.menuselect_cursor_memory[self.state_reason].y
        else
            self.current_menu_x = 1
            self.current_menu_y = 1
        end

        if not self:isValidMenuLocation() then
            self.current_menu_x = 1
            self.current_menu_y = 1
        end
    elseif new == "ENEMYSELECT" then
        self.battle_ui:clearEncounterText()

        if self.enemyselect_cursor_memory[self.state_reason] then
            self.current_menu_x = 1
            self.current_menu_y = self.enemyselect_cursor_memory[self.state_reason] or 1
        else
            self.current_menu_x = 1
            self.current_menu_y = 1
        end

        if not (self.enemies_index[self.current_menu_y] and self.enemies_index[self.current_menu_y].selectable) and #self.enemies_index > 0 then
            local give_up = 0
            repeat
                give_up = give_up + 1
                if give_up > 100 then return end
                -- Keep decrementing until there's a selectable enemy.
                self.current_menu_y = self.current_menu_y + 1
                if self.current_menu_y > #self.enemies_index then
                    self.current_menu_y = 1
                end
            until (self.enemies_index[self.current_menu_y] and self.enemies_index[self.current_menu_y].selectable)
        end

    elseif new == "PARTYSELECT" then
        self.battle_ui:clearEncounterText()

        if self.partyselect_cursor_memory[self.state_reason] then
            self.current_menu_x = 1
            self.current_menu_y = self.partyselect_cursor_memory[self.state_reason]
        else
            self.current_menu_x = 1
            self.current_menu_y = 1
        end

    elseif new == "ATTACKING" then
        self.battle_ui:clearEncounterText()

        local enemies_left = self:getActiveEnemies()

        if #enemies_left > 0 then
            for i,battler in ipairs(self.party) do
                local action = self.character_actions[i]
                if action and action.action == "ATTACK" then
                    self:beginAction(action)
                    table.insert(self.attackers, battler)
                    table.insert(self.normal_attackers, battler)
                elseif action and action.action == "AUTOATTACK" then
                    table.insert(self.attackers, battler)
                    table.insert(self.auto_attackers, battler)
                end
            end
        end

        self.auto_attack_timer = 0

        if #self.attackers == 0 then
            self.attack_done = true
            self:setState("ACTIONSDONE")
        else
            self.attack_done = false
        end

    elseif new == "ENEMYDIALOGUE" then
        self.current_selecting = 0
        self.battle_ui:clearEncounterText()
        self.textbox_timer = 3 * 30
        self.use_textbox_timer = true
        local active_enemies = self:getActiveEnemies()
        
        local function update_enemies()
            for _,enemy in ipairs(active_enemies) do
                enemy.current_target = enemy:getTarget()
            end
            local cutscene_args = {self.encounter:getDialogueCutscene()}
            if self.debug_wave then
                self:setState("DIALOGUEEND")
            elseif #cutscene_args > 0 then
                self:startCutscene(unpack(cutscene_args)):after(function()
                    self:setState("DIALOGUEEND")
                end)
            else
                local any_dialogue = false
                for _,enemy in ipairs(active_enemies) do
                    local dialogue = enemy:getEnemyDialogue()
                    if type(dialogue) == "string" then
                        any_dialogue = true
                        local bubble = enemy:spawnSpeechBubble(dialogue, {no_sound_overlap = true})
                        if Kristal.getLibConfig("magical-glass", "undertale_text_skipping") then
                            bubble:setSkippable(false)
                        end
                        table.insert(self.enemy_dialogue, bubble)
                    elseif type(dialogue) == "table" then
                        any_dialogue = true
                        for k, text in pairs(dialogue) do
                            --Kristal.Console:log(text)
                            --print(text)
                            --print(k)
                            local bubble = enemy:spawnSpeechBubble(text, k, {no_sound_overlap = true})
                            if Kristal.getLibConfig("magical-glass", "undertale_text_skipping") then
                                bubble:setSkippable(false)
                            end
                            table.insert(self.enemy_dialogue, bubble)
                        end
                    end
                end
                if not any_dialogue then
                    self:setState("DIALOGUEEND")
                end
            end
        end
        if #active_enemies == 0 and not self.encounter.event then
            self:setState("VICTORY")
        elseif Mod.libs["classic_turn_based_rpg"] and self.encounter:getEnemyAutoAttack() and not self.encounter.event and not self.debug_wave then
            update_enemies()
        else
            if self.state_reason then
                self:setWaves(self.state_reason)
                local enemy_found = false
                for i,enemy in ipairs(self.enemies) do
                    if Utils.containsValue(enemy.waves, self.state_reason[1]) then
                        enemy.selected_wave = self.state_reason[1]
                        enemy_found = true
                    end
                end
                if not enemy_found then
                    self.enemies[Utils.random(1, #self.enemies, 1)].selected_wave = self.state_reason[1]
                end
            else
                self:setWaves(self.encounter:getNextWaves())
            end

            local soul_x, soul_y, soul_offset_x, soul_offset_y
            local arena_x, arena_y, arena_h, arena_w
            local has_arena = false
            local has_soul = false
            local fullscreen = false
            for _,wave in ipairs(self.waves) do
                soul_x = wave.soul_start_x or soul_x
                soul_y = wave.soul_start_y or soul_y
                soul_offset_x = wave.soul_offset_x or soul_offset_x
                soul_offset_y = wave.soul_offset_y or soul_offset_y
                arena_x = wave.arena_x or arena_x
                arena_y = wave.arena_y or arena_y
                arena_w = wave.arena_width and math.max(wave.arena_width, arena_w or 0) or arena_w
                arena_h = wave.arena_height and math.max(wave.arena_height, arena_h or 0) or arena_h
                if wave.has_arena then
                    has_arena = true
                end
                if wave.has_soul then
                    has_soul = true
                end
                if wave.fullscreen then
                    fullscreen = true
                end
            end
    
            arena_w, arena_h = arena_w or 160, arena_h or 130
            arena_x, arena_y = arena_x or self.arena.home_x, arena_y or self.arena.home_y

            if fullscreen and #self.waves > 0 then
                if self.encounter.event then
                    self.arena:setPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2)
                    self.arena:setSize(SCREEN_WIDTH, SCREEN_HEIGHT)
                    self.arena:update()
                else
                    self.arena:changeShape({SCREEN_WIDTH-10, self.arena.height})
                end
            elseif has_arena then
                if self.encounter.event then
                    self.arena:setPosition(arena_x, arena_y)
                    self.arena:setSize(arena_w, arena_h)
                    self.arena:update()
                else
                    self.arena:changeShape({arena_w, self.arena.height})
                end
            elseif #self.waves > 0 then
                self.arena:disable()
            end

            local center_x, center_y = self.arena:getCenter()
    
            self:toggleSoul(has_soul)
            soul_x = soul_x or (soul_offset_x and center_x + soul_offset_x)
            soul_y = soul_y or (soul_offset_y and center_y + soul_offset_y)
            self.soul:setPosition(soul_x or center_x, soul_y or center_y)
            self.soul.can_move = self.encounter.event

            update_enemies()
        end
    elseif new == "DIALOGUEEND" then
        self.battle_ui:clearEncounterText()

        for i,battler in ipairs(self.party) do
            local action = self.character_actions[i]
            if action and action.action == "DEFEND" then
                self:beginAction(action)
                self:processAction(action)
            end
        end

        self.encounter:onDialogueEnd()
    elseif new == "DEFENDING" then
        self.arena.layer = LIGHT_BATTLE_LAYERS["arena"]

        self.wave_length = 0
        self.wave_timer = 0

        for _,wave in ipairs(self.waves) do
            wave.encounter = self.encounter

            self.wave_length = math.max(self.wave_length, wave.time)

            wave:onStart()

            wave.active = true
        end

        self.soul:onWaveStart()
    elseif new == "VICTORY" then
        self:toggleSoul(false)
        self.music:stop()
        self.current_selecting = 0
        self.forced_victory = true

        self:resetParty()
        
        local win_text = ""
        
        local no_skip = ""
        if Kristal.getLibConfig("magical-glass", "undertale_text_skipping") then
            no_skip = "[noskip]"
        end
        
        if Game:isLight() then

            self.money = self.encounter:getVictoryMoney(self.money) or self.money

            if self.tension then
                self.money = self.money + math.floor(Game:getTension() / 5)
            end

            for _,battler in ipairs(self.party) do
                for _,equipment in ipairs(battler.chara:getEquipment()) do
                    self.money = math.floor(equipment:applyMoneyBonus(self.money) or self.money)
                end
            end

            self.money = math.floor(self.money)

            self.money = self.encounter:getVictoryMoney(self.money) or self.money
            self.xp = self.encounter:getVictoryXP(self.xp) or self.xp

            win_text = no_skip.."* YOU WON!\n* You earned " .. self.xp .. " EXP and " .. self.money .. " " .. Game:getConfig("lightCurrency"):lower() .. "."

            Game.lw_money = Game.lw_money + self.money

            if (Game.lw_money < 0) then
                Game.lw_money = 0
            end

            for _,member in ipairs(self.party) do
                local lv = member.chara:getLightLV()
                member.chara:addLightEXP(self.xp)

                if lv ~= member.chara:getLightLV() then
                    win_text = no_skip.."* YOU WON!\n* You earned " .. self.xp .. " EXP and " .. self.money .. " " .. Game:getConfig("lightCurrency"):lower() .. ".\n* Your "..Kristal.getLibConfig("magical-glass", "light_level_name").." increased."
                    Assets.stopAndPlaySound("levelup")
                end
            end

            win_text = self.encounter:getVictoryText(win_text, self.money, self.xp) or win_text
        else
            if self.tension then
                self.money = self.money + (math.floor(((Game:getTension() * 2.5) / 10)) * Game.chapter)
            end

            for _,battler in ipairs(self.party) do
                for _,equipment in ipairs(battler.chara:getEquipment()) do
                    self.money = math.floor(equipment:applyMoneyBonus(self.money) or self.money)
                end
            end

            self.money = math.floor(self.money)

            self.money = self.encounter:getVictoryMoney(self.money) or self.money
            self.xp = self.encounter:getVictoryXP(self.xp) or self.xp
            -- if (in_dojo) then
            --     self.money = 0
            -- end

            Game.money = Game.money + self.money
            Game.xp = Game.xp + self.xp

            if (Game.money < 0) then
                Game.money = 0
            end

            win_text = no_skip.."* YOU WON!\n* You earned " .. self.xp .. " EXP and " .. self.money .. " " .. Game:getConfig("darkCurrencyShort") .. "."
            -- if (in_dojo) then
            --     win_text == "* You won the battle!"
            -- end
            if self.used_violence and Game:getConfig("growStronger") then
                local stronger = "You"
                
                local party_to_lvl_up = {}
                for _,battler in ipairs(self.party) do
                    table.insert(party_to_lvl_up, battler.chara)
                    if Game:getConfig("growStrongerChara") and battler.chara.id == Game:getConfig("growStrongerChara") then
                        stronger = battler.chara:getName()
                    end
                    for _,id in pairs(battler.chara:getStrongerAbsent()) do
                        table.insert(party_to_lvl_up, Game:getPartyMember(id))
                    end
                end
                
                for _,party in ipairs(Utils.removeDuplicates(party_to_lvl_up)) do
                    Game.level_up_count = Game.level_up_count + 1
                    party:onLevelUp(Game.level_up_count)
                end

                win_text = no_skip.."* YOU WON!\n* You earned " .. self.money .. " " .. Game:getConfig("darkCurrencyShort") .. ".\n* "..stronger.." became stronger."

                Assets.playSound("dtrans_lw", 0.7, 2)
                --scr_levelup()
            end

            win_text = self.encounter:getVictoryText(win_text, self.money, self.xp) or win_text
        end
        
        if self.encounter.no_end_message then
            self:setState("TRANSITIONOUT")
            self.encounter:onBattleEnd()
        else
            self:battleText(win_text, function()
                self:setState("TRANSITIONOUT", "POSTFADE")
                self.encounter:onBattleEnd()
                return true
            end)
        end

    elseif new == "TRANSITIONOUT" then
        self.ended = true
        self.current_selecting = 0
        if self.encounter_context and self.encounter_context:includes(ChaserEnemy) then
            for _,enemy in ipairs(self.encounter_context:getGroupedEnemies(true)) do
                enemy:onEncounterTransitionOut(enemy == self.encounter_context, self.encounter)
            end
        end

        local enemies = {}
        for k,v in pairs(self.enemy_world_characters) do
            table.insert(enemies, v)
        end
        self.encounter:onReturnToWorld(enemies)

        if self.state_reason == "POSTFADE" then
            self:returnToWorld()
            Game.fader:fadeIn(nil, {alpha = 1, speed = 12/30, color = {0, 0, 0}})
        else
            Game.fader:transition(function() self:returnToWorld() end, nil, {speed = (self.encounter.fast_transition and 5 or 12)/30})
        end
    elseif new == "DEFENDINGBEGIN" then
        self.battle_ui:clearEncounterText()
    elseif new == "FLEEING" then
        self.current_selecting = 0
        
        self:resetParty()
        self.encounter:onFlee()
    elseif new == "FLEEFAIL" then
        self:toggleSoul(false)
        self.current_selecting = 0
        self.encounter:onFleeFail()
        self:setState("ACTIONSDONE")
    elseif new == "DEFENDINGEND" then
        if self.encounter.event then
            self:setState("TRANSITIONOUT")
            self.encounter:onBattleEnd()
        else
            self:toggleSoul(false)
            self.arena:enable()
            self.arena.rotation = 0
            if self.arena.height >= self.arena.init_height then
                self.arena:changePosition({self.arena.home_x, self.arena.home_y}, true,
                function()
                    self.arena:changeShape({self.arena.width, self.arena.init_height},
                    function()
                        self.arena:changeShape({self.arena.init_width, self.arena.height})
                    end)
                end)
            else
                self.arena:changePosition({self.arena.home_x, self.arena.home_y}, true,
                function()
                    self.arena:changeShape({self.arena.init_width, self.arena.height},
                    function()
                        self.arena:changeShape({self.arena.width, self.arena.init_height})
                    end)
                end)
            end
        end
    end
    
    local normal_arena_state = {"TURNDONE", "DEFENDINGEND", "TRANSITIONOUT", "ACTIONSELECT", "VICTORY", "INTRO", "ACTIONS", "ENEMYSELECT", "PARTYSELECT", "MENUSELECT", "ATTACKING", "FLEEING", "FLEEFAIL", "BUTNOBODYCAME"}

    local should_end = not self.encounter.event
    if Utils.containsValue(normal_arena_state, new) then
        for _,wave in ipairs(self.waves) do
            if wave:beforeEnd() then
                should_end = false
            end
        end
        if should_end then
            for _,battler in ipairs(self.party) do
                battler.targeted = false
            end
        end
    end

    if old == "DEFENDING" and not Utils.containsValue({"ENEMYDIALOGUE", "DIALOGUEEND", "DEFENDINGBEGIN"}, new) and should_end then
        for _,wave in ipairs(self.waves) do
            if not wave:onEnd(false) then
                wave:clear()
                wave:remove()
            end
        end

        if self:hasCutscene() then
            self.cutscene:after(function()
                self:setState("TURNDONE", "WAVEENDED")
            end)
        else
            self.timer:after(15/30, function()
                self:setState("TURNDONE", "WAVEENDED")
            end)
        end
    end

    self.encounter:onStateChange(old,new)
end

function LightBattle:update()
    for _,enemy in ipairs(self.enemies_to_remove) do
        Utils.removeFromTable(self.enemies, enemy)
        local enemy_y = Utils.getKey(self.enemies_index, enemy)
        if enemy_y then
            self.enemies_index[enemy_y] = false
        end
    end
    self.enemies_to_remove = {}

    if self.cutscene then
        if not self.cutscene.ended then
            self.cutscene:update()
        else
            self.cutscene = nil
        end
    end
    if Game.battle == nil then return end -- cutscene ended the battle

    if self.state == "ATTACKING" then
        self:updateAttacking()
    elseif self.state == "ACTIONSDONE" then
        local any_hurt = false
        for _,enemy in ipairs(self.enemies) do
            if enemy.hurt_timer > 0 then
                any_hurt = true
                break
            end
        end
        if not any_hurt then
            self:resetAttackers()
            if not self.encounter:onActionsEnd() then
                self:setState("ENEMYDIALOGUE")
            end
        end
    elseif self.state == "ENEMYDIALOGUE" then
        self.textbox_timer = self.textbox_timer - DTMULT
        if (self.textbox_timer <= 0) and self.use_textbox_timer then
            self:advanceBoxes()
        else
            local all_done = true
            local boxes_done = true

            for _,textbox in ipairs(self.enemy_dialogue) do
                if textbox:isTyping() then
                    boxes_done = false
                end
            end

            for _,textbox in ipairs(self.enemy_dialogue) do
                if boxes_done then
                    textbox:setAdvance(true)
                end
            end

            for _,textbox in ipairs(self.enemy_dialogue) do
                if not textbox:isDone() then
                    all_done = false
                    break
                end
            end

            if all_done then
                self:setState("DIALOGUEEND")
            end
        end
    elseif self.state == "DEFENDINGBEGIN" then
        if self.arena:isNotTransitioning() then
            local soul_x, soul_y, soul_offset_x, soul_offset_y
            local arena_x, arena_y, arena_h, arena_w
            local has_arena = true
            local fullscreen = true
            for _,wave in ipairs(self.waves) do
                soul_x = wave.soul_start_x or soul_x
                soul_y = wave.soul_start_y or soul_y
                soul_offset_x = wave.soul_offset_x or soul_offset_x
                soul_offset_y = wave.soul_offset_y or soul_offset_y
                arena_x = wave.arena_x or arena_x
                arena_y = wave.arena_y or arena_y
                arena_h = wave.arena_height and math.max(wave.arena_height, arena_h or 0) or arena_h
                if not wave.has_arena then
                    has_arena = false
                end
                if not wave.fullscreen then
                    fullscreen = false
                end
            end

            arena_h, arena_w  = arena_h or 130, arena_w or 160
            
            local center_x, center_y = self.arena:getCenter()

            if fullscreen and #self.waves > 0 then
                if (self.arena.width ~= SCREEN_WIDTH or self.arena.height ~= SCREEN_HEIGHT) then
                    self.arena:changeShape({SCREEN_WIDTH, SCREEN_HEIGHT})
                end
                if not (self.arena.x == SCREEN_WIDTH/2 and self.arena.y == SCREEN_HEIGHT/2) then
                    self.arena:changePosition({SCREEN_WIDTH/2, SCREEN_HEIGHT/2})
                end
            elseif has_arena then
                if self.arena.height ~= arena_h then
                    self.arena:changeShape({self.arena.width, arena_h})
                end
                if not (self.arena.x == arena_x and self.arena.y == arena_y) then
                    self.arena:changePosition({arena_x, arena_y})
                end
            end
        end

        if self.arena:isNotTransitioning() and self.once and self.waves[1] then
            self.once = false
            if self.waves[1].popupInit then self.waves[1]:popupInit() end
            self.timer:after(1.5, function ()
                self.once = true
                self:setState("DEFENDING")
                self.soul.can_move = true
            end)
        elseif self.arena:isNotTransitioning() and not self.waves[1] then
            self:setState("DEFENDING")
            self.soul.can_move = true
        end
    elseif self.state == "DEFENDING" then
        local darken = false
        local alt_darken = false
        local time
        for _,wave in ipairs(self.waves) do
            if wave.darken then
                darken = true
                time = wave.time
                if wave.darken == "alt" then
                    alt_darken = true
                end
            end
        end
        
        if alt_darken then
            self.darkify_fader.layer = LIGHT_BATTLE_LAYERS["ui"] - 1.5
        else
            self.darkify_fader.layer = LIGHT_BATTLE_LAYERS["below_arena"]
        end

        if darken and self.wave_timer <= time - 9/30 then
            self.darkify_fader.alpha = Utils.approach(self.darkify_fader.alpha, 0.5, DTMULT * 0.05)
            if alt_darken then
                self.arena.alpha = Utils.approach(self.arena.alpha, 0.5, DTMULT * 0.05)
            end
        else
            self.darkify_fader.alpha = Utils.approach(self.darkify_fader.alpha, 0, DTMULT * 0.05)
            self.arena.alpha = Utils.approach(self.arena.alpha, 1, DTMULT * 0.05)
        end

        self:updateWaves()
    elseif self.state == "TURNDONE" then
        for _,wave in ipairs(self.waves) do
            wave:onArenaExit()
        end
        self.waves = {}

        if self.state_reason == "WAVEENDED" and #self.arena.target_position == 0 and #self.arena.target_shape == 0 and not self.forced_victory then
            Input.clear("cancel", true)
            self:nextTurn()
        end
    end
    
    if self.state == "ACTIONSELECT" then
        local actbox = self.battle_ui.action_boxes[self.current_selecting]
        if actbox then
            actbox:snapSoulToButton()
        end
    end

    if self.state ~= "TRANSITIONOUT" then
        self.encounter:update()
    end

    if MENU_WAVE_STATES[self.state] then
        self:updateMenuWaves()
    end
    
    if FADE_RESET_STATES[self.state] then
        self.darkify_fader.alpha = Utils.approach(self.darkify_fader.alpha, 0, DTMULT * 0.05)
        self.arena.alpha = Utils.approach(self.arena.alpha, 1, DTMULT * 0.05)
    end
    
    super.super.update(self)
end

function LightBattle:nextTurn()
  
    self.turn_count = self.turn_count + 1
    
    self.debug_wave = false
    if self.turn_count > 1 then
        if not self.dont_end_turn then
            self.dont_end_turn = false
            if self.encounter:onTurnEnd() then
                return
            end
        end
        self.dont_end_turn = false
        for _,battler in ipairs(self.party) do
            if battler.chara:onLightTurnEnd(battler) then
                return
            end
        end
        for _,enemy in ipairs(self:getActiveEnemies()) do
            if enemy:onTurnEnd() then
                return
            end
        end
    end

    for _,action in ipairs(self.current_actions) do
        if action.action == "DEFEND" then
            self:finishAction(action)
        end
    end

    for _,enemy in ipairs(self.enemies) do
        enemy.selected_wave = nil
        enemy.hit_count = 0
        enemy.active_msg = 0
        enemy.x_number_offset = 0
        enemy.post_health = nil
    end

    for _,battler in ipairs(self.party) do
        battler.hit_count = 0
        battler.delay_turn_end = false
        battler.manual_spare = false
        if (battler.chara:getHealth() <= 0) and battler.chara:canAutoHeal() then
            battler:heal(battler.chara:autoHealAmount())
        end
        battler.action = nil
    end

    self.attackers = {}
    self.normal_attackers = {}
    self.auto_attackers = {}

    if self.state ~= "BUTNOBODYCAME" then
        self.current_selecting = 1
    end

    while not (self.party[self.current_selecting]:isActive()) do
        self.current_selecting = self.current_selecting + 1
        if self.current_selecting > #self.party then
            print("WARNING: nobody up! this shouldn't happen...")
            self.current_selecting = 1
            break
        end
    end

    self.character_actions = {}
    self.current_actions = {}
    self.processed_action = {}

    if self.battle_ui then
        local found = false
        for _,action_box in ipairs(self.battle_ui.action_boxes) do
            for i,button in ipairs(action_box.buttons or {}) do
                if button.type == self.last_button_type then
                    action_box.selected_button = i
                    found = true
                    break
                end
            end
            if not found then
                local group
                for _,pair in ipairs(self:actionButtonPairs()) do
                    if Utils.containsValue(pair, self.last_button_type) then
                        group = pair
                        break
                    end
                end
                if group then
                    for i,button in ipairs(action_box.buttons or {}) do
                        if Utils.containsValue(group, button.type) then
                            action_box.selected_button = i
                            found = true
                            break
                        end
                    end
                end
            end
            if not found then
                action_box.selected_button = action_box.last_button or 1
            end
        end
        
        if not self.seen_encounter_text then
            self.seen_encounter_text = true
            self.battle_ui.current_encounter_text = self.encounter.text
        else
            self.battle_ui.current_encounter_text = self:getEncounterText()
        end
        self.battle_ui.encounter_text:setText("[shake:"..MagicalGlassLib.light_battle_shake_text.."]" .. self.battle_ui.current_encounter_text)
    end

    self.encounter:onTurnStart()
    for _,enemy in ipairs(self:getActiveEnemies()) do
        enemy:onTurnStart()
    end
    
    if self.battle_ui then
        for _,battler in ipairs(self.party) do
            battler.chara:onLightTurnStart(battler)
        end
    end

    if self.current_selecting ~= 0 and self.state ~= "ACTIONSELECT" then
        self:setState("ACTIONSELECT")
    end

    if self.encounter.getNextMenuWaves and #self.encounter:getNextMenuWaves() > 0 then
        self:setMenuWaves(self.encounter:getNextMenuWaves())

        for _,enemy in ipairs(self:getActiveEnemies()) do
            enemy.menu_wave_override = nil
        end
        self.menu_wave_length = 0
        self.menu_wave_timer = 0

        for _,wave in ipairs(self.menu_waves) do
            wave.encounter = self.encounter

            self.menu_wave_length = math.max(self.menu_wave_length, wave.time)

            wave:onStart()

            wave.active = true
        end

        self.soul:onMenuWaveStart()
    end

end

return LightBattle
