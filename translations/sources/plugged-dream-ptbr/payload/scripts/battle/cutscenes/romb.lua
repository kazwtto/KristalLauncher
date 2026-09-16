return {
    shake1 = function(cutscene, battler, enemy)
        enemy:shake(Utils.random(1, 4), Utils.random(1, 4))
        Assets.playSound("damage")
        cutscene:text("* Você sacudiu o cabo da criatura.\n[wait:5]* Foi eficaz!")
        cutscene:text("* A Defesa de RAMBHACK aumentou!")
    end,

    shake2 = function(cutscene, battler, enemy)
        enemy:shake(Utils.random(1, 5), Utils.random(1, 5))
        Assets.playSound("damage")
        Assets.playSound("electric_talk", 1, 1.5)
        cutscene:text("* Você sacudiu o cabo de novo.\n[wait:5]* Começou a soltar faísca e resmungar!")
        cutscene:text("* A Defesa de RAMBHACK aumentou!")
    end,

    shake3 = function(cutscene, battler, enemy)
        local kris = cutscene:getCharacter("kris")
        kris:setAnimation("jiggle")
        enemy:shake(Utils.random(1, 3), Utils.random(1, 3))
        Assets.playSound("damage")
        cutscene:text("* Você sacudiu o cabo ainda mais, mas.[wait:8].[wait:8].[wait:8]")
        Assets.playSound("wing")
        kris:shake(2, 2)
        kris:setAnimation("battle/defeat")
        cutscene:text("* A Defesa de RAMBHACK ficou alta o bastante para resistir.")
        cutscene:text("* Parece que sacudir não surte mais efeito.")
        cutscene:text("* .[wait:8].[wait:8].[wait:8]")
        Assets.playSound("wing")
        kris:shake(2, 2)
        kris:setAnimation("battle/idle")
        Assets.playSound("egg", 1.2, 0.85)
        cutscene:text("* De repente, você lembrou do seu controle.")
        cutscene:text("* Se plugar no console, [wait:5]talvez consiga se conectar.")
        cutscene:text("* (Tente usar as novas [color:yellow]AÇÕES[color:reset] pra se conectar ao RAMBHACK!)")
    end,

    shake4 = function(cutscene, battler, enemy)
        cutscene:text("* (Sacudir parece inútil agora.\n[wait:5]* Tente outras [color:yellow]AÇÕES[color:reset].)")
    end,

    connect1 = function(cutscene, battler, enemy)
        local ramb = cutscene:getCharacter("romb")
        cutscene:text("* Você pluga o controle no console.[wait:5].[wait:5].[wait:5]")
        Assets.playSound("egg", 1.2, .85)
        cutscene:text("* Conexão estabelecida com sucesso![wait:10]\n* Agora você pode interagir com RAMBHACK!")

        cutscene:battlerText(ramb, ".[wait:5].[wait:5].[wait:5]KRIS?")
        cutscene:battlerText(ramb, "KRIS! [wait:5]É VOCÊ \nMESMO?")
        cutscene:battlerText(ramb, "NÃO CONSIGO ENXERGAR \nDIREITO AGORA.")
        cutscene:battlerText(ramb, "TALVEZ VOCÊ CONSIGA?")
        cutscene:battlerText(ramb, "VER A LÂMINA.")

        -- Game.battle.enemies[1].wave_override = "mantle_0"
        ramb.connected = true
    end,

    connect2 = function(cutscene, battler, enemy)
        local ramb = cutscene:getCharacter("romb")
        cutscene:text("* Você implora para a criatura parar de atacar.")

        cutscene:battlerText(ramb, "O QUÊ?[wait:5]\nDESPLUGAR, É ISSO?")
        cutscene:battlerText(ramb, "OH, KRIS! [wait:5]COMO \nNÃO REPAROU\nNISSO?")
        cutscene:battlerText(ramb, "A LÂMINA NÃO É \nDIVERTIDA QUANDO \nVOCÊ GOLPEIA?")
        cutscene:battlerText(ramb, "DÁ UM GOLPE \nNO AR, [wait:5]\nQUERIDO!")
        cutscene:battlerText(ramb, "SÓ MAIS UMA VEZ.")

        -- Game.battle.enemies[1].wave_override = "mantle_0"
        ramb.connected = true
    end,

    connect3 = function(cutscene, battler, enemy)
        local ramb = cutscene:getCharacter("romb")
        cutscene:text("* Você diz que não quer mais jogar.")

        cutscene:battlerText(ramb, "KRIS, [wait:5]TÁ PERDENDO \nTANTA COISA, [wait:5]AMIGÃO!")
        cutscene:battlerText(ramb, "EU TE CONHEÇO, [wait:5]KRIS.")
        cutscene:battlerText(ramb, "NUNCA DEIXA UM \nJOGO PELA METADE.")
        cutscene:battlerText(ramb, "NUNCA.")
        cutscene:battlerText(ramb, "NEM MESMO \nNA NEVE MAIS \nPROFUNDA.")

        -- Game.battle.enemies[1].wave_override = "mantle_0"
        ramb.connected = true
    end,

    connect4 = function(cutscene, battler, enemy)
        local ramb = cutscene:getCharacter("romb")
        cutscene:text("* Você tenta alcançar a criatura.")

        cutscene:battlerText(ramb, "QUE CARA É ESSA, \n[wait:5]QUERIDO?")
        cutscene:battlerText(ramb, "É LIBERDADE, [wait:5]KRIS!")
        cutscene:battlerText(ramb, "SERÁ QUE.[wait:5].[wait:5].")
        cutscene:battlerText(ramb, "OS JOGOS ERAM \nMELHORES COM \nSEU IRMÃO?")
        cutscene:battlerText(ramb, "Ele devia ser a \nchave pra sua \nfelicidade.")
        cutscene:battlerText(ramb, ".[wait:5].[wait:5].[wait:5]Não era?")

        -- Game.battle.enemies[1].wave_override = "mantle_0"
        ramb.connected = true
    end,

    connect5 = function(cutscene, battler, enemy)
        local ramb = cutscene:getCharacter("romb")
        cutscene:text("* Você escuta a criatura.")

        cutscene:battlerText(ramb, "E A FAMÍLIA RENA.[wait:5].[wait:5].")
        cutscene:battlerText(ramb, "OH, [wait:5]QUE \nALEGRIA \nERA!")
        cutscene:battlerText(ramb, "A PEQUENA \nJOGANDO COM \nVOCÊ,")
        cutscene:battlerText(ramb, "ESSES JOGOS \nTÃO ALEGRES!")

        -- Game.battle.enemies[1].wave_override = "mantle_0"
        ramb.connected = true
    end,

    connect6 = function(cutscene, battler, enemy)
        local ramb = cutscene:getCharacter("romb")
        cutscene:text("* Você continua escutando a criatura.")

        cutscene:battlerText(ramb, "AINDA ASSIM, \n[wait:5]NO FIM \nDE TUDO,")
        cutscene:battlerText(ramb, "TODOS FORAM EMBORA.")
        cutscene:battlerText(ramb, "TODOS PERDERAM \nO BRILHO.")
        cutscene:battlerText(ramb, "SEUS OLHOS ARDENTES.")
        cutscene:battlerText(ramb, "UM NOS NEGÓCIOS, [wait:5]\nOUTRO NO HOSPITAL,")
        cutscene:battlerText(ramb, "E OS OUTROS?")
        cutscene:battlerText(ramb, "...")
        cutscene:battlerText(ramb, "FORAM ESGOTADOS.")

        -- Game.battle.enemies[1].wave_override = "mantle_0"
        ramb.connected = true
    end,

    connect7 = function(cutscene, battler, enemy)
        local ramb = cutscene:getCharacter("romb")
        cutscene:text("* Você pensa por um instante [wait:5]e volta a escutar.")

        cutscene:battlerText(ramb, "E VOCÊ.")
        cutscene:battlerText(ramb, "VOCÊ NÃO NOS DEIXOU!")
        cutscene:battlerText(ramb, "ATÉ AGORA, [wait:5]ESTÁ \nJOGANDO ESSES JOGOS!")
        cutscene:battlerText(ramb, "VAMOS, [wait:5]QUEBRE \nAS CORRENTES, [wait:5]KRIS!")
        cutscene:battlerText(ramb, "ESSES JOGOS... [wait:5]\nTUDO ISSO...")
        cutscene:battlerText(ramb, "Você não esqueceu \ncomo jogar,")
        cutscene:battlerText(ramb, "Você não esqueceria \ndepois daquilo.")
        cutscene:battlerText(ramb, "Disso eu tenho certeza.")

        -- Game.battle.enemies[1].wave_override = "mantle_0"
        ramb.connected = true
    end,

    connect8 = function(cutscene, battler, enemy)
        local ramb = cutscene:getCharacter("romb")
        cutscene:text("* Você desvia o olhar do rosto da criatura.")

        cutscene:battlerText(ramb, "Kris, [wait:5]o que houve?")
        cutscene:battlerText(ramb, "Continuar jogando \nos jogos?")
        cutscene:battlerText(ramb, "Calma, calma.")
        cutscene:battlerText(ramb, "Vem cá \num \n", {auto = true})

        enemy:shake(Utils.random(1, 3), Utils.random(1, 3))
        Assets.playSound("damage")
        cutscene:wait(.4)

        enemy:shake(Utils.random(1, 3), Utils.random(1, 3))
        Assets.playSound("damage")
        cutscene:wait(.4)

        cutscene:battlerText(ramb, "ESTÁ BEM, KRIS?")
        cutscene:battlerText(ramb, "VAMOS LÁ, [wait:5]\nOLHE PRA MIM.")
        cutscene:battlerText(ramb, "OLHE PARA OS", {auto = true})

        enemy:shake(Utils.random(1, 3), Utils.random(1, 3))
        Assets.playSound("damage")

        cutscene:battlerText(ramb, "OLHE PARA OS CÉUS!")
        cutscene:battlerText(ramb, "VEJA ELES CANTAREM!")

        -- Game.battle.enemies[1].wave_override = "mantle_0"
        ramb.connected = true
    end,

    connect9 = function(cutscene, battler, enemy)
        local ramb = cutscene:getCharacter("romb")
        cutscene:text("* Você finge ignorar a criatura.")

        enemy:shake(Utils.random(1, 3), Utils.random(1, 3))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "KRIS, [wait:5]VOCÊ NÃO \nENTENDE?")
        cutscene:battlerText(ramb, "QUEM LIGA SE OS \nJOGOS SÃO \nRUINS!")
        cutscene:battlerText(ramb, "QUEM LIGA SE OS \nJOGOS SÃO \nREPETITIVOS!")
        cutscene:battlerText(ramb, "POR QUE MAIS VOCÊ \nCRIARIA UMA \nFONTE?")
        cutscene:battlerText(ramb, "POR QUE MAIS \nCRIARIA \"A GENTE\".[wait:5].[wait:5]?")

        -- Game.battle.enemies[1].wave_override = "mantle_0"
        ramb.connected = true
    end,

    connect10 = function(cutscene, battler, enemy)
        local ramb = cutscene:getCharacter("romb")
        cutscene:text("* Você observa o cabo da criatura.")
        cutscene:text("* Você tenta sacudi-lo.")
        cutscene:text("* Você tenta golpeá-lo.")
        cutscene:text("* Você tenta chutá-lo.")
        cutscene:text("* Você tenta tudo que pode.")
        cutscene:text("* Mas não consegue alcançar.")
        cutscene:text("* .[wait:5].[wait:5].[wait:10]\n* Então, [wait:5]você implora pra criatura se desplugar.")

        enemy:shake(Utils.random(1, 3), Utils.random(1, 3))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "Kris, [wait:5]eu não posso...")

        enemy:shake(Utils.random(1, 3), Utils.random(1, 3))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "Eu não consigo parar.")

        enemy:shake(Utils.random(1, 3), Utils.random(1, 3))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "Se eu pudesse,")
        cutscene:battlerText(ramb, "Eu...")

        enemy:shake(Utils.random(1, 3), Utils.random(1, 3))
        Assets.playSound("damage")
        cutscene:wait(.2)

        enemy:shake(Utils.random(1, 4), Utils.random(1, 4))
        Assets.playSound("damage")
        cutscene:wait(.2)

        enemy:shake(Utils.random(1, 5), Utils.random(1, 5))
        Assets.playSound("damage")
        cutscene:wait(.2)

        cutscene:battlerText(ramb, "[shake:0.5]EU [wait:3]NUNCA [wait:3]FARIA [wait:3]\nNADA DISSO!")
        cutscene:battlerText(ramb, "KRIS.")
        cutscene:battlerText(ramb, "A LIBERDADE.")
        cutscene:battlerText(ramb, "O TEMPO DA \nLIBERDADE ESTÁ \nACABANDO!")

        enemy:shake(Utils.random(1, 5), Utils.random(1, 5))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "ESTÁ À NOSSA ESPERA.")
        cutscene:battlerText(ramb, "NO FINAL.")
        cutscene:battlerText(ramb, "E VOCÊ VAI SÓ.[wait:5].[wait:5].[wait:5]\nEMBORA ENTÃO?")
        cutscene:battlerText(ramb, "DEPOIS DOS JOGOS,\n[wait:5]DA NOSSA ALEGRIA,")
        cutscene:battlerText(ramb, "[shake:1]NÓS [wait:2]NUNCA [wait:2]\nIREMOS [wait:2]MORRER.")

        -- Game.battle.enemies[1].wave_override = "mantle_0"
        ramb.connected = true
    end,

    connect11 = function(cutscene, battler, enemy)
        local ramb = cutscene:getCharacter("romb")
        cutscene:text("* Você começa a", nil, nil, {auto = true})

        enemy:shake(Utils.random(1, 3), Utils.random(1, 3))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "AÍ ESTÁ, [wait:5]KRIS.")

        enemy:shake(Utils.random(1, 3), Utils.random(1, 3))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "A ÁREA FINAL!")

        enemy:shake(Utils.random(1, 3), Utils.random(1, 3))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "É O QUE ESTÁVAMOS \nESPERANDO.")
        cutscene:battlerText(ramb, "O DESAFIO \nTÃO, [wait:5]TÃO DIFÍ", {auto = true})

        enemy:shake(Utils.random(1, 3), Utils.random(1, 3))
        Assets.playSound("damage")
        cutscene:wait(.2)

        enemy:shake(Utils.random(1, 4), Utils.random(1, 4))
        Assets.playSound("damage")
        cutscene:wait(.2)

        enemy:shake(Utils.random(1, 5), Utils.random(1, 5))
        Assets.playSound("damage")
        cutscene:wait(.2)

        cutscene:battlerText(ramb, "[shake:1]O QUE ESTÁ HOUVENDO?!")
        cutscene:battlerText(ramb, "POR QUE O CABO.[wait:5].[wait:5].")
        cutscene:battlerText(ramb, "ESPERA UM POUCO.")

        enemy:shake(Utils.random(1, 5), Utils.random(1, 5))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[shake:1]KRIS! [wait:5]\nO QUE [wait:2]VOCÊ [wait:2]ESTÁ [wait:2]FAZENDO?!")

        enemy:shake(Utils.random(1, 5), Utils.random(1, 5))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "DÁ PRA PARAR \nDE SACUDIR \nISSO", {auto = true})

        enemy:shake(Utils.random(1, 5), Utils.random(1, 3))
        Assets.playSound("damage")
        cutscene:wait(.2)

        enemy:shake(Utils.random(1, 6), Utils.random(1, 6))
        Assets.playSound("damage")
        cutscene:wait(.2)

        enemy:shake(Utils.random(1, 7), Utils.random(1, 7))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[shake:1]PARE [wait:2]COM ISSO.")
        cutscene:battlerText(ramb, "[shake:1]PORQUE [wait:2]SE [wait:2]NÃO [wait:2]PARAR,")
        cutscene:battlerText(ramb, "[color:red]EU[color:reset] vou ajudar \ncom isso.")

        -- Game.battle.enemies[1].wave_override = "mantle_0"
        ramb.connected = true
    end,

    finale = function(cutscene, battler)
        local ramb = cutscene:getCharacter("romb")
        ramb:shake(Utils.random(1, 3), Utils.random(1, 3))
        Assets.playSound("damage")
        cutscene:wait(.5)

        ramb:shake(Utils.random(1, 4), Utils.random(1, 4))
        Assets.playSound("damage")
        cutscene:wait(.5)

        cutscene:battlerText(ramb, "UAU, [wait:5]KRIS!")
        cutscene:battlerText(ramb, "VOCÊ É BOM EM \nDESVIAR.")
        cutscene:battlerText(ramb, "O QUE SERÁ QUE \nVOCÊ GANHA...")

        ramb:shake(Utils.random(1, 4), Utils.random(1, 4))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "...DEPOIS DO \nNOVO JOGO+?")

        ramb.ngp = true
    end,

    connect_test = function(cutscene, battler, enemy)
        local ramb = cutscene:getCharacter("romb")
        cutscene:text("* Eu sou um pneu!")
        cutscene:battlerText(ramb, "Eu sou um pneu!")

        --[[ Assets.playSound("ominoux")
        if Game.party[1] then
            if Game.party[1].stats.health >= 184 then
                Game.party[1].stats.health = Game.party[1].stats.health + 4
                Game.party[1].health = Game.party[1].health + 4
                Game.party[1].max_stats.health = Game.party[1].max_stats.health + 4
            else
                Game.party[1].stats.health = Game.party[1].stats.health + 3
                Game.party[1].health = Game.party[1].health + 3
                Game.party[1].max_stats.health = Game.party[1].max_stats.health + 3
            end
        end
        Game.battle.enemies[1]:addMercy(8)]]
    end,

    mercy = function(cutscene, battler, enemy)
        local ramb = cutscene:getCharacter("romb")
        Assets.playSound("egg", 1.2, .85)
        cutscene:text("* Conexão", nil, nil, {auto = true})

        Assets.stopSound("egg")
        Assets.playSound("damage")
        enemy:shake(Utils.random(1, 7), Utils.random(1, 7))
        cutscene:battlerText(ramb, "[shake:1]O QUE ESTÁ \nTENTANDO FAZER?!")
        cutscene:battlerText(ramb, "[shake:1]PARE DE APERTAR \nOS BOTÕES \n", {auto = true})

        enemy:shake(Utils.random(1, 6), Utils.random(1, 6))
        Assets.playSound("damage")
        cutscene:wait(.2)

        enemy:shake(Utils.random(1, 7), Utils.random(1, 7))
        Assets.playSound("damage")
        cutscene:wait(.2)

        enemy:shake(Utils.random(1, 8), Utils.random(1, 8))
        Assets.playSound("damage")
        cutscene:wait(.2)

        cutscene:battlerText(ramb, "[shake:1]KRIS, PARE\n", {auto = true})

        enemy:shake(Utils.random(1, 9), Utils.random(1, 9))
        Assets.playSound("damage")
        cutscene:wait(.2)

        cutscene:battlerText(ramb, "[shake:1]SEU PIRRALHO\n", {auto = true})

        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:wait(.2)

        cutscene:battlerText(ramb, "[shake:1]PARE\nAGORA\nMESMO", {auto = true})

        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:wait(.2)

        cutscene:battlerText(ramb, "[shake:1]PARE DE MEXER \nNESSE CONTROLE!!!", {auto = true})

        Game.battle.enemies[1]:addMercy(1)
        Assets.playSound("ominoux")
        Game.party[1].stats.health = Game.party[1].stats.health + 1
        Game.party[1].health = Game.party[1].health + 1
        Game.party[1].max_stats.health = Game.party[1].max_stats.health + 1
        Game.battle.enemies[1].idle_moves = false
        Game.battle.music:pause()
        cutscene:wait(2)

        cutscene:battlerText(ramb, "[shake:.2]O Q-")
        cutscene:battlerText(ramb, "[shake:.5]O QUÊ?!")

        Game.battle.music:resume("ramb_boss")
        Game.battle.music:setPitch(Utils.random(1.3, 2.5))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:wait(.2)

        cutscene:battlerText(ramb, "[noskip][shake:1]EI, LARGA ESSE \nCONTROLE", {auto = true})

        Game.battle.music:setPitch(Utils.random(1.4, 2.6))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1]PARE DE BRINCAR \nCOM ISSO", {auto = true})

        Game.battle.music:setPitch(Utils.random(1.5, 2.7))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1]VOCÊ NÃO SABE O \nQUE ESTÁ FAZENDO", {auto = true})

        Game.battle.music:setPitch(Utils.random(1.6, 2.8))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        Assets.playSound("ominoux")
        Game.party[1].stats.health = Game.party[1].stats.health + 1
        Game.party[1].health = Game.party[1].health + 1
        Game.party[1].max_stats.health = Game.party[1].max_stats.health + 1
        Game.battle.enemies[1]:addMercy(1)
        cutscene:battlerText(ramb, "[noskip][shake:1]ESTOU TENTANDO TE \nDAR LIBERDADE", {auto = true})

        Game.battle.music:setPitch(Utils.random(1.7, 2.9))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1]VOCÊ SÓ VAI PERDER \nTAN", {auto = true})

        Game.battle.music:setPitch(Utils.random(1.8, 3))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1]POR QUE NÃO PARA?! \nPOR QUE NÃO", {auto = true})

        Game.battle.music:setPitch(Utils.random(1.9, 3.1))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1]NÃO VAI NOS DEIXAR", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        Assets.playSound("ominoux")
        Game.party[1].stats.health = Game.party[1].stats.health + 1
        Game.party[1].health = Game.party[1].health + 1
        Game.party[1].max_stats.health = Game.party[1].max_stats.health + 1
        Game.battle.enemies[1]:addMercy(1)
        cutscene:battlerText(ramb, "[noskip][shake:1]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:1.2]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:1.4]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:1.6]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:1.8]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:2]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:2.2]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:2.4]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:2.6]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:2.8]PARE \nPARE \nPARE", {auto = true})

        cutscene:fadeOut(0)

        Game.battle.music:pause()
        Assets.playSound("damage")
        Assets.playSound("ominoux")
        Assets.playSound("ominoux", .7, .7)
        Assets.playSound("ominoux", .4, .4)
        Assets.playSound("ominoux", .1, .1)
        Game.world:loadMap("consoleroom")
        Game:setBorder("none", 0)
        Game.party[1].stats.health = Game.party[1].stats.health + 1
        Game.party[1].health = Game.party[1].health + 1
        Game.party[1].max_stats.health = Game.party[1].max_stats.health + 1
        Game.battle.enemies[1]:addMercy(1)
        cutscene:wait(4)

        if Game.party[1] then
            Game.party[1].stats.health = 160
            Game.party[1].health = 160
            Game.party[1].max_stats.health = 160
        end
        cutscene:fadeIn(2)
        Game.battle:returnToWorld()
        Game.world:startCutscene("ramb_ending", "mercy")
        -- Game.battle:returnToWorld()
        -- Game.world:loadMap("consoleroom")
    end,

    fight = function(cutscene, battler, enemy)
        local kris = cutscene:getCharacter("kris")
        local ramb = cutscene:getCharacter("romb")

        Game.battle.music:pause()
        Game.battle.battle_ui.encounter_text:setText("")
        kris:shake(2, 2)
        kris:setAnimation("battle/attack")
        enemy:shake(Utils.random(1, 8), Utils.random(1, 8))
        Assets.playSound("damage")
        cutscene:wait(.5)

        kris:shake(2, 2)
        kris:setAnimation("battle/attack")
        enemy:shake(Utils.random(1, 8), Utils.random(1, 8))
        Assets.playSound("damage")
        cutscene:wait(.5)

        kris:shake(2, 2)
        kris:setAnimation("battle/attack")
        enemy:shake(Utils.random(1, 8), Utils.random(1, 8))
        Assets.playSound("damage")
        cutscene:wait(.5)

        cutscene:battlerText(ramb, "[shake:1]O QUE ESTÁ FAZENDO?!")
        cutscene:battlerText(ramb, "POR QUE NÃO PODE \nSÓ \n", {auto = true})

        kris:shake(2, 2)
        kris:setAnimation("battle/attack")
        enemy:shake(Utils.random(1, 6), Utils.random(1, 6))
        Assets.playSound("damage")
        cutscene:wait(.3)

        kris:shake(2, 2)
        kris:setAnimation("battle/attack")
        enemy:shake(Utils.random(1, 6), Utils.random(1, 6))
        Assets.playSound("damage")
        cutscene:wait(.3)

        Assets.playSound("criticalswing")
        kris:shake(3, 3)
        kris:setAnimation("battle/attack")
        enemy:shake(Utils.random(1, 6), Utils.random(1, 6))
        Assets.playSound("damage")
        cutscene:wait(1)

        cutscene:battlerText(ramb, "TUDO BEM, [wait:5]EU \nJÁ ENTENDI.")
        kris:setAnimation("battle/idle")
        cutscene:battlerText(ramb, "EU ENTENDI, [wait:5]KRIS!")

        enemy:shake(Utils.random(1, 9), Utils.random(1, 9))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "SE NINGUÉM \nQUER JOGAR \nJOGOS,")
        cutscene:battlerText(ramb, "SE NINGUÉM \nQUER SER \nLIVRE,")
        cutscene:battlerText(ramb, "[speed:.5]NINGUÉM SERÁ.")

        enemy:shake(Utils.random(1, 9), Utils.random(1, 9))
        Assets.playSound("damage")
        cutscene:wait(.5)

        enemy:shake(Utils.random(1, 9), Utils.random(1, 9))
        Assets.playSound("damage")
        cutscene:wait(.5)

        enemy:shake(Utils.random(1, 9), Utils.random(1, 9))
        Assets.playSound("damage")
        cutscene:wait(.45)

        enemy:shake(Utils.random(1, 9), Utils.random(1, 9))
        Assets.playSound("damage")
        cutscene:wait(.40)

        enemy:shake(Utils.random(1, 9), Utils.random(1, 9))
        Assets.playSound("damage")
        cutscene:wait(.30)

        enemy:shake(Utils.random(1, 9), Utils.random(1, 9))
        Assets.playSound("damage")
        cutscene:wait(.20)

        enemy:shake(Utils.random(1, 9), Utils.random(1, 9))
        Assets.playSound("damage")
        cutscene:wait(.10)

        enemy:shake(Utils.random(1, 9), Utils.random(1, 9))
        Assets.playSound("damage")
        cutscene:wait(.5)

        enemy:shake(Utils.random(1, 9), Utils.random(1, 9))
        Assets.playSound("damage")
        cutscene:wait(.25)

        enemy:shake(Utils.random(1, 9), Utils.random(1, 9))
        Assets.playSound("damage")
        cutscene:wait(.125)

        Game.world:shake(Utils.random(1, 9), Utils.random(1, 9))
        Game.battle:shake(Utils.random(1, 12), Utils.random(1, 9))
        enemy:shake(Utils.random(1, 9), Utils.random(1, 9))
        Game.world:addFX(ShaderFX("wave", {
            ["wave_sine"] = function() return Kristal.getTime() * 150 end,
            ["wave_mag"] = 2,
            ["wave_height"] = 10,
            ["texsize"] = { SCREEN_WIDTH, SCREEN_HEIGHT }
        }), "wave")
        Assets.playSound("damage")
        Assets.playSound("explosion", 1.2, 1.2)
        Assets.playSound("explosion", .8, .8)
        Assets.playSound("explosion", .4, .4)
        Assets.playSound("explosion", .1, .05)
        Game.battle.music:play("d")
        Game.battle.music:setPitch(.55)
        Game.battle.music:setVolume(2.5)
        cutscene:text("* RAMBHACK sacudiu o cabo.\n[wait:5]* A Defesa de RAMBHACK subiu!\n[wait:5]* O Ataque de RAMBHACK subiu!")

        cutscene:battlerText(ramb, "OH, [wait:5]OLHA SÓ!")
        cutscene:battlerText(ramb, "PARECE QUE VOCÊ \nNÃO É MAIS O \nVENCEDOR!")
        cutscene:battlerText(ramb, "E NUNCA MAIS SERÁ.")
        cutscene:battlerText(ramb, "PORQUE, [wait:5]NO\nJOGO DA LIBERDADE,")
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "NINGUÉM GANHA,")
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "NINGUÉM PERDE,")
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        Game.battle.music:pause()
        cutscene:battlerText(ramb, "MAS TODOS [wait:5]VÃO [wait:5]PRO")
        cutscene:battlerText(ramb, "[speed:.75]PARAÍSO", {auto = true})
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")

        kris:shake(2, 2)
        kris:setAnimation("battle/act")
        cutscene:text("* Você pluga o controle no console.[wait:5].[wait:5].[wait:5]")
        Assets.playSound("egg", 1.2, .85)
        cutscene:text("* Conexão feita com sucesso![wait:10]\n* Agora você pode interagir com RAMBHACK!")
        cutscene:wait(1)

        cutscene:battlerText(ramb, "[shake:.2]O QUÊ?")
        cutscene:battlerText(ramb, "[shake:.2]O CONTROLE?")
        cutscene:battlerText(ramb, "[shake:.2]O QUE VOCÊ \nESTÁ TENTANDO", {auto = true})

        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:wait(.2)

        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:wait(.7)

        cutscene:battlerText(ramb, "[shake:.2]ESPERA", {auto = true})

        Game.battle.music:resume("d")
        Game.battle.music:setPitch(Utils.random(1.3, 2.5))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:wait(.1)

        cutscene:battlerText(ramb, "[noskip][shake:1]EI, LARGA ESSE \nCONTROLE", {auto = true})

        Game.battle.music:setPitch(Utils.random(1.4, 2.6))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1]PARE DE BRINCAR \nCOM ISSO", {auto = true})

        Game.battle.music:setPitch(Utils.random(1.5, 2.7))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1]VOCÊ NÃO SABE O \nQUE ESTÁ FAZENDO", {auto = true})

        Game.battle.music:setPitch(Utils.random(1.6, 2.8))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1]ESTOU TENTANDO TE \nDAR LIBERDADE", {auto = true})

        Game.battle.music:setPitch(Utils.random(1.7, 2.9))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1]VOCÊ SÓ VAI PERDER \nTAN", {auto = true})

        Game.battle.music:setPitch(Utils.random(1.8, 3))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1]POR QUE NÃO PARA?! \nPOR QUE NÃO", {auto = true})

        Game.battle.music:setPitch(Utils.random(1.9, 3.1))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1]NÃO VAI NOS DEIXAR", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:1.2]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:1.4]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:1.6]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:1.8]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:2]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:2.2]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:2.4]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:2.6]PARE \nPARE \nPARE", {auto = true})

        Game.battle.music:setPitch(Utils.random(2, 3.2))
        enemy:shake(Utils.random(1, 10), Utils.random(1, 10))
        Assets.playSound("damage")
        cutscene:battlerText(ramb, "[noskip][shake:1][speed:2.8]PARE \nPARE \nPARE", {auto = true})

        Game.world:removeFX("wave")
        cutscene:fadeOut(0)

        Game.battle.music:pause()
        Assets.playSound("damage")
        Assets.playSound("ominoux")
        Assets.playSound("ominoux", .7, .7)
        Assets.playSound("ominoux", .4, .4)
        Assets.playSound("ominoux", .1, .1)
        Game.world:loadMap("consoleroom")
        Game:setBorder("none", 0)
        cutscene:wait(4)

        if Game.party[1] then
            Game.party[1].stats.health = 160
            Game.party[1].health = 160
            Game.party[1].max_stats.health = 160
        end
        cutscene:fadeIn(2)
        Game.battle:returnToWorld()
        Game.world:startCutscene("ramb_ending", "fight")
        -- Game.battle:returnToWorld()
        -- Game.world:loadMap("consoleroom")
    end,
}
