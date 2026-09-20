local SlicingGameNew, super = Class("LightMinigameWave")

function SlicingGameNew:init()
    super.init(self, _s("minigame_popup-slicinggame_new", "  SLICE!  "), "full_layout_alt")

    --self.time = 17.5
    self.time = -1

    self:setArenaSize(200,120)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 10)
    self.inputRequested = -1
    self.readyForCut = false

    self.ingredientsQueue = {}
    self.ingredientsCount = 0
    self.currentIngredientIndex = 1
    self.maxIngredientsCount = 3

    self.slices = {}
    self.particles = {}

    self.sliceCount = 0
    self.veggiesSliced = 0
    self.mistakes = 0
    self.currentMistakes = 0
    self.veggieScores = {}

    Game:setFlag("Results", "none")

    self.sliceCuttingTime = 2
    self.sliceLiftingTime = 3
    --self.sliceTimer = 0
    self.sliceStage = 'none'

    --self.ingredientList = {function(x, y, t) return SlicingGameCarrot(x,y,t) end, function(x, y, t) return SlicingGameHotPepper(x,y,t) end}
    self.ingredientList = {SlicingGameCarrot, SlicingGameHotPepper}
    Kristal.Console:log(tostring(slicingGameCarrot))

    --self.ingredientData = self:readIngredientData()
    --Kristal.Console:log(love.filesystem.getSource())
end

function SlicingGameNew:onStart()
     
     
    
    local dPadCenterX = Game.battle.arena.left
    local dPadCenterY = Game.battle.arena.top - 40
    
    self.centerX = (Game.battle.arena.left + Game.battle.arena.right) / 2
    self.cuttingBoardDatum = Game.battle.arena.left + 32
    self.knifeDatum = self.cuttingBoardDatum + 10

    self.knife = self:spawnObject(Sprite("objects/veggieslicingtest/knifeFacingCamera"))
    self.cuttingBoard = self:spawnObject(Sprite("objects/veggieslicingtest/testPlatformSliver"))

    self.knife:setScale(2,2)
    self.knife:setOrigin(0.5,0)
    self.knife:setLayer(BATTLE_LAYERS["below_soul"])
    self.knife.xBase = self.knifeDatum
    self.knife.yBase = Game.battle.arena.top + 10
    self.knife.xTarget = self.knife.xBase
    self.knife.yTravel = 35
    self.knife.x = self.knife.xBase
    self.knife.y = self.knife.yBase

    self.cuttingBoard:setScale(100,1)
    self.cuttingBoard:setOrigin(0,0)
    self.cuttingBoard:setLayer(BATTLE_LAYERS["below_soul"])
    self.cuttingBoard.x = self.cuttingBoardDatum
    self.cuttingBoard.y = Game.battle.arena.bottom - 32

    -- generate dPad objects
    self.dPad = {
        self:spawnObject(SlicingGameDPadArrow(dPadCenterX, dPadCenterY, math.rad(0))),      -- up
        self:spawnObject(SlicingGameDPadArrow(dPadCenterX, dPadCenterY, math.rad(90))),     -- right
        self:spawnObject(SlicingGameDPadArrow(dPadCenterX, dPadCenterY, math.rad(180))),    -- down
        self:spawnObject(SlicingGameDPadArrow(dPadCenterX, dPadCenterY, math.rad(270)))     -- left
    }

    self.timer:every(2/3, function()
        if self.ingredientsCount < self.maxIngredientsCount then
            
            -- if this is the first veggie, place in a specific location; 
            -- otherwise, place to the right of the previous veggie
            local x = 0
            if self.ingredientsCount == 0 or self.ingredientsQueue[self.currentIngredientIndex] == nil then
                x = self.centerX + 150
            else
                x = 10 + self.ingredientsQueue[self.ingredientsCount].x + 2*self.ingredientsQueue[self.ingredientsCount].width
            end
            local y = Game.battle.arena.bottom - 50

            -- choose ingredient type:
            local handle = TableUtils.pick(self.ingredientList)

            -- spawn veggie and place into queue table:
            local obj = self:spawnObject(handle(x, y, self.cuttingBoardDatum))
            --local obj = self:spawnObject(slicingGameCarrot(x, y, self.cuttingBoardDatum))
            obj:setLayer(BATTLE_LAYERS["above_arena"])
            if self.ingredientsCount == 0 or self.ingredientsQueue[self.currentIngredientIndex] == nil then
                obj:setNeighbor(nil)
                -- technically unnecessary for ingredientsCount == 0 case but needed for second case (when last veggie is cut before a new one has spawned)
                -- it's unlikely to happen but if it does this will prevent problems
            else
                obj:setNeighbor(self.ingredientsQueue[self.ingredientsCount])
            end
            table.insert(self.ingredientsQueue,obj)

            self.ingredientsCount = self.ingredientsCount + 1

        end
    end)
end

