local FryPackingGame, super = Class("LightMinigameWave")

function FryPackingGame:init()
    super.init(self, _s("minigame_popup-fry_packing_game_big", "PACK!"), "full_layout", true)

    self.grid_size = 5 -- amount of cells in each row, as well as amount of rows.
    self.cell_size = 40 -- sets pixel size in square pixels. 40 seems to be a good mid-point for total cell size.

    self.fryGrid = {}
    

    self.inputLock = false
    self.grab_non_shape = false

    self.indicators = {}
    self.blocks = {}

    self.shape_size = 4
    self.shape_count = 0

    self.colorTable = {
        {1.0, 1.0, 1.0}
    }
    self.accessibilityColors = false
    self.accessibilitySprites = false
    self.accessibilitySpriteAmount = 6
    local color_step_dist = 2
    local color_base = 0.6
    for r=0, color_step_dist do
    for g=0, color_step_dist do
    for b=0, color_step_dist do
        table.insert(self.colorTable, {color_base+((1.0-color_base)*(r/color_step_dist)),color_base+((1.0-color_base)*(g/color_step_dist)),color_base+((1.0-color_base)*(b/color_step_dist))})
    end
    end
    end

    self.allPacked_color = {r=1.0,g=1.0,b=0.0}


    self.time = 25
    self.allPacked = false
    self.arena_size_x = 250+self:getGridSize()
    self.arena_size_y = 60+self:getGridSize()
    self:setArenaSize(self.arena_size_x, self.arena_size_y)
    self:setArenaOffset(0,200-(20*self.grid_size))

    self.selected_bullet = nil -- the bullet we're currently moving, if any. should be nil whenever we are not actively moving a piece.
    self.selected_bullet_offset = {x=0,y=0} -- its' offset.
end


function FryPackingGame:getGridSize()
    return self.grid_size * self.cell_size
end

function FryPackingGame:spawnIndicators()
    for x = 1, self.grid_size do
        for y = 1, self.grid_size do
            local bulletX, bulletY = Game.battle.arena:getCenter()  -- grabs center of arena for placing grid nodes.
            bulletX = bulletX - (self:getGridSize()/2) + self.cell_size*x -- shift from center X to the edge, and then shift based on how many cells we are in.
            bulletY = bulletY - (self:getGridSize()/2) + self.cell_size*y -- ditto, for center Y
            self.indicators[""..x..y] = self:spawnBullet("indicator_bullet", bulletX-(self.cell_size/4), bulletY-(self.cell_size/4), x, y, self)
            --self.indicators[x..y] = self:spawnBullet("indicator_bullet", bulletX-(self.cell_size/2), bulletY-(self.cell_size/2), x, y, self)
        end
    end
end
function FryPackingGame:spawnBlocks()
    for x = 1, self.grid_size do
        for y = 1, self.grid_size do
            local bulletX, bulletY = Game.battle.arena:getCenter()  -- grabs center of arena for placing grid nodes.
            bulletX = bulletX - (self:getGridSize()/2) + self.cell_size*x -- shift from center X to the edge, and then shift based on how many cells we are in.
            bulletY = bulletY - (self:getGridSize()/2) + self.cell_size*y -- ditto, for center Y
            self.blocks[""..x..y] = self:spawnBullet("fry_block_bullet", bulletX-(self.cell_size/2), bulletY-(self.cell_size/2), x, y, self)
        end
    end
end

function FryPackingGame:spawnIndicator(x,y, layerOffset)
    local bulletX, bulletY = Game.battle.arena:getCenter()  -- grabs center of arena for placing grid nodes.
    bulletX = bulletX - (self:getGridSize()/2) + self.cell_size*x -- shift from center X to the edge, and then shift based on how many cells we are in.
    bulletY = bulletY - (self:getGridSize()/2) + self.cell_size*y -- ditto, for center Y
    local bullet = self:spawnBullet("indicator_bullet", bulletX-(self.cell_size/2), bulletY-(self.cell_size/2), x, y, self)
    bullet.layer = bullet.layer + (layerOffset or 0)
    --table.insert(self.indicators,bullet)
    self.indicators[""..x..y] = bullet
    --self.indicators[x..y] = self:spawnBullet("indicator_bullet", bulletX-(self.cell_size/2), bulletY-(self.cell_size/2), x, y, self)
