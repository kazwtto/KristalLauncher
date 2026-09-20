local LightStatusDisplay, super = Class(Object, "LightStatusDisplay")

function LightStatusDisplay:init(x, y, event)
    super.init(self, x, y, SCREEN_WIDTH + 1, 43)
    self.event = event
end

function LightStatusDisplay:getHPGaugeLengthCap()
    return Kristal.getLibConfig("magical-glass", "hp_gauge_length_cap")
end

function LightStatusDisplay:draw()
    if self.event and Game.battle.party[1] then
        self:drawStatusStripEvent()
    else
        self:drawStatusStrip()
    end
end

function LightStatusDisplay:drawStatusStripEvent()
    local battle = Game.battle
    local battler = battle.party[1]
    local chara = battler.chara
    local is_light = Game:isLight()
    local x, y = 200, 10
    local karma_mode = battle.encounter.karma_mode
    local karma_mode_offset = karma_mode and 20 or 0
    local level = is_light and chara:getLightLV() or chara:getLevel()
    local level_name = is_light and Kristal.getLibConfig("magical-glass", "light_level_name_short") or Kristal.getLibConfig("magical-glass", "light_level_name_dark")
    local font = Assets.getFont("namelv", 24)
    local hp_texture = Assets.getTexture("ui/lightbattle/hp")
    local kr_texture = karma_mode and Assets.getTexture("ui/lightbattle/kr") or nil

    love.graphics.setFont(font)
    love.graphics.setColor(MG_PALETTE["player_text"])
    local lenght = font:getWidth(level_name) - 30
    if font:getWidth(level) > 30 then
        lenght = lenght + font:getWidth(level) - 30
    end
    love.graphics.print(level_name.." "..level, x - karma_mode_offset - lenght, y)
    love.graphics.draw(hp_texture, x + 74 - karma_mode_offset, y + 5)

    local max = chara:getStat("health")
    local current = chara:getHealth()
    local karma = battler.karma
    local limit = self:getHPGaugeLengthCap()
    if limit == true then
        limit = 99
    end
    local size = max
    if limit and size > limit then
        size = limit
        limit = true
    end

    if karma_mode then
        love.graphics.draw(kr_texture, x + 110 + size * 1.2 + 1 + 9 - karma_mode_offset, y + 5)
    end

    love.graphics.setColor(is_light and (karma_mode and MG_PALETTE["player_karma_health_bg"] or MG_PALETTE["player_health_bg"]) or MG_PALETTE["player_health_bg_dark"])
    love.graphics.rectangle("fill", x + 110 - karma_mode_offset, y, size * 1.2 + 1, 21)
    if current > 0 then
        love.graphics.setColor(is_light and MG_PALETTE["player_karma_health"] or MG_PALETTE["player_karma_health_dark"])
        love.graphics.rectangle("fill", x + 110 - karma_mode_offset, y, (limit == true and math.ceil((Utils.clamp(current, 0, max + (karma_mode and 5 or 10)) / max) * size) * 1.2 + 1 or Utils.clamp(current, 0, max + (karma_mode and 5 or 10)) * 1.2 + 1), 21)
        if is_light then
            love.graphics.setColor(MG_PALETTE["player_health"])
        else
            love.graphics.setColor(chara:getColor())
        end
        love.graphics.rectangle("fill", x + 110 - karma_mode_offset, y, (limit == true and math.ceil((Utils.clamp(current - karma, 0, max + (karma_mode and 5 or 10)) / max) * size) * 1.2 + 1 or Utils.clamp(current - karma, 0, max + (karma_mode and 5 or 10)) * 1.2 + 1) - (karma_mode and 1 or 0), 21)
    end

    if max < 10 and max >= 0 then
        max = "0" .. tostring(max)
    end
    if current < 10 and current >= 0 then
        current = "0" .. tostring(current)
    end

    local color = MG_PALETTE["player_text"]
    if not battler.is_down then
        if battler.sleeping then
            color = MG_PALETTE["player_sleeping_text"]
        else
            local action = battle:getActionBy(battler)
            if action and action.action == "DEFEND" then
                color = MG_PALETTE["player_defending_text"]
            elseif karma > 0 then
                color = MG_PALETTE["player_karma_text"]
            end
        end
    end

    if battle.hp_display then current = battle.hp_display end
    if battle.max_hp_display then max = battle.max_hp_display end

    love.graphics.setColor(color)
    love.graphics.print(current .. " / " .. max, x + 115 + size * 1.2 + 1 + 14 + (karma_mode and kr_texture:getWidth() + 12 or 0) - karma_mode_offset, y)
