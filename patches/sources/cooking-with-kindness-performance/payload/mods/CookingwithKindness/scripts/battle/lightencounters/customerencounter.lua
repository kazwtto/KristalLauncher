local Customerencounter, super = Class(LightEncounter)

function Customerencounter:init()
    super.init(self)

    Game.world.music:stop()
    self.music = nil

    self.sickbeats = "customer_approaching"

    self.can_flee = false

    self.encounterlist = {}

    self.encountercounts = {}

    self.superlist = {}

    self.customerqueue = {}

    self.customernext = 1

    self.customercount = 3

    self.clockAngle = math.rad(-90)

    self.rotateClock = false

    self.customerNow = 1

    self.endscreentrue = true

    self.displaytimer = barTimer()

    self.showClock = true

    self.show_item_desc_menu = true

    self.accepts_ingredients = true

    if not self.notimer then
        self.displaytimer:setLayer(-980)
        Game.battle:addChild(self.displaytimer)
    end

    self.employs = {} -- temporary way to refer to wactive employs.



    self.isCustomerEncounter = true

    self.showReputationPopup = true

-- employee builder
    self.emps = {
        --Grillby
                      { ['id'] = "grillby",
                        ['uses'] = Game:getFlag("grilluse", 1) + Game:getFlag("coffee", 0),
                        ['function'] = function() -- actual behavior
                        local id = Game.battle:getActiveEnemies()[1].name
                        if Game.battle:getActiveEnemies()[1].timer.counterTime - 5 > 0 then
                        Game.battle:getActiveEnemies()[1].timer.counterTime = Game.battle:getActiveEnemies()[1].timer.counterTime - 5
                        end
                        Game:setFlag("GrilDia", Textdump:Search(id))
                        Game:setFlag("grillbyAffection", Game:getFlag("grillbyAffection", 0) + 1)
                        Game.battle:startCutscene("democustomers", "grillbyspeak")
                         end
                      }
}
self:buildEmployees()
self.displaytimer:getEmploys(self.employtable)
end
function Customerencounter:buildEmployees()
    self.employtable = {}
    if Game:getFlag("grillby_recruited") then
        self.employs = {"grillby"}
    end
    if self.employs ~= nil then
        for i = 1, #self.employs do
            for v = 1, #self.emps do
                if self.emps[v]['id'] == self.employs[i] then
                    table.insert(self.employtable, self.emps[v]) --grabs active employees
                end
            end
        end
    end
end

function Customerencounter:getEncounterText()
    local enemies = Game.battle:getActiveEnemies()
    local enemy = TableUtils.pick(TableUtils.filter(enemies, function(v)
        if not v.text then
            return true
        else
            return #v.text > 0
        end
    end))

    if enemy then
        return enemy:getEncounterText()
    else
        return self.text
    end
end

function Customerencounter:runEmployees()
    --local buttontable = {"1", "2", "3"} -- this table can be swapped out later to decide specific binds
    for i = 1, #self.employtable do
    if Game:getFlag("Grillpress") == true then if self.employtable[i]['uses'] > 0 then if Game:getFlag("spentemploy") ~= true then --forgive the if then nesting
    Game:setFlag("Grillpress", false)
    Game:setFlag("spentemploy", true)
     self.employtable[i]['function']()
     self.employtable[i]['uses'] =  self.employtable[i]['uses'] - 1
     Game:setFlag("coffee", math.max(Game:getFlag("coffee", 0) - 1, 0))
     self.displaytimer:updateUses(self.employtable[i]['uses'], self.employtable[i]['id'])
    else
        Game:setFlag("Grillpress", false)
    end
    end
    end
    end
end