end
function FryPackingGame:spawnBlock(x,y, layerOffset)
    local bulletX, bulletY = Game.battle.arena:getCenter()  -- grabs center of arena for placing grid nodes.
    bulletX = bulletX - (self:getGridSize()/2) + self.cell_size*x -- shift from center X to the edge, and then shift based on how many cells we are in.
    bulletY = bulletY - (self:getGridSize()/2) + self.cell_size*y -- ditto, for center Y
    local bullet = self:spawnBullet("fry_block_bullet", bulletX-(self.cell_size/2), bulletY-(self.cell_size/2), x, y, self)
    bullet.layer = bullet.layer + (layerOffset or 0)
    self.blocks[""..x..y] = bullet
end

function FryPackingGame:getBlockAt(x,y, noShapes)
    if noShapes and (self.blocks[""..x..y] ~= nil) then
        if self.blocks[""..x..y].shape_id == nil then return self.blocks[""..x..y] end
    else
        return self.blocks[""..x..y]
    end
end
function FryPackingGame:getAdjacentEmptyCells(x, y) -- gets the empty neighbors.
    local adjacent = {}
    local n_offs = { {x = 1, y = 0}, {x = -1, y = 0}, {x = 0, y = 1}, {x = 0, y = -1} }
    for _, off in ipairs(n_offs) do
        local nX, nY = x + off.x, y + off.y
        local obj = self:getBlockAt(nX, nY)
        if obj and obj:getShapeID() == nil then -- it is only when i was writing this line, that i remembered explicit nil-checks aren't needed, because nil counts as false. in the words of rouxls kaard, god damn it.
            table.insert(adjacent, {x = nX, y = nY})
        end
    end
    return adjacent
