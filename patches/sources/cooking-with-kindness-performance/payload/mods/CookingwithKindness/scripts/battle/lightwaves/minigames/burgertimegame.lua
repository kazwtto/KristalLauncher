-- Code by Mose, Credit to the Burger Time Arcade Game

local BurgerTimeGame, super = Class("LightMinigameWave")

function BurgerTimeGame:init()
    super.init(self, _s("minigame_popup-burgertimegame", "STACK!"), "full_layout_alt")

    self.time = -1

    Game:setFlag("Results", "none")

    self:setArenaSize(416,384)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 10)

    self:setSoulPosition(10000,10000)

    self.tile_map = -- Array of all of the tiles making up the map (Currently 13x24), each tile is 32x16 pixels (upscaled from 16x8)
                   -- 0 = empty
                   -- t = top of ladder
                   -- l = ladder
                   -- m = platform with ladder above and below it
                   -- b = bottom of ladder
                   -- p = platform
                   -- { = weird little basket thing that catches the burgers

    { -- 1  2   3    4    5    6    7    8    9   10   11  12  13
        {0, 0,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 , 0, 0}, -- 1
        {0, 0,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 , 0, 0}, -- 2
        {0, 0,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 , 0, 0}, -- 3
        {0, 0, "t", "p", "p", "p", "p", "t", "p", "p", "b", 0, 0}, -- 4
        {0, 0, "l",  0 ,  0 ,  0 ,  0 , "l",  0 ,  0 ,  0 , 0, 0}, -- 5
        {0, 0, "l",  0 ,  0 ,  0 ,  0 , "l",  0 ,  0 ,  0 , 0, 0}, -- 6
        {0, 0, "l",  0 ,  0 ,  0 ,  0 , "l",  0 ,  0 ,  0 , 0, 0}, -- 7
        {0, 0, "b", "p", "p", "t", "p", "m", "p", "p", "t", 0, 0}, -- 8
        {0, 0,  0 ,  0 ,  0 , "l",  0 , "l",  0 ,  0 , "l", 0, 0}, -- 9
        {0, 0,  0 ,  0 ,  0 , "l",  0 , "l",  0 ,  0 , "l", 0, 0}, -- 10
        {0, 0,  0 ,  0 ,  0 , "l",  0 , "m", "p", "p", "b", 0, 0}, -- 11
        {0, 0, "t", "p", "p", "m",  0 , "l",  0 ,  0 ,  0 , 0, 0}, -- 12
        {0, 0, "l",  0 ,  0 , "l",  0 , "l",  0 ,  0 ,  0 , 0, 0}, -- 13
        {0, 0, "l",  0 ,  0 , "l",  0 , "l",  0 ,  0 ,  0 , 0, 0}, -- 14
        {0, 0, "l",  0 ,  0 , "b", "p", "b", "p", "p", "t", 0, 0}, -- 15
        {0, 0, "l",  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 , "l", 0, 0}, -- 16
        {0, 0, "l",  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 , "l", 0, 0}, -- 17
        {0, 0, "l",  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 , "l", 0, 0}, -- 18
        {0, 0, "b", "p", "p", "b", "p", "b", "p", "p", "b", 0, 0}, -- 19
        {0, 0,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 , 0, 0}, -- 20
        {0, 0,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 , 0, 0}, -- 21
        {0, 0,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 , 0, 0}, -- 22
        {0, 0,  0 , "{",  0 ,  0 ,  0 ,  0 , "{",  0 ,  0 , 0, 0}, -- 23
        {0, 0,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 ,  0 , 0, 0}, -- 24
    }

    self.tile_width = 32
    self.tile_height = 16

    self.tiles = {} -- A list of the tiles that are actually filled, should contain information such as coordinates and what kind of tile it is

    self.burger_parts = {} -- A table that will contain all burger parts on the map

    self.lives = 3
    self.life_meter = {}
    self.invincible = false
    self.iFrames = 30/30

    self.useTimer = 0
    self.useFlashTimer = 0

    self.canMove = true
end

function BurgerTimeGame:onStart()
    super.onStart(self)

    self.center_x, self.center_y = Game.battle.arena:getCenter()

    -- Read the tilematp and make each tile
    for r, v in ipairs(self.tile_map) do
        for c, w in ipairs(v) do
            if w ~= 0 then

                local tile = self:spawnObject(Sprite("objects/burgertimegame/tiles/"..w))
                tile:setScale(2)

                tile.row = r
                tile.column = c

                tile.x = Game.battle.arena.left + ((c - 1) * self.tile_width)
                tile.y = Game.battle.arena.top + ((r - 1) * self.tile_height)

                tile.type = ""

                if w == "t" then
                    tile.type = "top"
                elseif w == "l" then
                    tile.type = "ladder"
                elseif w == "b" then
                    tile.type = "bottom"
                elseif w == "m" then
                    tile.type = "middle"
                elseif w == "p" then
                    tile.type = "platform"
                elseif w == "{" then
                    tile.type = "basket"
                    tile:setOriginExact(16, 0)
                end

                table.insert(self.tiles, tile)
                table.remove(self.tile_map[r], c)
                table.insert(self.tile_map[r], c, tile) -- replace this spot on the tilemap with the tile object
            else -- If the tile is meant to be empty, make a small table containing some information about these coordinates
                local tile = {}
                tile.x = Game.battle.arena.left + ((c - 1) * self.tile_width)
                tile.y = Game.battle.arena.top + ((r - 1) * self.tile_height)
                tile.type = "none"
                table.remove(self.tile_map[r], c)
                table.insert(self.tile_map[r], c, tile) -- replace this spot on the tilemap this little table
            end
        end
    end

    -- Create the player SOUL
    self.heart = self:spawnObject(Sprite("player/heart_legs_smol"), self.center_x, Game.battle.arena.top + (18 * self.tile_height))
    self.heart:setOrigin(0.5,1)
    self.heart:setScale(2)
    self.heart:setLayer(BATTLE_LAYERS["soul"])
    self.heart.collider = Hitbox(self.heart, (1/3 * self.heart.width), 0, (1/3 * self.heart.width), self.heart.height)
    self.heart.speed = 3
    self.heart.state = "WALKING"
    
    -- Set the heart's position to a valid tile just so it doesn't return nil on the first frame
    self.heart.on = self.tiles[1]
    self.heart.left = self.tiles[1]
    self.heart.right = self.tiles[1]
    self.heart.up = self.tiles[1]
    self.heart.down = self.tiles[1]

    -- Create fire enemy
    self.enemy_1 = self:spawnObject(fire_enemy_1(self.center_x, self.tile_map[8][7].y))
    self.enemy_2 = self:spawnObject(fire_enemy_2(self.center_x, self.tile_map[15][7].y))

    -- Spawn life count
    for i = 1, self.lives do
        local life = self:spawnObject(Sprite("ui/battle/icons/heart_small"), (Game.battle.arena.left + 8) + ((i-1)*22), Game.battle.arena.top + 8)
        life:setScale(2)
        table.insert(self.life_meter, i, life)
    end

    -- Create burger parts
    self.burger_parts = {
        self:spawnObject(burger_part(self.tile_map[19][9].x, self.tile_map[19][9].y, "bottom_bun")),
        self:spawnObject(burger_part(self.tile_map[15][9].x, self.tile_map[15][9].y, "patty")),
        self:spawnObject(burger_part(self.tile_map[11][9].x, self.tile_map[11][9].y, "lettuce")),
        self:spawnObject(burger_part(self.tile_map[4][9].x, self.tile_map[4][9].y, "top_bun")),

        self:spawnObject(burger_part(self.tile_map[19][4].x, self.tile_map[19][4].y, "bottom_bun")),
        self:spawnObject(burger_part(self.tile_map[12][4].x, self.tile_map[12][4].y, "patty")),
        self:spawnObject(burger_part(self.tile_map[8][4].x, self.tile_map[8][4].y, "lettuce")),
        self:spawnObject(burger_part(self.tile_map[4][4].x, self.tile_map[4][4].y, "top_bun")),
    }
end

function BurgerTimeGame:update()
    super.update(self)

    --print("ON: "..self.heart.on.type..", UP: "..self.heart.up.type..", DOWN: "..self.heart.down.type.." | "..self.heart.state)
    self:getTile(self.heart)
    self:getNextTiles(self.heart)

    if self.canMove then
        self:moveHeart()
    end
    
    self:burgerCollision(self.heart)

    if (self.heart.collider:collidesWith(self.enemy_1.collider) or self.heart.collider:collidesWith(self.enemy_2.collider)) and not self.invincible then
        self:hit()
    end

    local stacked = 0
    for _, v in ipairs(self.burger_parts) do
        if v.is_stacked then stacked = stacked + 1 end
    end
    if stacked == #self.burger_parts and not self._cwk_finish_timer_started then
        self._cwk_finish_timer_started = true
        self.timer:after(1, function ()
            self.finished = true
        end)
    end

    -- SOUL flashing effect while invulnerable
    if self.useTimer > 0 then
        self.useTimer = Utils.approach(self.useTimer, 0, DT)
        self.useFlashTimer = self.useFlashTimer + DT
        local amt = math.floor(self.useFlashTimer / (4/30))
        local dimmed = (amt % 2) == 1
        if dimmed then
            if self.heart.color[1] ~= 0.5 or self.heart.color[2] ~= 0.5 or self.heart.color[3] ~= 0.5 then
                self.heart:setColor(0.5, 0.5, 0.5)
            end
        else
            if self.heart.color[1] ~= 1 or self.heart.color[2] ~= 1 or self.heart.color[3] ~= 1 then
                self.heart:setColor(1, 1, 1)
            end
        end
    else
        self.useFlashTimer = 0
        if self.heart.color[1] ~= 1 or self.heart.color[2] ~= 1 or self.heart.color[3] ~= 1 or self.heart.alpha ~= 1 then
            self.heart:setColor(1, 1, 1, 1)
        end
    end

    if self.lives == 0 and not self._cwk_fail_timer_started then
        self._cwk_fail_timer_started = true
        self.canMove = false
        self.heart:stop()
        self.timer:after(0.25, function ()
            self.finished = true
        end)
    end
end

-- WE LOVE NESTED FOR LOOPS!!!
-- Checks if the SOUL is touching a burger part, if it is, then lower each segment the SOUL crosses
function BurgerTimeGame:burgerCollision(heart)
    for _, part in ipairs(self.burger_parts) do
        if heart.collider:collidesWith(part.collider) then
            part:checkSegments(heart)
        end
    end
end

function BurgerTimeGame:moveHeart()
    if not self.heart.playing then
        self.heart:play(0.1)
    end

    -- WALKING state actions
    if self.heart.state == "WALKING" then
        if Input.down("right") and ((self.heart.right.type == "platform" or self.heart.right.type == "top" or self.heart.right.type == "bottom" or self.heart.right.type == "middle") or (self.heart.x < self.heart.right.x - 4)) then
            self.heart.x = self.heart.x + DTMULT*self.heart.speed -- Move right
            self.heart.scale_x = 2 -- Face the heart to the right
        end

        if Input.down("left") and ((self.heart.left.type == "platform" or self.heart.left.type == "top" or self.heart.left.type == "bottom" or self.heart.left.type == "middle") or (self.heart.x > self.heart.left.x + self.tile_width + 4)) then
            self.heart.x = self.heart.x - DTMULT*self.heart.speed -- Move left
            self.heart.scale_x = -2 -- Face the heart to the left
        end

        if self.heart.up.type == "ladder" and self.heart.on.type ~= "none" then
            if Input.down("up") then
                self.heart:setSprite("player/heart_legs_smol_up") 
                self.heart.state = "CLIMBING"
            end
        end
        
        if self.heart.down.type == "ladder" and self.heart.on.type ~= "none" then
            if Input.down("down") then
                self.heart:setSprite("player/heart_legs_smol_up") 
                self.heart.state = "CLIMBING"
            end
        end
    end

    -- CLIMBING state actions
    if self.heart.state == "CLIMBING" then
        if Input.down("up") and not Input.down("down") then
            self.heart.y = self.heart.y - DTMULT*self.heart.speed
            if self.heart.on.type == "top" and (self.heart.y > self.heart.on.y - 2 and self.heart.y < self.heart.on.y + 2) then
                self.heart.state = "WALKING"
                self.heart:setSprite("player/heart_legs_smol")
                self.heart.y = self.heart.on.y
                Input.clear("up", true)
            end
            if self.heart.on.type == "middle" and (self.heart.y > self.heart.on.y - 2 and self.heart.y < self.heart.on.y + 2) then
                self.heart.state = "WALKING"
                self.heart:setSprite("player/heart_legs_smol")
                self.heart.y = self.heart.on.y
                Input.clear("up", true)
            end
        elseif Input.down("down") and not Input.down("up") then
            self.heart.y = self.heart.y + DTMULT*self.heart.speed
            if self.heart.on.type == "bottom" then
                self.heart.state = "WALKING"
                self.heart:setSprite("player/heart_legs_smol")
                self.heart.y = self.heart.on.y
                Input.clear("down", true)
            end
            if self.heart.down.type == "middle" and (self.heart.y > self.heart.down.y - 2 and self.heart.y < self.heart.down.y + 2) then
                self.heart.state = "WALKING"
                self.heart:setSprite("player/heart_legs_smol")
                self.heart.y = self.heart.down.y
                Input.clear("down", true)
            end
        end
    end

    -- If you aren't pressing any direction inputs, stop animating the SOUL
    if not (Input.down("right") or Input.down("left") or Input.down("up") or Input.down("down")) then
        self.heart:stop()
    end
end

-- Gets the tiles to the left, right, up, and down of the one the object is on, and sets the corresponding variables of the object
function BurgerTimeGame:getNextTiles(o)
    if o.on then
        o.left = self.tile_map[o.on.row][o.on.column - 1]
        o.right = self.tile_map[o.on.row][o.on.column + 1]
        o.up = self.tile_map[o.on.row - 1][o.on.column]
        o.down = self.tile_map[o.on.row + 1][o.on.column]
    end
end

-- Returns the tile that an object is on
function BurgerTimeGame:getTile(o)
    local column = math.floor((o.x - Game.battle.arena.left) / self.tile_width) + 1
    local row = math.floor(((o.y + 1) - Game.battle.arena.top) / self.tile_height) + 1
    local row_data = self.tile_map[row]
    local tile = row_data and row_data[column]
    if tile and tile.type ~= "none" then
        o.on = tile
        return
    end
    o.on = self.tile_map[2][2] -- An empty tile
end

function BurgerTimeGame:hit()
    -- Start invulnerablility
    self.invincible = true

    if self.lives > 0 then
        -- Shake hearts
        for _, l in ipairs(self.life_meter) do
            l:slideTo(l.x - 1, l.y + 1, 1/30, "linear", function ()
                l:slideTo(l.x + 1, l.y - 1, 1/30, "linear")        
            end)
        end

        self.life_meter[self.lives]:fadeOutAndRemove(0.01)
        table.remove(self.life_meter,self.lives)
        self.lives = self.lives - 1

        if self.lives > 0 then 
            Assets.playSound("hurt", 0.6)
        else
            Assets.playSound("break2", 0.7)
        end

    end

    -- Start flash timer
    self.useTimer = self.iFrames
    
    -- End invulnerability
    self.timer:after(self.iFrames, function ()
        self.invincible = false
    end)
end

function BurgerTimeGame:onEnd()
    if self.lives == 3 then
        Game:setFlag("Results", "perfect_stack")
    elseif self.lives == 2 then
        Game:setFlag("Results", "good_stack")
    elseif self.lives == 1 then
        Game:setFlag("Results", "okay_stack")
    else
        Game:setFlag("Results", "bad_stack")
    end
end

--[[ function BurgerTimeGame:draw()
    if self.heart then
        self.heart.collider:drawFor(self,0,1,0,1)
    end

    if self.enemy_1 then
        self.enemy_1.collider:drawFor(self,0,1,0,1)
    end

    if #self.burger_parts > 0 then
        for _, v in ipairs(self.burger_parts) do
            v.collider:drawFor(self,0,1,0,1)
            --for _, w in ipairs(v.sprite_segments) do
            --    w.collider:drawFor(self,0,1,0,1)
            --end
        end
    end
end ]]

return BurgerTimeGame