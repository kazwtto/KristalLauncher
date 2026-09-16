return {
    death = function(cutscene, event)
        if Mod.flags.ramb_dead ==  true then
            cutscene:text("* (É uma estátua.)")
            if Mod.flags.ramb_food_not_found == true then
                cutscene:text("* (Você revistou os bolsos da estátua.)")
                cutscene:text("* (Tudo que achou foi comida de TV.)")
                Game.inventory:addItem("tvslop")
                Assets.playSound("item")
                cutscene:text("* (Você obteve RangoDeTV.)")
                Mod.flags.ramb_food_not_found = false
            end
        else
            cutscene:text("* Kris! Querido, como vão as coisas?")
            cutscene:text("* Lembra quando congelei feito estátua no Camarim?")
            cutscene:text("* Cara, que susto", "jihi", "ramb", {auto=true})
            local ramb = cutscene:getCharacter("ramb")
            cutscene:wait(.5)
            ramb:setSprite("stone_full")
            Assets.playSound("badexplosion")
            cutscene:wait(2.25)
            cutscene:text("* Merda.")
            Mod.flags.ramb_dead = true
            Mod.flags.ramb_food_not_found = true
        end
    end,

    cinematic = function(cutscene, event)
        local kris = cutscene:getCharacter("kris")
        cutscene:fadeOut(.01)
        cutscene:fadeIn(5)
        if Game.party[1] then
            Game.party[1].stats.health = 160
            Game.party[1].health = 160
            Game.party[1].max_stats.health = 160
        end

        Game.world.music:play("board_ocean")
        local shadoweth = Sprite("tilesets/shadoweth", 0, 0)
        local static = Sprite("tilesets/plugged", 0, 0)
        static:play(.3, true)
        Game.world:spawnObject(shadoweth, 1000)
        Game.world:spawnObject(static, 0)

        Game.world.player:setColor(0, 0, 0)
        for _, follower in ipairs(Game.world.followers) do
            follower:setColor(0, 0, 0)
        end
    end
}