end
math.randomseed(os.time())
function FryPackingGame:assignShapes(grid_size, shape_size) -- assigns shapes. loosely documened because this hurt to make.
    local count = 0
    local ec = {} -- where we store our empty cells.
    for gY = 1, grid_size do -- construction of the empty cells list here
        for gX = 1, grid_size do
            if self:getBlockAt(gX, gY):getShapeID() == nil then
                table.insert(ec, {x = gX, y = gY})
            end
        end
    end
    Utils.shuffle(ec)
    for _, start_cell in ipairs(ec) do -- we build the shape here
        local obj = self:getBlockAt(start_cell.x, start_cell.y)
        if obj and obj:getShapeID() == nil then
            local coords = {start_cell}
            local open_list = self:getAdjacentEmptyCells(start_cell.x, start_cell.y)

            while #coords < shape_size and #open_list > 0 do -- this has been rewritten enough that i'm giving up trying to explain it - moist, @ 8th rewrite.
                local index = Utils.random(1, #open_list, 1)
                local next_cell = open_list[index]
                table.remove(open_list, index)

                local next_obj = self:getBlockAt(next_cell.x, next_cell.y)
                if next_obj and next_obj:getShapeID() == nil then
                    table.insert(coords, next_cell)
                    
                    local neighbors2 = self:getAdjacentEmptyCells(next_cell.x, next_cell.y) -- get new sets of neighbors.
                    for _, new_n in ipairs(neighbors2) do
                        local already_in_coords = false -- this stuff here checks if we're in coords first ↓
                        for _, coord in ipairs(coords) do if new_n.x == coord.x and new_n.y == coord.y then already_in_coords = true break end end
                        if not already_in_coords then -- make sure it isn't in the list of available cells already, before noting down an available cell.
                            local already_in_open = false
                            for _, open_n in ipairs(open_list) do if new_n.x == open_n.x and new_n.y == open_n.y then already_in_open = true break end end -- just another iterator. i forget how much it's containing.
                            if not already_in_open then
                                table.insert(open_list, new_n)
                            end
                        end
                    end
                end
            end
            if #coords >= math.floor(shape_size * 0.5) then -- set the shape once we've calculated everything, and ensured it's at least ~half of the shape size.
                count = count + 1
                local color = Utils.shuffle(self.colorTable)
                for _, coord in ipairs(coords) do
                    self:putColorToCoords(coord.x, coord.y)
                    if self.accessibilitySprites then
                        local url = "bullets/fry_block"..(count%self.accessibilitySpriteAmount).."acc"
                        self:getBlockAt(coord.x, coord.y):setSprite(url)
                    end
                    self:getBlockAt(coord.x, coord.y):setShapeID(tostring(count))
                end
                self.shape_count = count
            end
        end
    end
end

function FryPackingGame:putColorToCoords(x, y)
    self:putColor(self:getBlockAt(x, y))
end

function FryPackingGame:handleFinalColor()
    for _,v in ipairs(self._cwk_block_list or self.blocks) do
        if self.allPacked then
            v:setDisplayColor(self.allPacked_color.r, self.allPacked_color.g, self.allPacked_color.b)
        else
            v:setShapeColor()
        end
    end
end
function FryPackingGame:putColor(block)
    if self.accessibilityColors then
        block:setShapeColor(color[count])
        return
    else
        block:setShapeColor(1.0, 1.0, 0.8)
        return
    end
end

function FryPackingGame:scatterShapes(grid_size)
    local midpoint = 1+self.shape_count/2
    local area_height = self:getGridSize()+50
    local offset = ((self:getGridSize()+75)/2)+20
    local x,y = Game.battle.arena:getCenter()
    local top = Game.battle.arena:getTop()
    local function isOdd(num)
        if num % 2 == 0 then
            return 1
        else
            return -1
        end
    end
    local distance = area_height / midpoint
    for i = 1, self.shape_count do
        local hoff = Utils.random(-20,20)
        local hoff2 = Utils.random(0,30)*isOdd(i)
        local voff = Utils.random(-20,20)
        for _,bullet in pairs(self.blocks) do
            if bullet:getShapeID() == tostring(i) then
                bullet:shift((offset*isOdd(i)),0)
                local bX, bY = bullet:getPosition()
                bullet:setPosition(bX, top+(self.cell_size*bullet.grid_y))
                bullet:shift(hoff+-hoff2,voff+(30*((i/2)-1)))
            end
        end
    end

    if Kristal.getLibConfig("moist-lib","debug_prints") then
        print("Starting positions - "..self.shape_count.." shapes, L:1, R:"..midpoint.."| distance: "..distance.." CENTER: | "..x..","..y)
    end
end

function FryPackingGame:markImmovables()
    if not self.grab_non_shape then
        for key, value in pairs(self.blocks) do
            if value.shape_id == nil then value.grabbable = false; value:setColor(0.5, 0.5, 0.5) end
        end
    end
end

function FryPackingGame:onStart()
    self.fryGrid = {}
    local success
    for x = 1, self.grid_size do
        for y = 1, self.grid_size do
            self.fryGrid[""..x..y] = {occupied = false}
            self:spawnBlock(x,y) -- spawn an individual block at that point on the grid.
            self:spawnIndicator(x,y,1) -- spawn an individual indicator at that point on the grid, with an offset pushing it a layer higher.
        end
    end
    self:assignShapes(self.grid_size, self.shape_size)
    self:scatterShapes(self.grid_size)
    self:markImmovables()
    self:buildPerformanceCaches()
    self._cwk_collision_dirty = true

    -- Show controls
    self.controls = self:spawnObject(Sprite("objects/buttons/full_layout", Game.battle.arena:getLeft() + 40, Game.battle.arena:getTop() + 40))
    self.controls:setOrigin(0.5)
    self.controls:setScale(2)
    self.controls:play(0.25, true)
    Game.battle.timer:after(5, function ()
        self.controls:remove()
    end)
end

function FryPackingGame:handleGrab(bullet)
    if self.selected_bullet ~= nil then
        self.selected_bullet = nil -- if we've already selected a bullet, we let go of it instead, by unreferencing it.
    else
        
    end
end

function FryPackingGame:moveBlockOrShape(bullet, shapeID)
    local shapeID = shapeID or bullet.shape_id
end

function FryPackingGame:playForCollidingIndicator(block)
    Object.startCache()
    for _,v in ipairs(self._cwk_indicator_list) do
        if v.collider:collidesWith(block.collider) then
            v:playSound()
        end
    end
    Object.endCache()
end

function FryPackingGame:buildPerformanceCaches()
    self._cwk_block_list = {}
    self._cwk_indicator_list = {}
    self._cwk_shape_blocks = {}

    for _, block in pairs(self.blocks) do
        self._cwk_block_list[#self._cwk_block_list + 1] = block
        if block.shape_id then
            local shape = self._cwk_shape_blocks[block.shape_id]
            if not shape then
                shape = {}
                self._cwk_shape_blocks[block.shape_id] = shape
            end
            shape[#shape + 1] = block
        end
    end
    for _, indicator in pairs(self.indicators) do
        self._cwk_indicator_list[#self._cwk_indicator_list + 1] = indicator
    end
end

function FryPackingGame:getShapeBlocks(block)
    if block.shape_id then
        return self._cwk_shape_blocks[block.shape_id]
    end
    return {block}
end

function FryPackingGame:refreshIndicatorCollisions()
    local indicators = self._cwk_indicator_list

    if self._cwk_collision_dirty then
        local blocks = self._cwk_block_list
        local broad_phase = self.cell_size * 2

        Object.startCache()
        for i = 1, #indicators do
            local indicator = indicators[i]
            local colliding = false
            for j = 1, #blocks do
                local block = blocks[j]
                if math.abs(indicator.x - block.x) <= broad_phase
                and math.abs(indicator.y - block.y) <= broad_phase
                and indicator.collider:collidesWith(block) then
                    colliding = true
                    break
                end
            end
            indicator._cwk_cached_colliding = colliding
        end
        Object.endCache()

        self._cwk_collision_dirty = false
    end

    -- GridNode consumes and clears .colliding in its own update, so restore
    -- the cached result each frame without repeating the expensive collision tests.
    for i = 1, #indicators do
        indicators[i].colliding = indicators[i]._cwk_cached_colliding == true
    end
end

function FryPackingGame:update()
    local total = 0

    self:refreshIndicatorCollisions()
    for _,v in ipairs(self._cwk_indicator_list) do
        if v.occupied then total = total + 1 end
    end

    self.allPacked = (total == (self.grid_size * self.grid_size) and not self.selected_bullet)
    if self.allPacked then
        if not self.show_score then
            local count = 0
            local score = 0
            for k,v in pairs(self.indicators) do
                local occupied = v.occupied
                local inc
                if occupied then inc = 1 else inc = 0 end
                count = count + inc
                score = (count/16)*5
            end

            self:score(score)
            self.show_score = true
        end
        if not self._cwk_finish_timer_started then
            self._cwk_finish_timer_started = true
            Game.battle.timer:after(1.0, function ()
                if self.allPacked then
                    self:setFinished()
                else
                    self._cwk_finish_timer_started = false
                end
            end)
        end
    end
    self:handleFinalColor()

    if Input.pressed("confirm") and not self.inputLock then -- handle moving fry blocks.
        self.inputLock = true
        if self.selected_bullet ~= nil then
            for _,v in ipairs(self:getShapeBlocks(self.selected_bullet)) do
                v:setShapeColor()
            end
            self:playForCollidingIndicator(self.selected_bullet)
            self.selected_bullet = nil
        else
            for k,bullet in pairs(self.blocks) do -- check all the loaded bullets.
                if bullet:isColliding() and bullet.grabbable then
                    Assets.playSound("noise")
                    bullet:setOffset(0,0)
                    self.selected_bullet = bullet
                    for _,v in ipairs(self:getShapeBlocks(bullet)) do
                        v:setDisplayColor(1.0,1.0,0.7)
                        v:autoOffset(Game.battle.soul)
                    end
                    -- local x,y = Game.battle.soul:getExactPosition(Game.battle.soul.x, Game.battle.soul.y)
                    -- local x2,y2 = bullet:getPosition()
                    -- bullet:setOffset(x2-x, y2-y)
                    break
                end
            end
        end
    else
        if self.inputLock == true and not self.allPacked then self.inputLock = false end
    end
    
    if self.selected_bullet ~= nil then
        local x,y = Game.battle.soul:getExactPosition(Game.battle.soul.x, Game.battle.soul.y)
        local moved = false
        if self.selected_bullet.shape_id == nil then
            moved = self.selected_bullet:move(x,y)
        else
            for _,bullet in ipairs(self:getShapeBlocks(self.selected_bullet)) do
                moved = bullet:move(x,y) or moved
            end
        end
        if moved then
            self._cwk_collision_dirty = true
        end
    end
end

function FryPackingGame:beforeEnd()
end
function FryPackingGame:onEnd()
    if Kristal.getLibConfig("moist-lib","debug_prints") then
        for x=1, self.grid_size do
            local line = {}
            for y=1, self.grid_size do
            local block = self.blocks[""..x..y]
            local shape_id = block.shape_id or "nil"
            table.insert(line, "coords:"..block.grid_x..","..block.grid_y..", id ="..shape_id..",")
            end
            print(table.concat(line," | "))
        end
    end

    local count = 0
    local score = 0
    for k,v in pairs(self.indicators) do
        local occupied = v.occupied
        local inc
        if occupied then inc = 1 else inc = 0 end
        count = count + inc
        score = (count/16)*5
    end
    --print("score: "..count)
    
    if Kristal.getLibConfig("moist-lib","debug_prints") then
        print("Adjusted Score: "..math.floor(score))
    end
    Game.battle.encounter:setFlag("fryPackingScore", math.floor(score))
end

function FryPackingGame:score(score)
    local text = self:spawnObject(Sprite("ui/battle/scoremsg/blank"), 320, 200)
    text:setScale(1.66)
    text:setOrigin(0.5)
    text:setLayer(BATTLE_LAYERS["top"])

    -- Score the slice, add that score to the sliceScores table, and show text popup of how good you did
    if score >= 5 then
        text:setSprite("ui/battle/scoremsg/perfect")
        Assets.playSound("snd_perfect", 0.6, 1.2)
        CustScore:addPoints(5)
        
    elseif score >= 4 then
        text:setSprite("ui/battle/scoremsg/great")
        Assets.playSound("snd_great", 0.6, 1.2)
        CustScore:addPoints(4)

    elseif score >= 3 then
        text:setSprite("ui/battle/scoremsg/great")
        Assets.playSound("snd_good", 0.6, 1.2)
        CustScore:addPoints(3)
        
    elseif score >= 2 then
        text:setSprite("ui/battle/scoremsg/okay")
        Assets.playSound("snd_won")
        CustScore:addPoints(2)
        
    else
        CustScore:addPoints(0)
        Assets.playSound("error", 0.6, 1.2)
        Stepscript:backStep("frenchfry")
        if MathUtils.random() > 0.25 then
            text:setSprite("ui/battle/scoremsg/bad")
        else
            text:setSprite("ui/battle/scoremsg/frown")
        end
        
    end
    
    text:slideTo(text.x + MathUtils.random(-100, 100, 10), text.y - 100, 1/3, "out-cubic", function()
        text:fadeOutAndRemove(0.5)
    end)

end 

return FryPackingGame