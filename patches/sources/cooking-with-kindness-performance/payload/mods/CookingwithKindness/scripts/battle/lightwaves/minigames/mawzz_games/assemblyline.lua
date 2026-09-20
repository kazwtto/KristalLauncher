local AssemblyLine, super = Class("LightMinigameWave")

local AssemblyLineDebugMode = false

function AssemblyLine:init()
    if math.random(2) == 1 then
        super.init(self, _s("minigame_popup-assemblyline", "MAKE MONEY!"), "button")
        Game.battle:addChild(MawzzSounder("mawzz_makemoney"))  
    else
        super.init(self, _s("minigame_popup-assemblyline", "SORT THE CHESTS!"), "button")
        Game.battle:addChild(MawzzSounder("mawzz_sortthechests"))
    end
    self:setArenaSize(192*2,160)
    self:setArenaPosition(320,290)
    self.time = -1

    self.boxes = {}
    
    -- configuration!
    self.boxCount = {
        bomb = 5,
        coin = 10
    }

    self.scoreData = {
        coins_picked = 0,
        bombs_picked = 0,
        coins_passed = 0,
        bombs_passed = 0,
    }

    self.should_spawn_boxes = true
    self.conveyor_selectionSize = Sprite("player/heart").width * 3 -- The width of the detection for opening a chest.

    self.conveyor_Speed = 1.1 -- Amount of time, in seconds, between spawning boxes. Faster value means faster conveyor belt, and faster boxes.

    --- spawning the sprites.
    self.visualSoul = Sprite("player/heart")
    self.visualSoul:setOrigin(0.5,self.visualSoul.origin_y)
    self.visualSoul:setLayer(LIGHT_BATTLE_LAYERS.soul)
    self.hardHat = Sprite("objects/mawzz_games/xraygame/hard_hat", -8, -18)
    self.hardHat:setOrigin(0, 0)
    self.hardHat:setScale(2,2)
    self.visualSoul:addChild(self.hardHat)

    self.conveyorBelt = Sprite("objects/mawzz_games/xraygame/conveyor_full")
    self.conveyorBelt:setLayer(LIGHT_BATTLE_LAYERS.below_soul - 1)
    self.conveyorBelt:play(0.25)

    self.xrayMachine = Sprite("objects/mawzz_games/xraygame/xray")
    self.xrayMachine:setLayer(LIGHT_BATTLE_LAYERS.below_soul + 5)
    self.xrayMachine:setScale(2,2)

    self.xray_cutout = Rectangle(Game.battle.arena:getLeft()+98,Game.battle.arena:getTop()-20, 90, 80) -- the programmer art sprite uses these values. it may get changed, though.
    self.xray_cutout.visible = false
    self:addChild(self.xray_cutout)

    self.xrayMachine_Back = Sprite("objects/mawzz_games/xraygame/xray_back")
    self.xrayMachine_Back:setLayer(LIGHT_BATTLE_LAYERS.below_soul - 5)
    self.xrayMachine_Back:setScale(2,2)
    
    self.box_index = 0
    self.stunTime = 0
    self.coin_value = 2
end


---Function that prepares the data for each box. This function is run for every box, and sets up the sprites and bomb data.
---@param hasBomb boolean|nil If a bomb is inside the chest.
---@param xrayMask Object|nil
---@return table
local function boxData(hasBomb, xrayMask)
    if xrayMask == nil then xrayMask = Game.battle.arena end

    local table = {
        sprite = Sprite("objects/mawzz_games/xraygame/chest"),
        xray_sprite = nil,
        hasBomb = hasBomb or false,
        isOpen = false
    }
    if hasBomb then
        table.xray_sprite = Sprite("objects/mawzz_games/xraygame/chest_bomb")
    else
        table.xray_sprite = Sprite("objects/mawzz_games/xraygame/chest_coin")
    end

    table.sprite:setScale(2,2) -- All of the programmer art was made with scaling up in mind.
    table.sprite:setOrigin(0.5,1) -- The X coordinate needs to be at the center of the chest.
    table.sprite:setLayer(LIGHT_BATTLE_LAYERS.below_soul)

    table.xray_sprite:setLayer(LIGHT_BATTLE_LAYERS.below_soul + 1) -- The layer needs to go above the chest. It gets masked, and there's also some logic to hide it entirely past a certain point.
    table.xray_sprite:setParent(table.sprite) -- It's easiest to just parent the xray to the normal sprite.
    table.xray_sprite.visible = true

    table.sprite:addFX(MaskFX(Game.battle.arena)) -- i use the arena to mask the chests.
    table.xray_sprite:addFX(MaskFX(xrayMask))

    return table
