local Vulkin, super = Class("CustomerBattler")
function Vulkin:init()
    self.customerTime = 110
    super.init(self)

    local prefs = {}
    prefs["ketchup"] = 4
    prefs["cherry_bomb"] = 3
    prefs["spice_rice"] = 3
    prefs["relish"] = -2
    prefs["freeze_fry"] = -1
    prefs["chili"] = -1
    CustScore:regprefs(prefs)

    self:registerReputation(100) --registers base reputation as 50
   
    Stepscript:registerCustomer("VulkinRecipe")

    -- Enemy name
    self.name = _s("lightenemies-vulkin-name", "Vulkin")
    -- Sets the actor, which handles the enemy's sprites
    self:setActor("vulkin")

    self.capshroom_params = {"enemies/vulkin/lightbattle/vulkin_cap",3,-2}
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
        _s("lightenemies-vulkin-dialogue-001", "Toasty Bun?[wait:5] \nToasty Bun!"),
        _s("lightenemies-vulkin-dialogue-002", "Healing magma sauce![wait:5]\nWill you add it?"),
        _s("lightenemies-vulkin-dialogue-003", "Ahh![wait:5] Ah![wait:5]\nYummy foods!!"),
        _s("lightenemies-vulkin-dialogue-004", "Can I help with COOKing?"),
        _s("lightenemies-vulkin-dialogue-005", "Ah![wait:5] Warmy and Healthy!")
    }

    -- Check text (automatically has "ENEMY NAME - " at the start)
    self.check = _s("lightenemies-vulkin-check-001", "Toasty Bun![wait:5]\n* Mistakenly believes lava has significant health benefits.")

    -- Text randomly displayed at the bottom of the screen each turn
     
    
    -- Text displayed at the bottom of the screen when the enemy has low health
    self.low_health_text = "* The dummy looks like it's\nabout to fall over."

    self:registerAct(_s("lightenemies-vulkin-registerAct-001", "Encourage"))
    self:registerAct(_s("lightenemies-vulkin-registerAct-002", "Educate"))
    self:registerAct(_s("lightenemies-vulkin-registerAct-003", "Hug"))

    Game:setFlag("magmaSauce", false)

    -- can be a table or a number. if it's a number, it determines the width, and the height will be 13 (the ut default).
    -- if it's a table, the first value is the width, and the second is the height
    self.gauge_size = 150

    self.damage_offset = {5, -70}

    self.sprite_path = "enemies/vulkin/lightbattle/"

    self.body_sprite = Assets.getTexture(self.sprite_path .. "body")
    self.feet_back = Assets.getTexture(self.sprite_path .. "feet_back")
    self.feet_front = Assets.getTexture(self.sprite_path .. "feet_front")
    self.face = "neutral"
    self._cwk_face_textures = {}
    self._cwk_lava_textures = {
        Assets.getTexture(self.sprite_path .. "lava_1"),
        Assets.getTexture(self.sprite_path .. "lava_2"),
        Assets.getTexture(self.sprite_path .. "lava_3"),
        Assets.getTexture(self.sprite_path .. "lava_4"),
    }

    self.siner = 0
    self.pause = 0
    Game.battle.timer:after(1/3, function ()
        Game.battle.timer:everyInstant(1/2, function()
            if self.pause == 0 then
                local smoke = Game.battle:addChild(vulkin_smoke(self.x, self.y-140))
                smoke:setLayer(self.layer + 0.01)
            else
                return false
            end
        end)
    end)

    self.ingredient_dialogue = {
        ["default"] =_s("lightenemies-vulkin-ingredient_dialogue-default", {
            ["idgoeshere"] = {
                "Uwa...[wait:10] It's okay!"
            }
        }),

        ["ketchup"] =_s("lightenemies-vulkin-ingredient_dialogue-ketchup", {
            ["idgoeshere"] = {
                "Red sauce...[wait:10] Like magma!"
            }
        }),

        ["relish"] =_s("lightenemies-vulkin-ingredient_dialogue-relish", {
            ["idgoeshere"] = {
                "No green![wait:10] Green bad for health!"
            }
        }),

        ["cherry_bomb"] =_s("lightenemies-vulkin-ingredient_dialogue-cherry_bomb", {
            ["idgoeshere"] = {
                "Uwa...[wait:10] Nice and warm!!"
            }
        }),
        
        ["spice_rice"] =_s("lightenemies-vulkin-ingredient_dialogue-spice_rice", {
            ["idgoeshere"] = {
                "Uwa...[wait:10] Nice and warm!!"
            }
        }),

        ["freeze_fry"] =_s("lightenemies-vulkin-ingredient_dialogue-freeze_fry", {
            ["idgoeshere"] = {
                "OW![wait:10] Cold hurt!"
            }
        }),

        ["chili"] =_s("lightenemies-vulkin-ingredient_dialogue-chili", {
            ["idgoeshere"] = {
                "OW![wait:10] Cold hurt!"
            }
        })
    }
end

function Vulkin:update()
    super.update(self)


end

function Vulkin:growCapshroom()

    if not self.has_cap then
        local sprite = Sprite(self.capshroom_params[1],self.capshroom_params[2],self.capshroom_params[3])
        local poof = Sprite("particles/capshroom_poof",4,-14)
        poof.layer = 200
        sprite.layer = 100
        self:addChild(poof)
        poof:play(0.1,false,function()
            self:addChild(sprite)
            self.has_cap = true
            poof:setSprite("particles/capshroom_poof_end")
            poof:play(0.1,false,function() poof:remove() end)
        end)  
    end
end

function Vulkin:onAct(battler, name)
    
   
    if name == "Encourage" then
        Game.battle:startActCutscene("democustomers", "vulkinEncourage")
    elseif name == "Educate" then
        Game.battle:startActCutscene("democustomers", "vulkinEducate")
    elseif name == "Hug" then
        Game.battle:startActCutscene("democustomers", "vulkinHug")
    end

   
    -- If the act is none of the above, run the base onAct function
    -- (this handles the Check act)
    return super.onAct(self, battler, name)
end

function Vulkin:onSpared()
    self.pause = 2
    super.onSpared(self)
end

function Vulkin:draw()
    self.siner = self.siner + DTMULT

    if self.pause == 1 then
        self.siner = 0
        self.face = "hurt"
    elseif self.pause == 2 then
        self.siner = 0
    end

    local radsiner = self.siner

    local face_frame = math.ceil(math.max((self.siner/15)%2, 1/15))
    local face_key = self.face .. "_" .. face_frame
    local face_texture = self._cwk_face_textures[face_key]
    if not face_texture then
        face_texture = Assets.getTexture(self.sprite_path .. "faces/" .. face_key)
        self._cwk_face_textures[face_key] = face_texture
    end
    local lava_frame = math.ceil(math.max((self.siner/8)%4, 1/8))

    love.graphics.draw(self.feet_back, (2+math.cos(radsiner / 6)*2)/2, (102+math.sin(radsiner/6)*2)/2)
    love.graphics.draw(self.body_sprite)
    love.graphics.draw(face_texture, (22+math.sin(radsiner/12)*7)/2, 50/2, 0, 1-(math.abs(math.sin(radsiner / 12))*0.2)/2, 1)
    love.graphics.draw(self._cwk_lava_textures[lava_frame], 42/2, 10/2)
    love.graphics.draw(self.feet_front, (2+math.sin(radsiner / 6)*2)/2, (102+math.cos(radsiner/6)*2)/2)
    super.draw(self)
end

return Vulkin