end

function LightStatusDisplay:drawStatusStrip()
    local battle = Game.battle
    local party = battle.party
    local is_light = Game:isLight()
    local font24 = Assets.getFont("namelv", 24)
    local font16 = Assets.getFont("namelv", 16)
    local hp_texture = Assets.getTexture("ui/lightbattle/hp")
    local karma_mode = battle.encounter.karma_mode
    local kr_texture = karma_mode and Assets.getTexture("ui/lightbattle/kr") or nil
    local level_name = is_light and Kristal.getLibConfig("magical-glass", "light_level_name_short") or Kristal.getLibConfig("magical-glass", "light_level_name_dark")
    local state = battle:getState()
    local action_select_state = state == "ACTIONSELECT" or state == "MENUSELECT" or state == "ENEMYSELECT" or state == "PARTYSELECT"
    local debug_alt = DEBUG_RENDER and Input.alt()
    local small = false

    if battle.multi_mode then
        for _,member in ipairs(party) do
            if member.chara:getStat("health") >= 100 then
                small = true
                break
            end
        end
    end

    for index,battler in ipairs(party) do
        local chara = battler.chara
        local action = battle:getActionBy(battler)
        if not battle.multi_mode then
            local x, y = 30, 10
            local karma_mode_offset = karma_mode and 20 or 0
            local name = chara:getName()
            local level = is_light and chara:getLightLV() or chara:getLevel()
            local current = chara:getHealth()
            local max = chara:getStat("health")
            local karma = battler.karma

            love.graphics.setFont(font24)
            love.graphics.setColor(MG_PALETTE["player_text"])
            love.graphics.print(name .. "   "..level_name.." " .. level, x, y)
            love.graphics.draw(hp_texture, x + 214 - karma_mode_offset, y + 5)

            local limit = self:getHPGaugeLengthCap()
            if limit == true then
                limit = 99
            end
            local size = max
            if limit and size > limit then
                size = limit
                limit = true
            end

            if karma_mode then
                love.graphics.draw(kr_texture, x + 245 + size * 1.2 + 1 + 9 - karma_mode_offset, y + 5)
            end

            love.graphics.setColor(is_light and (karma_mode and MG_PALETTE["player_karma_health_bg"] or MG_PALETTE["player_health_bg"]) or MG_PALETTE["player_health_bg_dark"])
            love.graphics.rectangle("fill", x + 245 - karma_mode_offset, y, size * 1.2 + 1, 21)
            if current > 0 then
                love.graphics.setColor(is_light and MG_PALETTE["player_karma_health"] or MG_PALETTE["player_karma_health_dark"])
                love.graphics.rectangle("fill", x + 245 - karma_mode_offset, y, (limit == true and math.ceil((Utils.clamp(current, 0, max + (karma_mode and 5 or 10)) / max) * size) * 1.2 + 1 or Utils.clamp(current, 0, max + (karma_mode and 5 or 10)) * 1.2 + 1), 21)
                if is_light then
                    love.graphics.setColor(MG_PALETTE["player_health"])
                else
                    love.graphics.setColor(chara:getColor())
                end
                love.graphics.rectangle("fill", x + 245 - karma_mode_offset, y, (limit == true and math.ceil((Utils.clamp(current - karma, 0, max + (karma_mode and 5 or 10)) / max) * size) * 1.2 + 1 or Utils.clamp(current - karma, 0, max + (karma_mode and 5 or 10)) * 1.2 + 1) - (karma_mode and 1 or 0), 21)
            end

            if max < 10 and max >= 0 then max = "0" .. tostring(max) end
            if current < 10 and current >= 0 then current = "0" .. tostring(current) end

            local color = MG_PALETTE["player_text"]
            if not battler.is_down then
                if battler.sleeping then
                    color = MG_PALETTE["player_sleeping_text"]
                elseif action and action.action == "DEFEND" then
                    color = MG_PALETTE["player_defending_text"]
                elseif karma > 0 then
                    color = MG_PALETTE["player_karma_text"]
                end
            end

            if battle.hp_display then current = battle.hp_display end
            if battle.max_hp_display then max = battle.max_hp_display end

            love.graphics.setColor(color)
            love.graphics.print(current .. " / " .. max, x + 245 + size * 1.2 + 1 + 14 + (karma_mode and kr_texture:getWidth() + 12 or 0) - karma_mode_offset, y)
        else
            local x, y = 22 + (3 - #party - (#party == 2 and 0.4 or 0)) * 102 + (index - 1) * 102 * 2 * (#party == 2 and (1 + 0.4) or 1), 10
            local name = chara:getShortName()
            local level = is_light and chara:getLightLV() or chara:getLevel()
            local current = chara:getHealth()
            local max = chara:getStat("health")
            local karma = battler.karma

            love.graphics.setFont(font24)
            love.graphics.setColor(MG_PALETTE["player_text"])
            love.graphics.print(name, x, y - 7)
            love.graphics.setFont(font16)
            love.graphics.print(level_name.." " .. level, x, y + 13)
            love.graphics.draw(hp_texture, x + 66, y + 15)

            local gauge_size = small and 20 or 32
            if karma_mode then
                love.graphics.draw(kr_texture, x + 95 + gauge_size * 1.2 + 1, y + 15)
            end

            love.graphics.setColor(is_light and (karma_mode and MG_PALETTE["player_karma_health_bg"] or MG_PALETTE["player_health_bg"]) or MG_PALETTE["player_health_bg_dark"])
            love.graphics.rectangle("fill", x + 92, y, gauge_size * 1.2 + 1, 21)
            if current > 0 then
                love.graphics.setColor(is_light and MG_PALETTE["player_karma_health"] or MG_PALETTE["player_karma_health_dark"])
                love.graphics.rectangle("fill", x + 92, y, math.ceil((Utils.clamp(current, 0, max) / max) * gauge_size) * 1.2 + 1, 21)
                if is_light then
                    love.graphics.setColor(MG_PALETTE["player_health"])
                else
                    love.graphics.setColor(chara:getColor())
                end
                love.graphics.rectangle("fill", x + 92, y, math.ceil((Utils.clamp(current - karma, 0, max) / max) * gauge_size) * 1.2 + 1 - (karma_mode and 1 or 0), 21)
            end

            if max < 10 and max >= 0 then max = "0" .. tostring(max) end
            if current < 10 and current >= 0 then current = "0" .. tostring(current) end

            local color = MG_PALETTE["player_text"]
            if battler.is_down then
                color = MG_PALETTE["player_down_text"]
            elseif battler.sleeping then
                color = MG_PALETTE["player_sleeping_text"]
            elseif action and action.action == "DEFEND" then
                color = MG_PALETTE["player_defending_text"]
            elseif action and action_select_state and action.action ~= "AUTOATTACK" then
                color = MG_PALETTE["player_action_text"]
            elseif karma > 0 then
                color = MG_PALETTE["player_karma_text"]
            end
            love.graphics.setColor(color)
            Draw.printAlign(current .. "/" .. max, x + 197, y + 3 - (karma_mode and 2 or 0), "right")

            if battle.current_selecting == index or debug_alt then
                love.graphics.setColor(chara:getColor())
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", x - 3, y - 7, 201, 35)
            end

            if battler:isTargeted() and Game:getConfig("targetSystem") and battle.state == "ENEMYDIALOGUE" then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.setLineWidth(2)
                local function target_text_area()
                    love.graphics.rectangle("fill", x + 1, y - 9, 25, 4)
                end
                love.graphics.stencil(target_text_area, "replace", 1)
                love.graphics.setStencilTest("equal", 0)
                if math.floor(Kristal.getTime() * 3) % 2 == 0 then
                    love.graphics.rectangle("line", x - 3, y - 7, 201, 35)
                else
                    love.graphics.rectangle("line", x - 2, y - 6, 199, 33)
                end
                love.graphics.setStencilTest()
                love.graphics.draw(Assets.getTexture("ui/lightbattle/chartarget"), x + 2, y - 9)
            end
        end
    end
end

return LightStatusDisplay
