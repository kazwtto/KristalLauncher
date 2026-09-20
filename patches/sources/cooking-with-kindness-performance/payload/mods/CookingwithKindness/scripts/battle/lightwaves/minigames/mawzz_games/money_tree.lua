--Code by Sharks!

local MoneyTree, super = Class("LightMinigameWave")

function MoneyTree:init()
    super.init(self, _s("minigame_popup-money_tree", "   TAX   \n   EVASION!   "), "horiz_layout_alt")
    
    -- I hate that I had to make an object for this
    Game.battle:addChild(MawzzSounder("mawzz_taxevasion"))
    self.time = -1

    self.timer = 0

    Game:setFlag("Results", "none")
    Game:setFlag("AddedMawzzGold", 0)

    self:setArenaSize(200, 230)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 - 10)

    self.money_caught = 0

    self.movement_speed = 5
    self.countdown = 16
end

function MoneyTree:onStart()

    self.soul = self:spawnObject(Soul(),320, 337)
    self.soul:setColor(0,1,0)
    self.soul.sprite:setSprite("player/heart")
    self.soul:setLayer(BATTLE_LAYERS["bullets"])
    self.soul.noclip = false
    self.soul.can_move = false

    self.tree_bg = self:addChild(Sprite("objects/mawzz_games/moneytree/tree",0,0))
    self.tree_bg:setScale(2)
    self.tree_bg:setParent(Game.battle.arena.mask)
    self.tree_bg:setLayer(1)

    self.tree_spawner = MoneyTreeSpawner(0,0)
    self:addChild(self.tree_spawner)
    self.tree_spawner:setParent(Game.battle.arena.mask)
    self.tree_spawner:setLayer(2)

    self.tree_leaves = self:addChild(Sprite("objects/mawzz_games/moneytree/tree_leaves",0,0))
    self.tree_leaves:setScale(2)
    self.tree_leaves:setParent(Game.battle.arena.mask)
    self.tree_leaves:setLayer(3)

    self.countdown_text = self:spawnObject(Text(""), 0, Game.battle.arena:getTop() + 4)
    self.countdown_text.align = "center"
    self.countdown_text:setText("[font:Sunny, 48][style:menu][color:green]"..self.countdown)
    self.countdown_text:setLayer(BATTLE_LAYERS["top"])

    Game.battle.timer:everyInstant(1, function()

        if self.finished then return false end


        self.countdown = self.countdown - 1

        if self.countdown > 10 then
            self.countdown_text:setText("[font:Sunny, 48][style:menu][color:green]"..self.countdown)
            Assets.playSound("graze",1,1)
            
        elseif self.countdown > 5 then
            self.countdown_text:setText("[font:Sunny, 48][style:menu][color:#ff8800]"..self.countdown)
            Assets.playSound("graze",1,0.85)
        elseif self.countdown <= 5 then
            self.countdown_text:setText("[font:Sunny, 48][style:menu][color:red]"..self.countdown)
            self.countdown_text:shake()
            Assets.playSound("break1",1,1)
        end

        if self.countdown == 0 then
            self.finished = true
            self.tree_bg:remove()
            self.tree_leaves:remove()
        end
    end)
end

function MoneyTree:update()

    self:handleMovement()

    Object.startCache()
    local item_index = 1
    while item_index <= #self.tree_spawner.current_items do
        local v = self.tree_spawner.current_items[item_index]
        if not v.parent then
            table.remove(self.tree_spawner.current_items, item_index)
        elseif v:collidesWith(self.soul) then
            if v.type == "COIN" then
                Assets.playSound("snd_ding", 1, 1.2)
                self.money_caught = self.money_caught + 5
                self:genCoinText("[font:main, 32][style:menu][color:yellow]+ 5G")
                self.tree_spawner.item_drop_speed = self.tree_spawner.item_drop_speed + 0.2
                Game:addFlag("MawzzGoldEarned", 5)
            elseif v.type == "TAXES" then
                self.money_caught = self.money_caught - 5
                Assets.playSound("snd_reverse_cash")
                local tax_reduction = math.max(0, Game:getFlag("MawzzGoldEarned") - 5)
                Game:setFlag("MawzzGoldEarned", tax_reduction)
                self:genCoinText("[font:main, 32][style:menu][color:red]- 5G")
            elseif v.type == "BILL" then
                self.money_caught = self.money_caught + 20
                self.tree_spawner.item_drop_speed = self.tree_spawner.item_drop_speed + 0.2
                Assets.playSound("snd_cash")
                self:genCoinText("[font:main, 32][style:menu][color:green]+ 20G")
                Game:addFlag("MawzzGoldEarned", 20)
            end
            table.remove(self.tree_spawner.current_items, item_index)
            v:remove()
        else
            item_index = item_index + 1
        end
    end
    Object.endCache()
end
    --[[for i,row in ipairs(self.tree_spawner.grid) do
        for j = #row, 1, -1 do
            local item = row[j]
            if item:collidesWith(self.soul) then
                --item:remove()
                item.visible = false
                item.colliable = false
            end
        end
    end]]--

function MoneyTree:handleMovement()

    if Input.down("left") then
        self.soul.physics.speed_x = -self.movement_speed * DTMULT
    elseif Input.down("right") then
        self.soul.physics.speed_x = self.movement_speed * DTMULT
    else
        self.soul.physics.speed_x = 0
    end

end

function MoneyTree:genCoinText(text)
    local text_o = self:spawnObject(Text(text,self.soul.x,self.soul.y-20))
    text_o:setScale(0.5)
    text_o.alpha = 0
    Game.battle.timer:tween(0.25, text_o, {y = text_o.y-5, alpha = 1}, "linear", function()
        text_o:fadeOutAndRemove(0.25)
    end)
end

function MoneyTree:onEnd()
    Kristal.Console:log(self.money_caught)
    self.tree_spawner:remove()
    self.tree_bg:remove()
    self.tree_leaves:remove()
    Game:setFlag("Results", "moneytree")
    Game:setFlag("CurrentMinigame", "moneytree")
    Game.lw_money = Game.lw_money + math.floor(self.money_caught/5)
    Game:setFlag("MawzzBonus", math.floor(self.money_caught/5))
    Stepscript:backStep("moneytree")
end


return MoneyTree