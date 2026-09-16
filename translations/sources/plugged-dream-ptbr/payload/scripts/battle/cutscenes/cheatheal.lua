return function(cutscene)
    local function createForcePull(b, e)
        local data = {}
        data["value"]=0.5
        data["decrease"]=(0.085-Game.battle.enemies[1].mercy/100)-Utils.random(-1/2, 1/2)/10
        if data["decrease"]>0.085 then data["decrease"]=0.085 end
        if data["decrease"]<=0 then
            if Game.battle.enemies[1].mercy<90 then
                data["decrease"]=0.03
            else
                data["decrease"]=0.03
            end
        end
        --(1.09)
        print(data["decrease"])
        data["timer"]=Utils.random(120, 240)

        data["bg"]=Rectangle(93, 90, 430+15, 15)
        data["bg"].color={0, 0, 0}
        data["bg"].layer=BATTLE_LAYERS["top"]+10
        data["bg"].alpha=0
        Game.battle.timer:tween(0.5, data["bg"], {alpha=1})
        Game.battle:addChild(data["bg"])
        data["barPlayer"]=Rectangle(93, 90, (430*data["value"])+15, 15)
        data["barPlayer"].color={.7, .7, 1}
        data["barPlayer"].layer=BATTLE_LAYERS["top"]+13
        data["barPlayer"].alpha=0
        Game.battle.timer:tween(0.5, data["barPlayer"], {alpha=1})
        Game.battle:addChild(data["barPlayer"])
        data["barEnemy"]=Rectangle(553, 90, (430*data["value"])+15, 15)
        data["barEnemy"]:setOrigin(1, 0)
        data["barEnemy"].color={.5, .2, .7}
        data["barEnemy"].layer=BATTLE_LAYERS["top"]+12
        data["barEnemy"].alpha=0
        Game.battle.timer:tween(0.5, data["barEnemy"], {alpha=1})
        Game.battle:addChild(data["barEnemy"])

        data["keys"] = {"confirm", "left", "right", "up", "down", "menu", "cancel"}
        data["choosen_key"] = Utils.pick(data["keys"])

        data["text"]=Text("Aperte " .. (Input.getText(data["choosen_key"])) .. "!", 205, 40, {style = "none"})
        data["text"].layer=BATTLE_LAYERS["top"]+14
        Game.battle:addChild(data["text"])

        data["key_timer"] = 0
        data["key_timer_rect"] = Rectangle(93, 90, (430+15)*(1-data["key_timer"]/100), 7.5)
        data["key_timer_rect"]:setOrigin(0, 1)
        data["key_timer_rect"].layer=BATTLE_LAYERS["top"]+14
        data["key_timer_rect"].alpha=0
        Game.battle.timer:tween(0.5, data["key_timer_rect"], {alpha=1})
        Game.battle:addChild(data["key_timer_rect"])

        return data
    end

    cutscene:text("* Parece haver algumas combinações atrás do seu controle.")
    Assets.playSound("egg", 1.2, .85)
    cutscene:text("* Você pluga o controle no console, pronto pra digitar a combinação!")
    Game.battle.battle_ui.encounter_text:setText("* Aperte os botões na tela corretamente pra ativar o CURAHACK!")

    local kris = cutscene:getCharacter("kris")
    local romb = cutscene:getCharacter("romb")

    local forcePull = createForcePull(kris, romb)
    local rect = Rectangle(0, 0, SCREEN_WIDTH + 500, SCREEN_HEIGHT + 500)
    rect.color = {0, 0, 0}
    rect.layer = BATTLE_LAYERS["top"] + 9
    rect.alpha = 0
    Game.world:addChild(rect)
    local t = Timer()
    t:tween(.3, rect, {alpha = .3}, nil)
    rect:addChild(t)
    cutscene:wait(0.5)
    Assets.playSound("noise")
    cutscene:wait(0.5)
    cutscene:wait(0.5)
    local spam_counter = 1
    cutscene:wait(function()
    --print(forcePull["value"])
        forcePull["timer"]=forcePull["timer"]-DTMULT

            print(forcePull["key_timer"], 1-forcePull["key_timer"]/(25+(Game.battle.enemies[1].mercy/100)), spam_counter)
            forcePull["key_timer"] = forcePull["key_timer"] + DTMULT
            forcePull["key_timer_rect"].width = 430*(1-forcePull["key_timer"]/(25+(Game.battle.enemies[1].mercy/100)))+15

            if forcePull["key_timer"] >= 25+(Game.battle.enemies[1].mercy/100) then
                Assets.stopAndPlaySound("damage")
                forcePull["choosen_key"] = Utils.pick(forcePull["keys"])
                forcePull["text"]:setText("Aperte " .. (Input.getText(forcePull["choosen_key"])) .. "!")
                forcePull["key_timer"] = 0
                forcePull["value"]=forcePull["value"]-forcePull["decrease"]*DTMULT*2
            end

            if forcePull["value"]<0 then
            forcePull["value"]=0
        elseif forcePull["value"]>1 then
            forcePull["value"]=1
        end
        forcePull["barPlayer"].width=(430*forcePull["value"])
        forcePull["barEnemy"].width=430-forcePull["barPlayer"].width

    local time_succ = nil
    local spam = 0
        for i,key in ipairs(forcePull["keys"]) do
            if Input.pressed(key) then
                if key == forcePull["choosen_key"] then
                    Assets.playSound("impact")
                    time_succ = true
                else
                    time_succ = false
                end
                spam = spam + 1 --spam spam
            end
        end

    if time_succ == true then
        Assets.stopAndPlaySound("noise")
            kris:shake(math.random(2.5, 4.5), math.random(2.5, 4.5))
        if spam > 1 then
            spam_counter = spam_counter + 1
        end
        local value=0.25+math.random()/(Game:getFlag("altPull") and 15 or 5)
        print("Forced! Added "..value.." to the bar's value: "..forcePull["value"].."!")
        forcePull["value"]=forcePull["value"]+value
        forcePull["choosen_key"] = Utils.pick(forcePull["keys"])
        forcePull["text"]:setText("Aperte " .. (Input.getText(forcePull["choosen_key"])) .. "!")
        forcePull["key_timer"] = 0
    end
    if time_succ == false then
        Assets.stopAndPlaySound("damage")
            forcePull["choosen_key"] = Utils.pick(forcePull["keys"])
            forcePull["text"]:setText("Aperte " .. (Input.getText(forcePull["choosen_key"])) .. "!")
            forcePull["key_timer"] = 0
            forcePull["value"]=forcePull["value"]-forcePull["decrease"]*DTMULT*2
        end

    if forcePull["timer"]<=0 then
        return true
    end
    return false
    end)
    forcePull["text"]:remove()
    Game.battle.timer:tween(0.5, forcePull["key_timer_rect"], {alpha=0}, "linear", function() forcePull["key_timer_rect"]:remove() end)

    forcePull["barPlayer"].width=(430*forcePull["value"])
    forcePull["barEnemy"].width=430-forcePull["barPlayer"].width
    Game.battle.timer:tween(0.5, forcePull["bg"], {alpha=0}, "linear", function() forcePull["bg"]:remove() end)
    Game.battle.timer:tween(0.5, forcePull["barPlayer"], {alpha=0}, "linear", function() forcePull["barPlayer"]:remove() end)
    Game.battle.timer:tween(0.5, forcePull["barEnemy"], {alpha=0}, "linear", function() forcePull["barEnemy"]:remove() end)
    rect:remove()
    t:remove()
    Game.battle.battle_ui.encounter_text:setText("")
    Assets.playSound("impact")
    cutscene:wait(0.5)
    if forcePull.value > 0 then
        if spam_counter > forcePull.value * 10 then
            spam_counter = forcePull.value * 10
        end
        Game.battle.party[1]:heal(Utils.round((11 * forcePull.value) / spam_counter * math.random(9.5, 11.5)))
    else
        Game.battle.party[1]:heal(10)
    end
    cutscene:text("* CURAHACK foi ativado com sucesso!")
end
