local Toriel, super = Class("CustomerBattler")
function Toriel:init()
    self.customerTime = 200
    self.notimer = true
    super.init(self)

  
    self:registerReputation(100) --registers base reputation as 50
   
    Stepscript:registerCustomer("TorielTutorialRecipe") -- This MUST be set in the battler!

    -- Enemy name
    self.name = _s("lightenemies-toriel-name", "Toriel")
    -- Sets the actor, which handles the enemy's sprites (see scripts/data/actors/dummy.lua)
    self:setActor("toriel")

    -- Enemy health
    self.max_health = 800
    self.health = 800
    -- Enemy attack (determines bullet damage)
    self.attack = 5
    -- Enemy defense (usually 0)
    self.defense = 0
    -- Enemy reward
    self.money = 69
    self.experience = 1
    
    self.dialogue_bubble = "ut_wide"

    -- List of possible wave ids, randomly picked each turn
    self.waves = {
        
        
    }



    self.menu_waves = {
        -- "aiming"
    }

    -- Dialogue randomly displayed in the enemy's speech bubble
    self.dialogue = {

    }

    -- Check text (automatically has "ENEMY NAME - " at the start)
    self.check = _s("lightenemies-toriel-check-001", "Butterscotch Pie\n* Wants to teach you how to COOK.\n* Better follow her lead!")

    -- Text randomly displayed at the bottom of the screen each turn
    self.text = {
        _s("lightenemies-toriel-text-001", "* Toriel looks at you with a patient smile."),
        _s("lightenemies-toriel-text-002", "* Toriel hovers close,[wait:5] ready to help."),
        _s("lightenemies-toriel-text-003", "* Toriel prepares some fire magic to help bake."),
        _s("lightenemies-toriel-text-004", "* Toriel knows how to COOK,[wait:5] better listen to her!")
        
    }
    -- Text displayed at the bottom of the screen when the enemy has low health
    self.low_health_text = "* The dummy looks like it's\nabout to fall over."

    -- Register act called "Smile"
    self:registerAct(_s("lightenemies-toriel-registerAct-001", "Talk"))
    self:registerAct(_s("lightenemies-toriel-registerAct-002", "Joke"))
    self:registerAct(_s("lightenemies-toriel-registerAct-003", "Flirt"))

    -- can be a table or a number. if it's a number, it determines the width, and the height will be 13 (the ut default).
    -- if it's a table, the first value is the width, and the second is the height
    self.gauge_size = 150

    self.sp = "npcs/toriel/lightbattle/"
    self.body = self:getSpritePart("body")
    self.h = self:getSpritePart("head")


    self.damage_offset = {5, -70}

    self.state = false
    self._cwk_tutorial_step_started = nil

    Game:setFlag("ReadyToEnd", false)
end

function Toriel:update()

    local state = Game.battle:getState()
    local steps = Game:getFlag("TorielSteps", 0)

    if steps == 0 then
        self._cwk_tutorial_step_started = nil
    end

    if state == 'ACTIONSELECT' then
        if steps == 1 and self._cwk_tutorial_step_started ~= 1 and Game.battle.cutscene == nil then
            self._cwk_tutorial_step_started = 1
            Game.battle:startCutscene("torieltutorial", "step1")

            -- A bunch of bullshit to make sure the game doesn't explode
            Game.battle.current_selecting = 0
            Game.battle:toggleSoul(false)
            Game.battle.battle_ui.encounter_text:setText("")
            self.text = {_s("lightenemies-toriel-text-005", "* It's time to mix the ingredients!")}

        end

        if steps == 2 and self._cwk_tutorial_step_started ~= 2 and Game.battle.cutscene == nil then
            self._cwk_tutorial_step_started = 2
            Game.battle:startCutscene("torieltutorial", "step2")

            -- A bunch of bullshit to make sure the game doesn't explode
            Game.battle.current_selecting = 0
            Game.battle:toggleSoul(false)
            Game.battle.battle_ui.encounter_text:setText("")
            self.text = {_s("lightenemies-toriel-text-006", "* Now to put the pie in the oven...")}
        end

        if steps == 3 and self._cwk_tutorial_step_started ~= 3 and Game.battle.cutscene == nil then
            self._cwk_tutorial_step_started = 3
            Game.battle:startCutscene("torieltutorial", "step3")

            -- A bunch of bullshit to make sure the game doesn't explode
            Game.battle.current_selecting = 0
            Game.battle:toggleSoul(false)
            Game.battle.battle_ui.encounter_text:setText("")

        end
    
    if Game:getFlag("ReadyToEnd") == true then

        Game.battle:setState("VICTORY")
    end

        
    end


end
function Toriel:onAct(battler, name)
    
    if name == "Talk" then
        Game.battle:startActCutscene("torieltutorial", "talk")
        
    end

    if name == "Joke" then
        Game.battle:startActCutscene("torieltutorial", "joke")
    end

    if name == "Flirt" then
        Game.battle:startActCutscene("torieltutorial", "flirt")
    end

    -- If the act is none of the above, run the base onAct function
    -- (this handles the Check act)
    return super.onAct(self, battler, name)
end

function Toriel:onMercy()
    
    Game.battle:startCutscene("torieltutorial", "spare")

        -- A bunch of bullshit to make sure the game doesn't explode
    Game.battle.current_selecting = 0
    Game.battle:toggleSoul(false)
    Game.battle.battle_ui.encounter_text:setText("")

end

function Toriel:onSpared()
    super.onSpared(self)
    
end


return Toriel