end

function AssemblyLine:setupBoxes()
    for i = 1, self.boxCount.bomb do -- sets up bombs
        table.insert(self.boxes,boxData(true, self.xray_cutout))
    end
    for i = 1, self.boxCount.coin do -- sets up coins
        table.insert(self.boxes,boxData(false, self.xray_cutout))
    end
    self.boxes = TableUtils.shuffle(self.boxes) -- shuffles everything
end

---Increments down the box using the index variable.
function AssemblyLine:spawnNextBox()
    self.box_index = self.box_index + 1
    self.boxes[self.box_index].sprite:setSpeed(2.0 * self.conveyor_Speed, 0)
    self:spawnObject(self.boxes[self.box_index].sprite, Game.battle.arena:getLeft() - 10, self.conveyorBelt.y)
end


function AssemblyLine:onStart()
    self:setupBoxes()

    self:spawnObject(self.visualSoul, 426, 230)

    Game.battle.timer:every(self.conveyor_Speed, function ()
        if not self.finished then
            self:spawnNextBox()
        else
            return false
        end
    end, #self.boxes)


    self.conveyorBelt:setScale(2,2)
    local x,y = Game.battle.arena:getBottomLeft()
    
    self:spawnObject(self.conveyorBelt, x, y-60)
    self:spawnObject(self.xrayMachine, x, 216)
    self:spawnObject(self.xrayMachine_Back, x, 216)

    -- Create open text
    self.button = self:spawnObject(Sprite("objects/buttons/open_text"), Game.battle.arena:getRight() - 3, Game.battle.arena:getBottom() - 1)
    self.button:setLayer(LIGHT_BATTLE_LAYERS.soul)
    self.button:setScale(2)
    self.button:setOrigin(1, 1)

    -- Create open button
    self.open_button = self:spawnObject(ControlsDisplay(self.button.x-self.button.width*2, self.button.y, "button", false))
    self.open_button:setLayer(LIGHT_BATTLE_LAYERS.soul)
    self.open_button:setOrigin(1, 1)
    self.open_button:setScale(1.4)
end

function AssemblyLine:getMoney()
    return Game.lw_money
end
function AssemblyLine:setMoney(amount)
    Game.lw_money = amount
end

function AssemblyLine:awardCoin()
    self:setMoney(self:getMoney() + self.coin_value)
    local coin = Game.battle:addChild(Text("[font:main, 32][style:menu][color:yellow] +"..(self.coin_value*5).."G", self.visualSoul.x, self.visualSoul.y))
    Game:addFlag("MawzzGoldEarned", self.coin_value*5)
    -- Slide the text away and fade it out
    coin:slideTo(coin.x, coin.y - 40, 1/3, "linear", function() --MathUtils.random(-100, 100, 10)
        coin:fadeOutAndRemove(0.5)
    end)
end

function AssemblyLine:update()
    local buttonDown = Input.pressed("confirm",false)
    local buttonUp = Input.released("confirm")

    local leftX = self.visualSoul.x - (self.conveyor_selectionSize/2)
    local rightX = leftX + self.conveyor_selectionSize


    if self.stunTime > 0 then self.stunTime = self.stunTime - 1 end
    if self.stunTime % 2 == 1 then
        self.visualSoul:fadeTo(0.6, 0.05)
        self.hardHat:fadeTo(0.6, 0.05)
    else
        self.visualSoul:fadeTo(1, 0.05)
        self.hardHat:fadeTo(1, 0.05)
    end

    local active = 0
    for k,v in pairs(self.boxes) do if v.sprite.active then active = active + 1 end end
    if active == 0 and not self._cwk_finish_timer_started then
        self._cwk_finish_timer_started = true
        Game.battle.timer:after(1, function () self:setFinished() end)
    end

    
    if buttonDown and self.stunTime == 0 then
        self.visualSoul:slideTo(self.visualSoul.x, 262, 0.03)
        self.open_button.flash = false
        for k,v in pairs(self.boxes) do
            if v.sprite.x > leftX and v.sprite.x < rightX and not v.isOpen then -- looks for any chests who aren't opened already and who are within the hitbox range.
                v.isOpen = true
                v.sprite:setSprite("objects/mawzz_games/xraygame/chest_open")
                
                Assets.playSound("noise", 0.6, 1.2)

                if v.hasBomb then
                    self.scoreData.bombs_picked = self.scoreData.bombs_picked + 1
                    local bomb = Sprite("objects/mawzz_games/xraygame/bomb", v.sprite.x, v.sprite.y - 10)
                    bomb:setOrigin(0.5,1)
                    bomb:setScale(2,2)
                    self:spawnObject(bomb)
                    bomb:slideTo(v.sprite.x, v.sprite.y - 50, 0.5, "out-quad", function ()
                        local boom = Explosion()
                        boom:setScale(0.75, 0.75)
                        self:spawnObject(boom, bomb.x, bomb.y)
                        bomb:remove()
                        self.stunTime = 45
                        self.visualSoul:slideTo(self.visualSoul.x, 230, 0.05)
                    end)
                else
                    self.scoreData.coins_picked = self.scoreData.coins_picked + 1
                    local coin = Sprite("objects/mawzz_games/surfinggame/coin", v.sprite.x, v.sprite.y - 10)
                    coin:setOrigin(0.5,1)
                    coin:setScale(2,2)
                    coin:play(0.1)
                    self:spawnObject(coin)
                    Game.battle.timer:after(0.25, function ()
                        coin:fadeOutAndRemove(0.5)
                        Assets.playSound("snd_ding", 0.5, 1.2)
                        self:awardCoin()
                    end)
                    coin:slideTo(v.sprite.x, v.sprite.y - 50, .5, "out-quad", function ()
                        --self:awardCoin()
                    end)
                end

                Game.battle.timer:after(0.2, function ()
                    v.sprite:fadeOutAndRemove(0.6, "out-quad")
                    v.xray_sprite:remove()
                    self.boxes[k] = nil
                end)
            end
        end
    elseif buttonUp then
        self.visualSoul:slideTo(self.visualSoul.x, 230, 0.05)
        self.open_button.flash = true
    end

    for k,v in pairs(self.boxes) do
        --v.xray_sprite.visible = (v.sprite.x <= (Game.battle.arena:getLeft()+110))

        if (v.sprite.x >= (Game.battle.arena:getRight()-20)) then
            v.sprite:fadeOutAndRemove(0.5)
            v.xray_sprite:remove()

            if v.hasBomb then 
                self.scoreData.bombs_passed = self.scoreData.bombs_passed + 1
            else
                self.scoreData.coins_passed = self.scoreData.coins_passed + 1
            end

            self.boxes[k] = nil
        end
    end
end
function AssemblyLine:draw()
    local leftX = self.visualSoul.x - (self.conveyor_selectionSize/2)
    Draw.setColor(1, 0, 0, 1)
    love.graphics.setLineWidth(1)
    if AssemblyLineDebugMode and self.visualSoul:isFullyVisible() then Draw.rectangle("line",leftX,310,self.conveyor_selectionSize,10) end
end

function AssemblyLine:onEnd()
    self.should_spawn_boxes = false
    if AssemblyLineDebugMode then
        self:printScore(self.scoreData.coins_picked,self.scoreData.coins_passed,self.scoreData.bombs_picked,self.scoreData.bombs_passed)
    end
    self:doScore(self.scoreData.coins_picked,self.scoreData.coins_passed,self.scoreData.bombs_picked,self.scoreData.bombs_passed)

    Game:setFlag("CurrentMinigame", "assemblyline")
    Stepscript:backStep("assemblyline")
end

function AssemblyLine:doScore(coinsPicked, coinsPassed, bombsPicked, bombsPassed)
    local CoinsPresent = self.boxCount.coin
    local BombsPresent = self.boxCount.bomb

    Game:setFlag("MawzzBonus", coinsPicked*self.coin_value)
    -- the logic for determining the score can go here.
end

--- Debug print for scoring data.
function AssemblyLine:printScore(coinsPicked, coinsPassed, bombsPicked, bombsPassed)
    local total = coinsPicked + coinsPassed + bombsPicked + bombsPassed
    print("Coins Picked: "..coinsPicked.."/"..self.boxCount.coin.." ("..coinsPassed.." Passed)\n".."Bombs Picked: "..bombsPicked.."/"..self.boxCount.bomb.." ("..bombsPassed.." Passed)\n".."Total Picked: "..(coinsPicked+bombsPicked).."/"..(self.boxCount.bomb+self.boxCount.coin).."\nTotal Passed: "..(coinsPassed+bombsPassed).."/"..(self.boxCount.bomb+self.boxCount.coin))
end

return AssemblyLine