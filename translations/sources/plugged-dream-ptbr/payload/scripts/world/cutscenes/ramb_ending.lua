return {
    mercy = function(cutscene, event, player, facing)
        local kris = cutscene:getCharacter("kris")
        Game.world.music:play("glowing_snow", 1, .9)
        Game:setBorder("tvblack", 2)

        cutscene:fadeOut(0)
        cutscene:fadeIn(2)

        kris:setPosition(805, 413)
        kris:setFacing('right')

        local ramb = cutscene:spawnNPC("ramb", kris.x + 85, kris.y)
        ramb:setSprite("stone_full")
        cutscene:wait(2)

        cutscene:text("* Hah... [wait:5]hah...")
        cutscene:text("* Esses jogos foram pesados, [wait:5]não foram?")
        cutscene:text("* Tão pesados, [wait:5]tão incríveis que eu...")
        cutscene:text("* ... Eu não consegui mais me controlar.")
        cutscene:text("* Não dava pra ler seu sorriso, sua alegria,")
        cutscene:text("* Nem saber se você estava se divertindo lá.")
        cutscene:text("* Mas ei, [wait:5]aprendemos algo a cada dia, [wait:5]não é?")
        cutscene:text("* Talvez você também tenha aprendido..?")
        cutscene:text("* Heh, [wait:5]que nada... [wait:5]\n* Continua o mesmo Kris de sempre, [wait:5]né?")
        cutscene:text("* ...")
        cutscene:text("* Antes de eu, err... [wait:5]petrificar, [wait:5]pode me fazer um favorzinho?")
        cutscene:text("* Me passa esse controlezinho, [wait:5]por favor, [wait:5]querido?")

        Assets.playSound("egg", 1.2, .85)
        kris:setAnimation("battle/act")
        if Game.inventory:hasItem("oddcontroller") then
            Game.inventory:removeItem("oddcontroller")
        end
        cutscene:wait(.35)

        kris:setSprite("walk")
        cutscene:text("* (Você deu seu [color:yellow]CONTROLEESTRANHO[color:reset] ao Ramb.)")
        cutscene:text("* Muito agradecido, amigão.")
        cutscene:text("* Se procura por onde sair, [wait:5]tem um bueiro logo ali.")
        cutscene:text("* Só... [wait:5]me empurra um pouquinho, [wait:5]tá?")
        cutscene:text("* É, [wait:5]assim mesmo.")

        Assets.playSound("bump")
        cutscene:wait(cutscene:slideTo(ramb, ramb.x, ramb.y - 5, 1.5, "in-out-quad", function() ramb:remove() end))
    end,

    fight = function(cutscene, event, player, facing)
        local kris = cutscene:getCharacter("kris")
        Game:setBorder("tvblack", 2)

        cutscene:fadeOut(0)
        cutscene:fadeIn(2)

        kris:setPosition(0, 400)
        kris:setFacing("right")
        cutscene:walkTo(kris, kris.x + 300, kris.y, 2.5, facing)
        cutscene:wait(2.5)

        Assets.stopAndPlaySound("impact")
        Game.world:shake(3, 3)
        cutscene:wait(.45)

        Assets.stopAndPlaySound("impact")
        Game.world:shake(4, 4)
        cutscene:wait(.45)

        Assets.stopAndPlaySound("impact")
        Assets.stopAndPlaySound("impact", .7, .8)
        Assets.stopAndPlaySound("escaped", 1.25)
        Game.world:shake(5, 5)
        cutscene:wait(.55)

        cutscene:text("* Olha só quem tá aí!", "teeth", "susie")

        local susie = cutscene:spawnNPC("susie", 900, kris.y)
        susie:setSprite("walk_unhappy")
        cutscene:walkTo(susie, kris.x + 100, kris.y, 1.25, facing)
        cutscene:walkTo(kris, kris.x - 100, kris.y, 1.25, right, true)
        cutscene:wait(1.25)

        local ralsei = cutscene:spawnNPC("ralsei", susie.x + 300, kris.y)
        cutscene:walkTo(ralsei, susie.x + 50, kris.y, 2.25, facing)
        cutscene:text("* Que diabos te demorou tanto?!", "teeth_b", "susie")

        susie:setSprite("away_turn")
        cutscene:text("* Alguém te prendeu aqui ou o quê?", "shy", "susie")

        susie:setSprite("walk_unhappy")
        susie:setFacing("left")
        cutscene:text("* Porque não tem outra explicação pra você vir parar nisso!", "shy_b", "susie")

        susie:setFacing("right")
        cutscene:text("* Susie, [wait:5]não precisa ficar tão brava!", "dismissive", "ralsei")

        ralsei:setFacing("up")
        cutscene:text("* Kris ainda não sabe o que aconteceu com a gente.", "smile_side", "ralsei")

        ralsei:setFacing("left")
        cutscene:text("* Deixa eu explicar tudo, [wait:5]tá bom?", "neutral", "ralsei")
        cutscene:text("* É, beleza.", "nervous", "susie")

        susie:setFacing("down")
        cutscene:walkTo(susie, susie.x, susie.y - 20, 1, down, true)
        cutscene:text("* Não se preocupe, Kris. [wait:5]\n* Susie não estava brava com você!", "pleased", "ralsei")
        cutscene:text("* Ela só queria te visitar pelo tédio, mas...", "small_smile", "ralsei")
        cutscene:text("* Parecia que a porta estava trancada.", "smile_b", "ralsei")
        cutscene:text("* Mas, [wait:5]após investigar um pouco,", "neutral", "ralsei")
        cutscene:text("* Nós descobrimos outra entrada!", "wink", "ralsei")

        susie:setSprite("away_turn")
        cutscene:text("* Se achar um bueiro nas paredes conta como \"entrada\".", "closed_grin", "susie")

        susie:setSprite("diagonal_kick_right_1")
        susie:setFacing("right")
        ralsei:setFacing("down")
        cutscene:text("* Nós... [wait:5]não tínhamos muita escolha.", "pensive", "ralsei")

        ralsei:setFacing("right")
        cutscene:text("* A porta parecia ser um tipo esquisito de parede.", "small_smile_side", "ralsei")

        ralsei:setFacing("left")
        susie:setSprite("walk_back_arm")
        cutscene:walkTo(susie, susie.x, susie.y + 20, .35, right, true)
        cutscene:text("* É, [wait:5]tanto faz.", "smirk", "susie")

        susie:setFacing("left")
        cutscene:text("* Ao menos podemos dar o fora daqui e...", "smile", "susie")

        kris:shake(3,2)
        susie:setSprite("walk_unhappy")
        Assets.playSound("bump")
        cutscene:wait(1.25)

        cutscene:text("* Err... [wait:5]Ralsei?", "nervous_side", "susie")

        susie:setFacing("right")
        ralsei:setSprite("walk_unhappy")
        cutscene:text("* É normal humanos... [wait:5]tremerem assim?", "nervous", "susie")
        cutscene:text("* ...", "frown", "ralsei")

        kris:shake(3,2)
        Assets.playSound("bump")
        susie:setFacing("left")
        cutscene:text("* Ah, err...", "shock_nervous", "susie")
        local longwalk = cutscene:walkTo(susie, kris.x + 50, kris.y + 1, 2, facing)
        cutscene:text("* Tudo bem, [wait:5]Kris, [wait:5]já achamos uma saída daqui!", "smile", "susie")

        kris:shake(3,2)
        Assets.playSound("bump")
        cutscene:text("* Não sei o que houve nesse lugar sinistro, [wait:5]mas...", "smirk", "susie")

        kris:shake(3,2)
        Assets.playSound("bump")
        cutscene:text("[noskip]* Se você REALMENTE precisar, [wait:5]eu posso te ajudar a", "closed_grin", "susie", {auto=true})
        cutscene:wait(longwalk)

        Assets.playSound("sussurprise")
        Assets.playSound("egg", 1.2, .85)
        kris:setAnimation("battle/act")
        susie:shake(3,2)
        susie:setSprite("shock_left")
        cutscene:slideTo(susie, kris.x + 75, kris.y + 1, .25, "out-quad")
        if Game.inventory:hasItem("oddcontroller") then
            Game.inventory:removeItem("oddcontroller")
        end
        cutscene:wait(.35)

        cutscene:text("* Ei, [wait:5]que diabos você-...", "surprise_frown", "susie")

        kris:setSprite("walk")
        susie:setSprite("walk_unhappy")
        cutscene:text("* Ah, [wait:5]só queria me entregar um controle.", "surprise", "susie")

        susie:setSprite("away_hand")
        ralsei:setSprite("walk")
        cutscene:text("* Ué, [wait:5]quem você acha que eu sou, [wait:5]o Berdly?", "closed_grin", "susie")

        susie:setSprite("away_turn")
        cutscene:text("* Eu não coleciono controle nem nada do tipo.", "smirk", "susie")

        susie:setSprite("walk")
        cutscene:text("* Vou só tacar na parede ali, beleza?", "smile", "susie")

        susie:setSprite("walk_back_arm")
        cutscene:text("* Nem deve ser importante já que você deu tão fácil!", "sincere_smile", "susie")

        cutscene:wait(cutscene:walkTo(susie, ralsei.x - 50, kris.y, .75, facing))
        cutscene:text("* Beleza, vamos logo.", "small_smile", "susie")

        susie:setSprite("walk_unhappy")
        cutscene:text("* A Toriel não vai esperar por nós mesmo.", "sus_nervous", "susie")

        susie:setSprite("walk")
        cutscene:text("* A gente te espera lá fora, Kris.", "smile_side", "ralsei")
        cutscene:text("* Agora, vamos!", "neutral", "ralsei")

        local susmove = cutscene:walkTo(susie, susie.x + 260, kris.y, 1.25, facing)
        cutscene:wait(cutscene:walkTo(ralsei, ralsei.x + 260, kris.y, 1.25, facing))
        cutscene:wait(susmove)

        kris:setFacing("down")
        susie:remove()
        ralsei:remove()
        Assets.stopAndPlaySound("escaped", 1.15)
    end,

    nowayback = function(cutscene, event, player, facing)
        local kris = cutscene:getCharacter("kris")
        kris:setPosition(kris.x + 3, kris.y)

        cutscene:text("* (Você não quer mais voltar.)")
    end,

    manhole = function(cutscene, event, player, facing)
        cutscene:text("* (É um bueiro.) [wait:5]\n* (Parece ter sido aberto à força.)")
        cutscene:text("* (Entrar?)")
        if cutscene:choicer({"Sim", "Não"}) == 1 then
            cutscene:fadeOut(1.5, {music = true})
            Kristal.hideBorder(1.5)
            Assets.stopAndPlaySound("escaped", 1.25)

            cutscene:wait(3.25)
            cutscene:endCutscene()
            Game.world:startCutscene("credits")
        end
    end,
}