function SlicingGameNew:moveKnife()
    self.sliceStage = 'cutting'
    self.knife:slideTo(self.knife.xTarget, self.knife.yBase + self.knife.yTravel, self.sliceCuttingTime/30, 'linear', function()
        -- after cuting is completed, update stage flag and move knife to new position
        --Assets.playSound("snd_chop_noise_only")
        Assets.playSound("snd_chop_7")
        self.sliceStage = 'lifting'
        self.sliceCount = self.sliceCount + 1
        
        local spent = self.ingredientsQueue[self.currentIngredientIndex]:slice(self)
        if spent then
            self.currentIngredientIndex = self.currentIngredientIndex + 1
            if self.ingredientsQueue[self.currentIngredientIndex] ~= nil then
                self.ingredientsQueue[self.currentIngredientIndex]:setNeighbor(nil)
            end

            self.knife.xTarget = self.knifeDatum

            self.veggiesSliced = self.veggiesSliced + 1

            self:score(self.currentMistakes)
            self.currentMistakes = 0
        else
            self.knife.xTarget = self.knife.xTarget + 2*self.ingredientsQueue[self.currentIngredientIndex].data.sliceWidth
        end

        -- apply 2 frames (at 30fps) of jolt to cutting board:
        self.cuttingBoard:slideTo(self.cuttingBoard.x, self.cuttingBoard.y + 3, 2/30, 'linear', function()
            self.cuttingBoard:slideTo(self.cuttingBoard.x, self.cuttingBoard.y - 3, 1/30)
        end)

        -- begin lifting knife:
        self.knife:slideTo(self.knife.xTarget, self.knife.yBase, self.sliceLiftingTime/30, 'linear', function()
            -- after lifting is completed, reset stage flag and set flag to get new desired input
            self.sliceStage = 'none'
            self.inputRequested = -1
        end)
    end)
end

function SlicingGameNew:score(mistakes)
    local grade = 0

    local msg = ""
    local snd = "error"

    -- Score the slice, add that score to the sliceScores table, and show text popup of how good you did
    if mistakes <= 0 then
        msg = "Perfect"
        snd = "snd_perfect"
        grade = 5
        
    elseif mistakes <= 2 then
        msg = "Great"
        snd = "snd_great"
        grade = 3
        
    elseif mistakes <= 3 then
        msg = "Okay"
        snd = "snd_good"
        grade = 1
        
    else
        if MathUtils.random() > 0.25 then
            msg = "Bad"
        else
            msg = ":("
        end
        snd = "error"
        grade = 0
        
    end
    
    self:scoreMessage(msg, 320, 260)
    Assets.playSound(snd, 0.6, 1.2)

    table.insert(self.veggieScores, grade)
end

function SlicingGameNew:update()
    -- Code here gets called every frame

    if self.inputRequested == -1 then
        self.inputRequested = math.floor(Utils.random(1,4.9999))
        self.dPad[self.inputRequested]:turnOn()
    end
    
    if self.ingredientsQueue[self.currentIngredientIndex] ~= nil then
        -- only allow cut if current veggie returns good readyToCut
        self.readyForCut = self.ingredientsQueue[self.currentIngredientIndex].readyForCut and self.sliceStage == 'none'
    end

    if self.readyForCut then
        -- Get input and convert to a number for easy indexing into dPad stuff:
        self.button = -1
        if Input.pressed("up") then
            self.button = 1
        end
        if Input.pressed("right") then
            self.button = 2
        end
        if Input.pressed("down") then
            self.button = 3
        end
        if Input.pressed("left") then
            self.button = 4
        end


        if self.button ~= -1 then
            if self.button == self.inputRequested then
                -- if correct input was made, turn on green highlight on dPad for 4/30ths and begin slice animation
                self.dPad[self.button]:turnOff()
                self.dPad[self.button]:highlightCorrect(4)
                
                self:moveKnife()
            else
                -- else, turn on red highlight on dPad for 4/30ths
                self.dPad[self.button]:highlightIncorrect(4)
                Assets.playSound("error", 0.6, 1.2)
                --for performance tracking, I think having a count of incorrect buttons would be useful, as it makes
                --sense to me to judge performance here by the lack of errors rather than amount of slices (Rose)
                self.mistakes = self.mistakes + 1
                self.currentMistakes = self.currentMistakes + 1
                --we may add more sfx or indicators to highlight how this loses points in the polish stage
            end
        end
    end

    -- Temporarily commenting this out, since the scoring for this minigame is getting changed
    --[[ if self.mistakes >= 7 then
        --Trying to make it so that after a certain amount of mistakes, the minigame ends without giving score.

            self.finished = true
            CustScore:addPoints(0)
            Stepscript:backStep("vegetable_slice")
            
    end ]]

    if self.currentIngredientIndex > self.maxIngredientsCount and not self._cwk_finish_timer_started then
        self._cwk_finish_timer_started = true
        self.timer:after(0.5, function ()
            self.finished = true
        end)
    end

    local slice_write = 1
    for slice_read = 1, #self.slices do
        local slice = self.slices[slice_read]
        if slice.y > SCREEN_HEIGHT + 20 or slice.x < -20 then
            slice:remove()
        else
            self.slices[slice_write] = slice
            slice_write = slice_write + 1
        end
    end
    for i = #self.slices, slice_write, -1 do
        self.slices[i] = nil
    end

    super.update(self)
end

function SlicingGameNew:onEnd()
    Kristal.Console:log("Slices:     "..self.sliceCount)
    Kristal.Console:log("Veggie cut: "..self.veggiesSliced)
    Kristal.Console:log("Mistakes: "..self.mistakes)
    Game:setFlag("SliceScore", self.sliceCount)
    --Kristal.Console:log(self.knife.x)
    --Kristal.Console:log(self.knife.y)

    local avg = 0
    for _, v in ipairs(self.veggieScores) do
        avg = avg + v
    end
    print(avg/self.maxIngredientsCount)
    avg = math.floor(avg/self.maxIngredientsCount)

    print(avg)
    if avg == 4 and self.mistakes <= 1 then
        CustScore:addPoints(3)
    else
        CustScore:addPoints(avg)
    end

    if avg == 0 then
        Stepscript:backStep("vegetable_slice")
    else
        Game.battle:getEnemyBattler("dino").metrecs = true
    end
end

return SlicingGameNew