---@param customers    table   Table of all the customer IDs (as strings)
---@param values       table   Table of integer values. Each index will correspond with an index in the customers table
---@param mode         string  Determines how customers are registered. Value changes with mode.
---"random" generates a truely random quantity of each customer based on customercount. value does not need to be passed.
---"weighted" utilizes a weighted set of probabilities. value determines probability by percentage.
---"determined" utilizes a set number of each customer. Value determines the number of each customer. customercount is not needed.
---"set" places each customer in the queue in the order they are written in the customers table. VALUE DOES NOT DO ANYTHING BUT STILL NEEDS TO BE THERE. customercount is not needed.
function Customerencounter:registerCustomers(customers, values, mode)

    if mode == "random" or nil then
        self.encounterlist = customers
        local previous = ""
        for i = 1, self.customercount do
            local cust = self.encounterlist[math.random(1,#customers)]
            if cust ~= previous then -- Ensures the same customer is not placed in the list twice in a row
                table.insert(self.customerqueue, cust)
                previous = cust
            end
        end
    elseif mode == "weighted" then
        self.encounterlist = customers
        local roll = 100
        local charranges = {}
        local previous = ""
        for i = 1, #self.encounterlist do
            table.insert(charranges, {roll, roll - values[i]})
            roll = roll - values[i]
        end

        for i = 1, self.customercount do
            local customer = nil
            repeat
                local die = MathUtils.random(100)
                for v = 1, #charranges do
                    if (charranges[v][2] <= die and die <= charranges[v][1]) and self.encounterlist[v] ~= previous then -- Also ensures that the next customer added to the queue is not the same as the previous one
                        table.insert(self.customerqueue, self.encounterlist[v])
                        previous = self.encounterlist[v] -- Saves the customer just added to the queue
                    elseif (charranges[v][2] <= die and die <= charranges[v][1]) and self.encounterlist[v] == previous then
                        customer = self.encounterlist[v]
                    end
                end
            until customer ~= previous
        end
    elseif mode == "determined" then
        self.encounterlist = customers
        self.encountercounts = values
        for i = 1, #self.encounterlist do
            for v = 1, self.encountercounts[i] do
                table.insert(self.superlist, self.encounterlist[i])
            end
        end
        -- generates unshuffled list of all customers in correct quantities.
        local tblsize = #self.superlist

        -- shuffling algorithm.
        for i= 1, tblsize do
            local value = math.random(1, #self.superlist)
            local rand = self.superlist[value]
            table.remove(self.superlist, value)
            table.insert(self.customerqueue, rand)
        end
    elseif mode == "set" then
        self.customerqueue = customers
    end

    if #self.customerqueue == 0 then
        table.insert(self.customerqueue, "dummy")
    end

    -- default if customer queue is empty for whatever reason.
    local enemy = self:addEnemy(self.customerqueue[self.customernext], 320, 240)
    enemy.layer = BATTLE_LAYERS["bottom"]-1
    enemy:slideTo(SCREEN_WIDTH/2,240,1,nil)
end

function Customerencounter:update()
    super.update(self)

    if self.employtable ~= nil then self:runEmployees() end

    Game:setFlag("clockAngle", self.clockAngle)

    if Game:getFlag("nextin") == true then
        self.customernext = self.customernext + 1
        self.customer = self.customerqueue[self.customernext]
        self:bringInNext()
    end

    self.customer = self.customerqueue[self.customernext]
    if Game.music:isPlaying() == false and Game.battle:getState() == "ACTIONSELECT" then Game.music:play(self.sickbeats) end --TEMPORARY EXISTS EXCLUSIVELY UNTIL A BETTER SOLUTION IS FOUND


    if Game.battle:getState() == "TURNDONE" then --BANDAID SOLUTION DO NOT RELY ON THIS
        Game.battle:setState("ACTIONSELECT")
    end


    if self.clockAngle ~= math.rad((360 / #self.customerqueue * (self.customernext - 1)) - 90) and self.rotateClock == false then
        Game.stage.timer:tween(1, self, {clockAngle=math.rad((360 / #self.customerqueue * (self.customernext - 1)) - 90)}, "out-quad")
        self.rotateClock = true
        Game.stage.timer:after(1, function()
            self.clockAngle = math.rad((360 / #self.customerqueue * (self.customernext - 1)) - 90)
            self.rotateClock = false
        end)
   end
end

function Customerencounter:runVictory()
    Game.battle.enemies = {}
    Game.battle.enemies_index = {}
    Game.battle.enemy_dialogue = {}
    Game.battle.enemies_to_remove = {}
    Game.battle.defeated_enemies = {}

    Game.battle:setState("TRANSITIONOUT")
    Game.music:stop()
    Game:setFlag("nextin", false)
    CustScore:finalizePoints()
end

function Customerencounter:bringInNext()
    for _,enemy in ipairs(Game.battle:getActiveEnemies()) do
        enemy:defeat() -- Removes them from the active enemies
        enemy:slideTo(0,240,1,nil,function()
            Game.battle:setState("ACTIONSELECT")
        end)
        Game.battle.timer:after(1, function ()
            enemy:remove() -- Deletes their sprite
        end)
    end
    Game.battle.enemies = {}
    Game.battle.enemies_index = {}
    Game.battle.enemy_dialogue = {}
    Game.battle.enemies_to_remove = {}
    Game.battle.defeated_enemies = {}

    if self.customernext > #self.customerqueue then
        Game.battle:setState("TRANSITIONOUT")
        CustScore:finalizePoints()
        Game.music:stop()
        Game:setFlag("nextin", false)
        return
    else
        Game.battle:setState("NOTHING")

        if Game.battle:getState() == "FLEEING" then Game.music:stop()
            Game:setFlag("nextin", false)
            return
        end

        local enemy = self:addEnemy(self.customer, SCREEN_WIDTH, 240)
        enemy.layer = BATTLE_LAYERS["bottom"]-1
        enemy:slideTo(SCREEN_WIDTH/2,240,1,nil,function()
            Game.battle:setState("ACTIONSELECT")
        end)
    end
    Game:setFlag("nextin", false)
end

-- Returns a letter grade for a customer based on how well you did
function Customerencounter:getLetterGrade(ciel, repValue)
    if     repValue >= ciel then
        return "S", "grade_s", 1, 1, 0
    elseif repValue >= ciel*0.7 then
        return "A", "grade_a", 0, 1, 0
    elseif repValue >= ciel*0.5 then
        return "B", "grade_b", 0.5, 1, 0
    elseif repValue >= ciel*0.3 then
        return "C", "grade_c", 1, 0.7, 0
    elseif repValue >= ciel*0.2 then
        return "D", "grade_d", 1, 0.2, 0
    else
        return "F", "grade_f", 0.8, 0, 0
    end
end

-- Handles the customer feedback that appears when spared
function Customerencounter:handleSpareText(origin_x,origin_y, scoreDecimal, goldDecimal)
    local scoreDecimal = scoreDecimal or 0
    local goldDecimal = goldDecimal or 0

    local rep = MoistLib.roundToDecimal(Game:getFlag("newscore"), scoreDecimal) or "Some"
    local rep_text = "+ "..rep.."REP"

    local gold = MoistLib.roundToDecimal(Game:getFlag("newcash"), goldDecimal) or "Some"
    local gold_text = "+ ".. gold .."G"

    local ReputationText = Game.battle:addChild(Text(rep_text,origin_x, origin_y))
    ReputationText:setColor(0, 1, 0)

    local rank, RankIconure, r,g,b = self:getLetterGrade(100,rep + gold);
    --local RankIcon = Game.battle:addChild(Text(rank,origin_x+ReputationText:getTextWidth()-26, origin_y))
    local RankIcon = Sprite('ranks/'..RankIconure,origin_x+ReputationText:getTextWidth()+5, origin_y + 20)
    local RankBell = Sprite('ranks/grade_bell',origin_x+ReputationText:getTextWidth()+45, origin_y + 40)

    RankIcon:setScale(2)
    RankBell:setScale(2)
    RankIcon:setColor(r, g, b)
    RankBell:setColor(1, 1, 0)
    Game.battle:addChild(RankIcon)
    if rank == "S" then
        Game.battle:addChild(RankBell)
        Game.battle.timer:after(4/30, function () Assets.playSound("snd_ding", 1, 1) end)

        RankBell:play(0.2, false, function ()
            RankBell:fadeOutSpeedAndRemove(0.1)
        end)
    end



    local GoldText = Game.battle:addChild(Text(gold_text,origin_x, origin_y+ReputationText:getTextHeight()))
    GoldText:setColor(255, 204, 0)

    Game.battle.timer:script(function(wait)
        Game.battle.timer:tween(0.5, ReputationText, {y = origin_y-40}, 'in-out-quad')
        Game.battle.timer:tween(0.5, RankIcon, {y = origin_y-40}, 'in-out-quad')
        if RankBell then Game.battle.timer:tween(0.5, RankBell, {y = origin_y-60}, 'in-out-quad') end
        Game.battle.timer:tween(0.5, GoldText, {y = origin_y-(40-(ReputationText:getTextHeight()-10))}, 'in-out-quad')
        wait(2)
        Game.battle.timer:tween(0.5, ReputationText, {y = origin_y-60}, 'in-out-quad')
        Game.battle.timer:tween(0.5, RankIcon, {y = origin_y-60}, 'in-out-quad')
        if RankBell then Game.battle.timer:tween(0.5, RankBell, {y = origin_y-80}, 'in-out-quad') end
        Game.battle.timer:tween(0.5, GoldText, {y = origin_y-(60-(ReputationText:getTextHeight()-10))}, 'in-out-quad')
        ReputationText:fadeOutSpeedAndRemove(0.15)
        RankIcon:fadeOutSpeedAndRemove(0.12)
        GoldText:fadeOutSpeedAndRemove(0.15)
    end)
end


---comment
---@param letter "s"|"a"|"b"|"c"|"d"|"f"|string
function Customerencounter:getManualLetterGrade(letter)
    letter = string.lower(letter)
    if     letter == "s" then
        return "S", "grade_s", 1, 1, 0
    elseif letter == "a" then
        return "A", "grade_a", 0, 1, 0
    elseif letter == "b" then
        return "B", "grade_b", 0.5, 1, 0
    elseif letter == "c" then
        return "C", "grade_c", 1, 0.7, 0
    elseif letter == "d" then
        return "D", "grade_d", 1, 0.2, 0
    elseif letter == "f" then
        return "F", "grade_f", 0.8, 0, 0
    else
        return "F", "grade_f", 0.8, 0, 0
    end
end

--- Handles the customer feedback that appears when spared
---@param desired_rank any
---@param displayed_rep any
---@param displayed_gold any
function Customerencounter:manualSpareText(origin_x,origin_y, desired_rank, displayed_rep, displayed_gold)
    local rep_text = "+ "..displayed_rep.."REP"
    local gold_text = "+ ".. displayed_gold .."G"

    local ReputationText = Game.battle:addChild(Text(rep_text,origin_x, origin_y))
    ReputationText:setColor(0, 1, 0)

    local GoldText = Game.battle:addChild(Text(gold_text,origin_x, origin_y+ReputationText:getTextHeight()))
    GoldText:setColor(255, 204, 0)

    local rank, RankIconure, r,g,b = self:getManualLetterGrade(desired_rank);
    local RankIcon = Sprite('ranks/'..RankIconure,origin_x+ReputationText:getTextWidth()+5, origin_y + 20)
    local RankBell = Sprite('ranks/grade_bell',origin_x+ReputationText:getTextWidth()+45, origin_y + 40)

    if desired_rank ~= "none" then
        RankIcon:setScale(2)
        RankBell:setScale(2)
        RankIcon:setColor(r, g, b)
        RankBell:setColor(1, 1, 0)
        Game.battle:addChild(RankIcon)
        if rank == "S" then
            Game.battle:addChild(RankBell)
            Game.battle.timer:after(4/30, function () Assets.playSound("snd_ding", 1, 1) end)

            RankBell:play(0.2, false, function ()
                RankBell:fadeOutSpeedAndRemove(0.1)
            end)
        end
    end

    Game.battle.timer:script(function(wait)
        Game.battle.timer:tween(0.5, ReputationText, {y = origin_y-40}, 'in-out-quad')
        Game.battle.timer:tween(0.5, RankIcon, {y = origin_y-40}, 'in-out-quad')
        if RankBell then Game.battle.timer:tween(0.5, RankBell, {y = origin_y-60}, 'in-out-quad') end
        Game.battle.timer:tween(0.5, GoldText, {y = origin_y-(40-(ReputationText:getTextHeight()-10))}, 'in-out-quad')
        wait(2)
        Game.battle.timer:tween(0.5, ReputationText, {y = origin_y-60}, 'in-out-quad')
        Game.battle.timer:tween(0.5, RankIcon, {y = origin_y-60}, 'in-out-quad')
        if RankBell then Game.battle.timer:tween(0.5, RankBell, {y = origin_y-80}, 'in-out-quad') end
        Game.battle.timer:tween(0.5, GoldText, {y = origin_y-(60-(ReputationText:getTextHeight()-10))}, 'in-out-quad')
        ReputationText:fadeOutSpeedAndRemove(0.15)
        RankIcon:fadeOutSpeedAndRemove(0.12)
        GoldText:fadeOutSpeedAndRemove(0.15)
    end)
end

-- Draws the background as an object on a layer battlers can go below
function Customerencounter:onBattleStart()
    self.newbg = Sprite("world/Kitchenbg", 0, -10)
    self.newbg.layer = BATTLE_LAYERS["bottom"]
    Game.battle:addChild(self.newbg)
end

function Customerencounter:drawBackground()
    Draw.setColor (1, 1, 1, 1)

    if Game:getFlag("torielbattlebg") == true then
        Draw.draw(Assets.getTexture("world/KitchenbgToriel"), 0, 0)
    else
        --Draw.draw(Assets.getTexture("world/Kitchenbg"), 0, 0)
    end

    love.graphics.setLineWidth(3)

    Draw.setColor(102/255, 204/255, 61/255, 1)
    if self.showClock then
        love.graphics.line(70, 138, 70 + 20 * math.cos(self.clockAngle), 138 + 20 * math.sin(self.clockAngle))
    end
end

function Customerencounter:onBattleEnd()
    CustScore:finalizePoints()
end

function Customerencounter:onReturnToWorld()
    Game.music:stop()
    Game.world.music:play()
    if Game:getFlag("notEndDay") ~= true then --why does this keep deleting itself? make sure this one doesn't get lost in the shuffle, it's important
        Game.world:startCutscene("general.end_of_day")
    else
        Game:setFlag("notEndDay", false)
    end
end

return Customerencounter
