local SoulFlash, super = Class(Sprite)

function SoulFlash:init(parent, count, alpha)
    super.init(self, "player/heart_dodge", 0, 0)

    self.color = parent.color

    self:setParallax(0)
    self.scale_origin_x = 0.5
    self.scale_origin_y = 0.5

    self.count = count
    self.countAlpha = alpha

    parent:addChild(self)
end

function SoulFlash:update()
    self:setScale(self.scale_x + self.count)
    self.alpha = self.alpha - self.countAlpha

    if self.alpha < 0 then
        self:remove()
    end
end

return {
    intro = function(cutscene, event)
        cutscene:fadeOut(0)
        local kris = cutscene:getCharacter("kris")
        kris:setFacing("up")
        local text

        -- DIFFICULTY MENU SEQUENCE

        local function gonerTextFade(wait)
            local this_text = text
            Assets.playSound("ui_spooky_action")
            Game.world.timer:tween(1, this_text, { alpha = 0 }, "linear", function ()
                this_text:remove()
            end)
            if wait ~= false then
                cutscene:wait(1)
            end
        end

        local function gonerText(str, advance)
            text = DialogueText("[speed:0.5][spacing:2][style:GONER][voice:none]" .. str, 160, 100, 640, 480,
                                { auto_size = true })
            text.layer = WORLD_LAYERS["top"] + 100
            text.skip_speed = true
            text.parallax_x = 0
            text.parallax_y = 0
            Game.world:addChild(text)

            if advance ~= false then
                cutscene:wait(function () return not text:isTyping() end)
                gonerTextFade(true)
            end
        end

        cutscene:wait(1)
        Game.world.music:play("AUDIO_DRONE", 1)

        gonerText("ESCOLHA A DIFICULDADE", false)
        local chosen = nil

        local bottomtext = Text("", -9, 320)
        -- bottomtext:setScale(0.5)
        bottomtext.alpha = 0
        bottomtext.parallax_x = 0
        bottomtext.parallax_y = 0
        bottomtext.align = "center"
        bottomtext.font_size = 16
        Game.stage:addChild(bottomtext)

        Game.world.timer:tween(0.25, bottomtext, {alpha = 0.5}, "out-sine")

        local descriptions = {
            CASUAL = "Modo Fácil.\nReduz atributos do inimigo e acelera a ALMA.",
            MIXED  = "Modo Equilibrado.\nMantém o ataque e a defesa originais.",
            LEGACY = "Modo Clássico.\nMantém movimento da ALMA em grade e atributos."
        }

        local choicer = GonerChoice(220, 270, {
            { { "CASUAL", -140, 0 }, { "MIXED", 55, 0 }, { "LEGACY", 240, 0 } }
        }, function (choice)
            chosen = choice
        end)

        function choicer:onHover(choice, x, y)
            local name = choice[1]
            bottomtext:setText(descriptions[name] or "")
        end

        choicer:setSelectedOption(2, 1)
        choicer:setSoulPosition(71, 0)
        Game.stage:addChild(choicer)

        choicer:onHover(choicer:getChoice(choicer.selected_x, choicer.selected_y))

        cutscene:wait(function () return chosen ~= nil end)
        Game.world.timer:tween(1, bottomtext, { alpha = 0 }, "linear")
        gonerTextFade()

        if chosen == "CASUAL" then
            Mod.flags.DIFFICULTY = "CASUAL"
        elseif chosen == "MIXED" then
            Mod.flags.DIFFICULTY = "MIXED"
        elseif chosen == "LEGACY" then
            Mod.flags.DIFFICULTY = "LEGACY"
        end

        Game.world.timer:tween(1, Game.world.music, {volume = 0}, nil, function() Game.world.music:stop() end)
        cutscene:wait(1.5)

        -- DIFFICULTY MENU SEQUENCE END

        if Kristal.Config and Kristal.Config["skip_intro"] == true then
            cutscene:endCutscene()
            cutscene:loadMap("board_static")
        end

        cutscene:wait(2)
        cutscene:setTextboxTop(false)
        Assets.playSound("locker")
        cutscene:text("* (Você abriu o baú de\ntesouro.)[wait:5]\n* (Dentro estava o [color:yellow]MantoSombrio[color:reset].)")
        cutscene:text("* ([color:yellow]MantoSombrio[color:reset] foi adicionado às suas [color:yellow]ARMADURAS[color:reset].)")
        Assets.playSound("equip")
        cutscene:text("* (Você equipa o [color:yellow]MantoSombrio[color:reset].)")
        cutscene:wait(1.5)
        cutscene:setTextboxTop(true)
        Assets.playSound("tvturnoff", 1.2)
        cutscene:wait(1.5)
        cutscene:text("* (Bem, [wait:5]a TV agora está desligada.)")
        cutscene:wait(1)
        cutscene:fadeIn(0)
        Assets.playSound("impact")
        cutscene:wait(2)
        kris:setFacing("right")
        cutscene:text("* Você conseguiu, [wait:5]Kris! [wait:5]Conseguiu!")
        local ramb = cutscene:spawnNPC("ramb", SCREEN_WIDTH + 30, kris.y)
        ramb:setColor(0.5, 0.5, 0.5)
        ramb:setSprite("stone_half")
        Assets.playSound("bump")
        cutscene:wait(cutscene:slideTo(ramb, ramb.x - 50, ramb.y, 1.5, "in-out-quad"))
        cutscene:wait(1)
        Assets.playSound("bump")
        cutscene:wait(cutscene:slideTo(ramb, ramb.x - 50, ramb.y, 1.5, "in-out-quad"))
        cutscene:wait(1)
        cutscene:text("* O manto.[wait:2].[wait:2].[wait:2] em suas mãos.")
        ramb:setSprite("stone_half_look")
        cutscene:text("* Trabalho brilhante, [wait:3]querido.")
        Assets.playSound("bump")
        cutscene:wait(cutscene:slideTo(ramb, ramb.x - 50, ramb.y, 1.5, "in-out-quad"))
        cutscene:wait(1)
        cutscene:walkTo(kris, kris.x - 90, kris.y, 4, right, true)
        Assets.playSound("bump")
        cutscene:wait(cutscene:slideTo(ramb, ramb.x - 50, ramb.y, 1.5, "in-out-quad"))
        cutscene:wait(1)
        Assets.playSound("bump")
        cutscene:wait(cutscene:slideTo(ramb, ramb.x - 50, ramb.y, 1.5, "in-out-quad"))
        cutscene:wait(1.5)
        cutscene:text("* Agora, [wait:5]sobre.[wait:2].[wait:2].[wait:2] os jogos.")
        ramb:setSprite("stone_half")
        cutscene:text("* Foram divertidos?")
        cutscene:text("* Foram, [wait:5]não foram?")
        local choice = cutscene:choicer({"Muito legais", "Ruins"})
        if choice == 1 then
            ramb:setSprite("stone_half_look")
            cutscene:text("* Entendi, [wait:5]entendi...")
            cutscene:text("* Bom, [wait:5]desde que tenha se divertido...")
            cutscene:text("* ... não preciso me preocupar com eles.")
            cutscene:text("* Afinal, [wait:5]meu propósito é garantir que você jogue o que quiser.")
            ramb:setSprite("stone_half")
            cutscene:text("* Não é, [wait:5]querido?")
            ramb:setSprite("stone_half_look")
        elseif choice == 2 then
            ramb:setSprite("stone_half_look")
            cutscene:text("* Qual é, [wait:5]não mente pra mim...")
            cutscene:text("* Consigo ver o brilho no seu olhar...")
            cutscene:text("* Além do mais...")
            ramb:setSprite("stone_half")
            cutscene:text("* Por que mais voltaria pra jogar mais.[wait:2].[wait:2]?")
            cutscene:text("* Por diversão, né?")
            ramb:setSprite("stone_half_look")
        end
        cutscene:text("* ...")
        cutscene:text("* Mas agora, [wait:5]que os jogos acabaram.[wait:2].[wait:2].")
        ramb:setSprite("stone_half")
        cutscene:text("* ... o que você vai fazer?")
        cutscene:text("* Jogar os joguinhos do Tenna de novo?")
        ramb:setSprite("stone_half_look")
        Assets.playSound("bump")
        local ramb_move = cutscene:slideTo(ramb, ramb.x - 25, ramb.y, .7, "in-out-quad")
        cutscene:text("* Não, [wait:5]eu te conheço, [wait:5]Kris.[wait:2].[wait:2].")
        cutscene:text("* Fez esse trampo todo pra se divertir aqui...")
        ramb:setSprite("stone_half")
        cutscene:text("* Diversão.[wait:2].[wait:2].[wait:5] DE VERDADE...[wait:10] \n* Não essas missões do Tenna.")
        cutscene:text("* Igualzinho aos velhos tempos.[wait:2].[wait:2].")
        ramb:setSprite("stone_half_look")
        cutscene:text("* O cara da TV não entende o VERDADEIRO sentido, [wait:5]não é?")
        ramb:setPosition(395, 375)
        ramb:setSprite("stone_half")
        Assets.playSound("bump")
        local ramb_move2 = cutscene:slideTo(ramb, ramb.x + 25, ramb.y, .7, "in-out-quad")
        cutscene:text("* Bem, [wait:5]eu tenho a solução pra você.")
        ramb:setSprite("stone_half_look")
        cutscene:text("* Jogos, [wait:8]\n* Diversão, [wait:8]\n* Liberdade, ")
        cutscene:text("* Tudo isso!")
        ramb:setSprite("stone_half")
        cutscene:text("* Vem cá, [wait:5]amigão. [wait:5]\n* Tenho algo pra te contar.")
        ramb:setPosition(420, 375)
    end,

    encounter = function(cutscene, event)
        local kris = cutscene:getCharacter("kris")
        local ramb = cutscene:getCharacter("ramb")
        cutscene:text("* Deixa eu te explicar uma coisa.")
        ramb:setSprite("stone_half_look")
        cutscene:text("* Quando jogou aquele jogo que te chamei pra testar,")
        cutscene:text("* Eu vi que você se divertiu.")
        cutscene:text("* Não muito, às vezes quase nada...")
        ramb:setSprite("stone_half")
        cutscene:text("* ...mas se divertiu.")
        ramb:setSprite("stone_half_look")
        cutscene:text("* Com isso, [wait:5]eu entendi do que você precisa.")
        ramb:setSprite("stone_half")
        cutscene:text("* Mais, [wait:5]mais jogos!")
        ramb:setSprite("stone_half_look")
        cutscene:text("* Foi aí que encontrei a resposta:")
        ramb:setSprite("stone_half")
        cutscene:text("* Outras versões.")
        cutscene:text("* TINHA que ter mais de uma versão!")
        ramb:setSprite("stone_half_look")
        cutscene:text("* E tinha mesmo.")
        ramb:setSprite("stone_half")
        cutscene:text("* Dezenas, [wait:5]\n* Centenas, [wait:5]\n* Milhares de protótipos!")
        ramb:setSprite("stone_half_look")
        cutscene:text("* Só que... [wait:5]a maioria em péssimo estado.")
        cutscene:text("* Não iam rodar no console todos detonados, [wait:5]iam?")
        ramb:setSprite("stone_half")
        cutscene:text("* Então achei a solução.")
        cutscene:text("* Aqui, [wait:5]fique com isso.")
        Assets.playSound("item")
        cutscene:text("* ([color:yellow]PLUGUEESTRANHO[color:reset] foi para seus [color:yellow]ITENS-CHAVE[color:reset].)")
        ramb:setSprite("stone_half_look")
        cutscene:text("* Esse plugue.")
        cutscene:text("* Esse plugue é a conexão para nossa liberdade.")
        cutscene:text("* Você pluga ele, [wait:5]e eu faço cada versão rodar!")
        cutscene:text("* Uma última aventura.")
        ramb:setSprite("stone_half")
        cutscene:text("* Só para nós dois.")
        ramb:setSprite("stone_half_look")
        cutscene:text("* Mas,[wait:5] veja bem...")
        ramb:setSprite("stone_half")
        cutscene:text("* Mal consigo me mover agora.")
        cutscene:text("* Não consigo.[wait:2].[wait:2].[wait:5] fazer nada com esse treco.")
        ramb:setSprite("stone_half_look")
        cutscene:text("* Mas você?")
        ramb:setSprite("stone_half")
        cutscene:text("* Você pode tudo se realmente quiser!")
        ramb:setSprite("stone_half_look")
        cutscene:text("* Então.[wait:2].[wait:2].[wait:10] \n* Se quiser mesmo se divertir mais...")
        cutscene:text("* Plugue isso na minha cara.")
        ramb:setSprite("stone_half")
        cutscene:text("* O que acha?")
        local choice2 = cutscene:choicer({"Claro", "Nunca"})
        if choice2 == 1 then
            cutscene:text("* Valeu, [wait:5]Kris-")
            ramb:setSprite("stone_half_look")
            cutscene:text("* Espera um pouco.[wait:2].[wait:2].")
            cutscene:text("* Que cara é essa, [wait:5]querido? [wait:10]\n* Não tem por que ficar triste!")
            cutscene:text("* Liberdade, [wait:5]é disso que se trata, [wait:5]liberdade!")
            ramb:setSprite("stone_half")
            cutscene:text("* Agora, [wait:5]nada de tristeza e faça sua escolha!")
        elseif choice2 == 2 then
            cutscene:text("* Sabe de uma coisa, [wait:5]Kris?")
            ramb:setSprite("stone_half_look")
            cutscene:text("* Eu te entendo.")
            cutscene:text("* Não quero complicar as coisas pra você, [wait:5]de verdade.[wait:2].[wait:2].")
            ramb:setSprite("stone_half")
            cutscene:text("* Mas Kris, [wait:5]ei, [wait:5]Kris!")
            cutscene:text("* A diversão.[wait:2].[wait:2].[wait:10] \n* A diversão tá mais perto do que nunca!")
            cutscene:text("* ...")
            ramb:setSprite("stone_half_look")
            cutscene:text("* Desculpa, [wait:5]Kris, [wait:5]nem sei o que tô falando.")
            cutscene:text("* Só faça o que quiser fazer.")
            ramb:setSprite("stone_half")
            cutscene:text("* A escolha é sua, [wait:5]querido.")
        end
        cutscene:wait(1)
        cutscene:wait(cutscene:walkTo(kris, kris.x - 50, kris.y, 1.5, right, true))
        -- cutscene:wait(.15)
        cutscene:wait(cutscene:walkTo(kris, ramb.x - 5, kris.y, .3, right, true))
        local rect = Rectangle(0, 0, SCREEN_WIDTH + 500, SCREEN_HEIGHT + 500)
        rect.color = {0, 0, 0}
        rect.layer = ramb.layer + 101
        Game.world:addChild(rect)
        ramb.layer = ramb.layer + 102
        ramb:setColor(1, 1, 1)
        ramb:setSprite("ramb_transform_prepare")
        ramb:setPosition(ramb.x - 72, ramb.y - 56)
        Assets.playSound("impact", 1.2, 1.2)
        Assets.playSound("impact", .7, .7)
        Assets.playSound("impact", .2, .2)
        cutscene:wait(cutscene:slideTo(ramb, ramb.x + 90, ramb.y, 2, "out-quint"))
        cutscene:wait(1)
        cutscene:text("* Kris! [wait:5]Você conseguiu![wait:5]\n* Conseguiu mesmo!")
        cutscene:text("* Só me diz uma coisa...")
        cutscene:wait(1)
        ramb:setAnimation("ramb_transform_one")
        cutscene:wait(0.01)
        Assets.playSound("explosion", 1, 2)
        Assets.playSound("impact", 1.2, 1.2)
        Assets.playSound("impact", .7, .7)
        for dx = -10, 15, 10 do
            for dy = 0, 35, 10 do
                local effect = Sprite("effects/shard", ramb.x + 83, ramb.y + 45)
                effect:setParallax(0)
                effect:setOrigin(.5, .5)
                effect:setScale(math.random(2))
                effect.alpha = math.random() + .5
                effect.physics.gravity = math.random(1)
                effect.physics.speed_y = -math.random(3, 6)
                effect.physics.speed_x = math.random(1, 9)
                effect:play(2 / 30, true)
                effect.layer = ramb.layer + 1
                effect:shake(9, 9, 0.5)

                local t = Timer()
                local timer = math.random(4) / 2

                t:after(timer, function()
                    t:tween(1, effect, {alpha = 0}, nil, function()
                        effect:remove()
                    end)
                end)

                effect:addChild(t)

                Game.world:addChild(effect)
            end
        end
        cutscene:wait(.5)
        cutscene:text("* Quando você...")
        cutscene:text("* Quando parar de jogar...")
        cutscene:wait(1)
        ramb:setAnimation("ramb_transform_two")
        cutscene:wait(0.01)
        Assets.playSound("explosion", 1, 2)
        Assets.playSound("impact", 1.2, 1.2)
        Assets.playSound("impact", .7, .7)
        for dx = -10, 15, 10 do
            for dy = 0, 35, 10 do
                local effect = Sprite("effects/shard", ramb.x + 65, ramb.y + 40)
                effect:setParallax(0)
                effect:setOrigin(.5, .5)
                effect:setScale(math.random(2))
                effect.alpha = math.random() + .5
                effect.physics.gravity = math.random(1)
                effect.physics.speed_y = -math.random(3, 6)
                effect.physics.speed_x = math.random(-9, -1)
                effect:play(2 / 30, true)
                effect.layer = ramb.layer + 1
                effect:shake(9, 9, 0.5)

                local t = Timer()
                local timer = math.random(4) / 2

                t:after(timer, function()
                    t:tween(1, effect, {alpha = 0}, nil, function()
                        effect:remove()
                    end)
                end)

                effect:addChild(t)

                Game.world:addChild(effect)
            end
        end
        cutscene:wait(.5)
        cutscene:text("* Só me diz...[wait:5] heh...")
        cutscene:text("* Só me diz se você se...")
        cutscene:wait(1)
        Assets.playSound("charge", 1.2)
        local t = Timer()
        local to_remove = {}

        t:every(0.05, function()
            local radius = math.random(64, 96)
            local angle = math.rad(math.random(0, 360))

            local x = math.cos(angle) * radius + 45
            local y = math.sin(angle) * radius + 28
            local scale = math.random() + 0.5

            local effect = Sprite("effects/sparkle", x, y)
            effect:setScale(0)
            effect:setOrigin(.5)
            effect:setParallax(0)
            effect.alpha = 0
            effect.layer = ramb.layer + 1

            t:tween(0.8, effect, {x = 4 + 45, y = 4 + 28, alpha = 0.5, scale_x = scale, scale_y = scale}, 'in-out-circ', function()
                for k,v in ipairs(to_remove) do
                    if v == effect then
                        table.remove(to_remove, k)
                        break
                    end
                end

                effect:remove()
            end)

            ramb:addChild(effect)
            table.insert(to_remove, effect)
        end)

        local effect = Sprite("effects/sparkle", 4 + 45, 4 + 28)
        effect:setScale(0)
        effect:setOrigin(.5)
        effect:setParallax(0)
        effect.alpha = 0
        effect.layer = ramb.layer + 1

        local effect2 = Sprite("effects/sparkle", 6 + 45, 6 + 28)
        effect2:setScale(0)
        effect2:setOrigin(.5)
        effect2:setParallax(0)
        effect2.alpha = 0

        effect:addChild(effect2)

        t:tween(3, effect, {scale_x = 3, scale_y = 3, alpha = 0.5}, 'in-out-circ')
        t:tween(3, effect2, {scale_x = 2, scale_y = 2, alpha = 0.5}, 'in-out-cubic')

        ramb:addChild(effect)

        ramb:addChild(t)

        cutscene:wait(3)

        cutscene:fadeOut(0)

        cutscene:wait(1)

        cutscene:text("* .[wait:2].[wait:2].[wait:5]divertiu...")

        cutscene:wait(2.5)
        cutscene:endCutscene()
        Game.world:startCutscene("ramb_intro", "encounter2")
    end,

    encounter2 = function(cutscene, event)
        cutscene:loadMap("board_static")
        local kris = cutscene:getCharacter("kris")
        kris:setPosition(155, kris.y)
        kris:setColor(1, 1, 1)
        cutscene:setSprite(kris, "sit")
        Assets.playSound("wing")
        cutscene:fadeIn(0)
        cutscene:wait(2)

        Assets.playSound("wing")
        kris:shake(4)

        kris:resetSprite()
        kris:setFacing('right')

        cutscene:wait(1.5)

        kris:setFacing('down')

        cutscene:wait(.35)

        kris:setFacing('up')

        cutscene:wait(.35)

        kris:setFacing('left')

        cutscene:wait(1)

        kris:setFacing('up')

        cutscene:wait(2.5)

        kris:setFacing('right')
        Assets.playSound("friend")
        Assets.playSound("run")

        cutscene:wait(2)

        local ramb = cutscene:spawnNPC("ramb", SCREEN_WIDTH + 2300, kris.y)
        ramb:setColor(0, 0, 0)
        cutscene:wait(cutscene:slideTo(ramb, kris.x + 10, kris.y, 1))

        Game.world.music:stop()
        kris.layer = kris.layer + 1
        ramb.layer = ramb.layer + 1
        local rect = Rectangle(0, 0, SCREEN_WIDTH + 500, SCREEN_HEIGHT + 500)
        rect.color = {0, 0, 0}
        rect.layer = kris.layer - 1
        Game.world:addChild(rect)
        Assets.playSound("noise")
        kris:setAnimation("battle/attack_ready")
        kris:setColor(.5,.5,.5)

        local soul = Sprite("player/heart_dodge", kris.x, 255)
        soul:setParallax(0)
        soul.color = {1, 0, 0}

        local soulFlash = FlashFade("player/heart_dodge", 0, 0)
        soul:addChild(soulFlash)

        Game.world:spawnObject(soul, 1001)

        cutscene:wait(0.5)

        Assets.playSound("greatshine", 1, 0.8)
        Assets.playSound("greatshine", 1, 1)
        Assets.playSound("closetimpact", 1, 1.5)

        soul.color = {.85, 0, 1}

        local soulFlash = FlashFade("player/heart_dodge", 0, 0)
        soul:addChild(soulFlash)

        SoulFlash(soul, 0.1, 0.075)
        SoulFlash(soul, 0.25, 0.05)

        local shake = 6

        kris:shake(shake)

        cutscene:wait(1)

        local gridsoul = GridSoul(10, 10)
        gridsoul:setScale(0)
        gridsoul.sprite:remove()
        gridsoul:setSwordRotation("right")
        gridsoul.can_defend = false
        gridsoul.can_move = false

        local t = Timer()

        t:tween(0.01, gridsoul, {scale_x = 1, scale_y = 1}, 'out-sine', function()
            gridsoul.can_defend = true
        end)

        cutscene:wait(.2)

        soul:addChild(t)
        soul:addChild(gridsoul)

        local text

        t:after(1, function()
            text = Text("Aperte [bind:confirm]", -17, -20)
            text.alpha = 0
            text:setScale(0.5)

            soul:addChild(text)
            t:tween(0.25, text, {alpha = 0.5}, 'out-sine')
        end)

        cutscene:wait(function()
            if Input.down('confirm') then
                t:remove()
                if text then text:remove() end
                gridsoul:setSwordRotation("right")
                if Input.down('left') then
                    gridsoul:setSwordRotation("right")
                end
                if Input.down('up') then
                    gridsoul:setSwordRotation("right")
                end
                if Input.down('down') then
                    gridsoul:setSwordRotation("right")
                end
                gridsoul.can_defend = false
                gridsoul.sword.visible = true
                gridsoul.sword.isAttacking = true
                gridsoul.rotationSpeed = 0
                Assets.playSound('sword/wing1')
                Assets.playSound('sword/kill')

                local hideTimer = Timer()
                hideTimer:after(.15, function()
                    gridsoul.visible = false
                    gridsoul.sword.visible = false
                    gridsoul:remove()
                    soul:remove()
                    rect:remove()
                    kris:setAnimation("battle/attack")
                    cutscene:slideTo(kris, kris.x - 25, kris.y, .5, "out-quad")
                    ramb:remove()
                    kris:setColor(0.25, 0.25, 0.25)
                    Assets.playSound("criticalswing")
                    Assets.playSound("criticalswing", 1.2, 1.2)
                    Assets.playSound("criticalswing", .7, .7)
                    Assets.playSound("damage")
                    Assets.playSound("damage", .7, .7)
                end)
                soul:addChild(hideTimer)
                return true
            end
        end)

        cutscene:wait(2)

        kris:setSprite("battle/idle")
        local romb = cutscene:spawnNPC("romb", 500, 10)
        romb:setColor(0, 0, 0)
        cutscene:wait(1)
        romb:shake(4)
        Assets.playSound("bump", .5, 0.8)
        Assets.playSound("damage", .5, 1)
        cutscene:wait(cutscene:slideTo(romb, romb.x, romb.y + 90, 2, "out-back"))
        cutscene:wait(1)
        romb:shake(4)
        Assets.playSound("bump", .7, 0.8)
        Assets.playSound("damage", .7, 1)
        cutscene:wait(cutscene:slideTo(romb, romb.x, romb.y + 90, 2, "out-back"))
        cutscene:wait(1)
        romb:shake(4)
        Assets.playSound("bump", 1, 0.8)
        Assets.playSound("damage", 1, 1)
        cutscene:wait(cutscene:slideTo(romb, romb.x, romb.y + 90, 2, "out-back"))
        cutscene:wait(1)
        Assets.playSound("friend", 1, 1)
        Assets.playSound("friend", .8, .8)
        Assets.playSound("friend", .6, .6)
        cutscene:wait(.25)
        romb:shake(4)
        romb:setColor(0.08, 0.08, 0.08)
        Assets.playSound("bump", 1, 0.8)
        Assets.playSound("damage", 1, 1)
        cutscene:wait(.5)
        romb:shake(4)
        romb:setColor(0.17, 0.17, 0.17)
        Assets.playSound("bump", 1, 0.8)
        Assets.playSound("damage", 1, 1)
        cutscene:wait(.5)
        romb:shake(4)
        romb:setColor(0.25, 0.25, 0.25)
        Assets.playSound("bump", 1, 0.8)
        Assets.playSound("damage", 1, 1)
        cutscene:wait(.5)
        Game:saveQuick()
        cutscene:endCutscene()
        cutscene:startEncounter("romb", nil, romb)
    end,

    encounter2_short = function(cutscene, event)
        Game:saveQuick()
        cutscene:fadeOut(0)
        local kris = cutscene:getCharacter("kris")
        kris:setPosition(130, kris.y)
        Assets.playSound("wing")
        cutscene:fadeIn(.25)
        kris:setSprite("battle/idle")
        local romb = cutscene:spawnNPC("romb", 500, 10)
        romb:setColor(0, 0, 0)
        cutscene:wait(.5)
        romb:shake(4)
        Assets.playSound("bump", .5, 0.8)
        Assets.playSound("damage", .5, 1)
        cutscene:wait(cutscene:slideTo(romb, romb.x, romb.y + 90, 1.3, "out-back"))
        cutscene:wait(.5)
        romb:shake(4)
        Assets.playSound("bump", .7, 0.8)
        Assets.playSound("damage", .7, 1)
        cutscene:wait(cutscene:slideTo(romb, romb.x, romb.y + 90, 1.3, "out-back"))
        cutscene:wait(.5)
        romb:shake(4)
        Assets.playSound("bump", 1, 0.8)
        Assets.playSound("damage", 1, 1)
        cutscene:wait(cutscene:slideTo(romb, romb.x, romb.y + 90, 1.3, "out-back"))
        cutscene:wait(.7)
        Assets.playSound("friend", 1, 1)
        Assets.playSound("friend", .8, .8)
        Assets.playSound("friend", .6, .6)
        cutscene:wait(.25)
        romb:shake(4)
        romb:setColor(0.08, 0.08, 0.08)
        Assets.playSound("bump", 1, 0.8)
        Assets.playSound("damage", 1, 1)
        cutscene:wait(.35)
        romb:shake(4)
        romb:setColor(0.17, 0.17, 0.17)
        Assets.playSound("bump", 1, 0.8)
        Assets.playSound("damage", 1, 1)
        cutscene:wait(.35)
        romb:shake(4)
        romb:setColor(0.25, 0.25, 0.25)
        Assets.playSound("bump", 1, 0.8)
        Assets.playSound("damage", 1, 1)
        cutscene:wait(.35)
        cutscene:endCutscene()
        cutscene:startEncounter("romb", nil, romb)
    end
}
