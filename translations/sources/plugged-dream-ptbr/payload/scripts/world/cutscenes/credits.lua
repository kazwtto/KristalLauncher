return function(cutscene)
    local yellow_text = "Obrigado por se divertir."
    Kristal.saveConfig()

    cutscene:fadeOut(0)
    cutscene:wait(2)

    Kristal.hideBorder(1)
    local theme = Music("ch2_credits")
    theme.source:setLooping(false)

    local text = Text("a", (SCREEN_WIDTH/2) + 30, (SCREEN_HEIGHT/2) - 100, nil, nil, {style = "none", skip = false, spacing = 500})
    text.align = "center"
    text:setText("\n[color:yellow]PLUGGED DREAM[color:reset]\n\nPor\nFunkin's Garbage")
    text.layer = WORLD_LAYERS["top"]
    Game.world:addChild(text)

    cutscene:wait(3.35)

    text:setText("Um fangame de\nDELTARUNE\n\nPor\nToby Fox")

    cutscene:wait(3.35)

    text:setText("[color:555555]Motor de Jogo[color:reset]\nKristal\n\nA Equipe Kristal")

    cutscene:wait(3.35)

    text:setText("[color:555555]Sprites[color:reset]\n\nDELTARUNE\nFunkin's Garbage")

    cutscene:wait(3.35)

    text:setText("[color:555555]Músicas[color:reset]\nSWORD\nGLACIER\nBIT ROOTS\nGlowing Snow\n\nToby Fox")

    cutscene:wait(3.35)

    text:setText("[color:555555]Música[color:reset]\nKAIZO\n\nW.D.Gaster")

    cutscene:wait(3.35)

    text:setText("[color:555555]Efeitos Sonoros[color:reset]\n\nDELTARUNE\nDELTARUNE: Fun Town")

    cutscene:wait(3.35)

    text:setText("[color:555555]Design de Ramb[color:reset]\n\nW.D.Gaster (Inspiração)\nFunkin's Garbage")

    cutscene:wait(3.35)

    text:setText("[color:555555]Bibliotecas[color:reset]\nRecriações de Inimigos\n(Werewire)\n\nSylvi")

    cutscene:wait(3.35)

    text:setText("[color:555555]Bibliotecas[color:reset]\nBoard Writer\n\nMihBoss")

    cutscene:wait(3.35)

    text:setText("[color:555555]Bibliotecas[color:reset]\nShadows\n\nAcousticJamm")

    cutscene:wait(3.35)

    text:setText("[color:555555]Bibliotecas[color:reset]\nPurple Soul\n\nFunkin's Garbage\n(Com ajuda da Green Soul\nLibrary de KateBulka)")

    cutscene:wait(3.35)

    text:setText("[color:555555]Betatesters[color:reset]\n\nEggraft")

    cutscene:wait(3.35)

    text:setText("[color:555555]Agradecimentos Especiais[color:reset]\nSimbel\npor ajudar na\nação de cura")

    cutscene:wait(3.35)

    text:setText("[color:555555]Agradecimentos Especiais[color:reset]\nAo servidor do Kristal no\nDiscord pelo apoio")

    cutscene:wait(3.35)

    text:setText("[color:555555]Jogando este jogo[color:reset]\n\n" .. ((Game.save_name ~= "PLAYER" and Game.save_name or "You")))

    cutscene:wait(3.35)

    local fx = AlphaFX(0)

    text.color = {1, 1, 0}
    text:addFX(fx)
    text.y = (SCREEN_HEIGHT/2) - 50
    text:setText(yellow_text)
    Game.world.timer:tween(3, fx, {alpha = 1})
    cutscene:wait(6)

    Game.world.timer:tween(3, fx, {alpha = 0})
    Game.world.timer:tween(3, text, {color = {.65, .6, .85}})
    cutscene:wait(5)

    --Should be useless, but...
    cutscene:wait(function()
        return not theme:isPlaying()
    end)

    -- Why the fuck do I need to use cutscene:after() now??
    cutscene:after(function()
        Kristal.returnToMenu()
    end, true)
end

--FROZEN HEART by Simbel
--Deltarune by Toby Fox
--Kristal Engine
--Sprites by Toby Fox
--Music by Toby Fox, ...
--Betatester, uh...
--Thanks to the helper
--The secret...?
