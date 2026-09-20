-- Code by Mose

-- I wrote this while I was sick so it quickly devoled into a disorganized mess. Terribly sorry.

local TrickOrTreatGame, super = Class("LightMinigameWave")

function TrickOrTreatGame:init()
    super.init(self, _s("minigame_popup-trickortreatgame", "GET THE MOST CANDY!"), "full_layout")

    self.time = -1

    Game:setFlag("Results", "none")

    self:setArenaSize(400, 400)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 10)

    self.houses = {{x=8, y=90}, {x=195, y=81}, {x=680, y=116}, {x=810, y=106}, {x=1107, y=131}, {x=207, y=225}, {x=345, y=192}, {x=98, y=324}, {x=346, y=370}, {x=970, y=442},
                   {x=1198, y=329}, {x=48, y=674}, {x=318, y=783}, {x=510, y=645}, {x=830, y=606}, {x=1194, y=723}, {x=1503, y=675}, {x=436, y=1096}, {x=729, y=912},
                   {x=918, y=960}, {x=1338, y=972}, {x=72, y=1222}, {x=184, y=1362}, {x=380, y=1318}, {x=843, y=1179}}
    self.mansions = {{x=674, y=437}, {x=130, y=994}, {x=904, y=1382}, {x=1224, y=1263}, {x=1413, y=1356}}
    self.ghosts = {{x=1080, y=0}, {x=540, y=178}, {x=1080, y=356}, {x=540, y=534}, {x=1080, y=712}, {x=540, y=890}, {x=1080, y=1068}, {x=540, y=1246}}

    self.can_move = true
    self.transitioning = false
    self.in_well = false
    self.has_picked_up_bat = false

    self.candy = 0
    self.houses_looted = 0
    self.houses_max = 10

    self.siner = 0
end

function TrickOrTreatGame:onStart()
    -- Make soul
    self.heart = self:spawnObject(Sprite("player/heart"), self.arena_x, self.arena_y)
    self.heart:setOrigin(0.5)
    self.heart:setLayer(BATTLE_LAYERS["soul"])
    self.heart.speed = 5
    self.heart.i_frames = 30/30
    self.heart.vulnerable = true
    self.heart.collider = Hitbox(self.heart, 0, 0, self.heart.width, self.heart.height)
    self.heart:setSprite("player/heart_bag")

    self.x_pos_list = {self.heart.x, self.heart.x, self.heart.x}
    self.y_pos_list = {self.heart.y, self.heart.y, self.heart.y}

    -- Make bag
    --[[ self.bag = self:spawnObject(Sprite("objects/trickortreatgame/bag"), self.heart.x, self.heart.y - 10)
    self.bag:setOrigin(1,0.5)
    self.bag.rotation = math.rad(-90) ]]

    -- Make background
    self.map = self:spawnObjectTo(Game.battle.arena.mask, Sprite("objects/trickortreatgame/background"), -498, -510)
    self.map:setLayer(BATTLE_LAYERS["arena"])

    -- Make houses
    for i, h in ipairs(self.houses) do
        local house = self.map:addChild(Sprite("objects/trickortreatgame/house_"..math.random(1,3), h.x, h.y + 1))
        house:setOrigin(0,1)
        house:setLayer(BATTLE_LAYERS["above_arena"])

        house.door_collider = Hitbox(house, 57, 59, 19, 25) -- Determined by pixel measurements

        house.looted = false -- Whether the player has been to this house or not

        table.remove(self.houses, i)
        table.insert(self.houses, i, house)
    end

    -- Make mansions
    for i, m in ipairs(self.mansions) do
        local mansion = self.map:addChild(Sprite("objects/trickortreatgame/mansion", m.x, m.y + 1))
        mansion:setOrigin(0,1)
        mansion:setLayer(BATTLE_LAYERS["above_arena"])

        mansion.door_collider = Hitbox(mansion, 69, 81, 29, 29) -- Determined by pixel measurements

        mansion.looted = false -- Whether the player has been to this house or not

        table.remove(self.mansions, i)
        table.insert(self.mansions, i, mansion)
    end

    -- Make ghosts
    for i, g in ipairs(self.ghosts) do
        local ghost = self.map:addChild(Sprite("objects/trickortreatgame/ghosts/ghost_"..TableUtils.pick{"a","b","c","d"}, g.x, g.y))
        if Game:getFlag("pumpkid_type") == "dog" then ghost:setSprite("objects/trickortreatgame/ghosts/ghost_dog") end
        ghost:setLayer(BATTLE_LAYERS["above_soul"])
        ghost:play(0.5, true)

        if g.x == 540 then
            ghost.dir = 1
        else
            ghost.dir = -1
            ghost.flip_x = true
        end

        ghost.speed = 6

        ghost.collider = Hitbox(ghost, 0, 0, ghost.width, ghost.height)

        table.remove(self.ghosts, i)
        table.insert(self.ghosts, i, ghost)
    end

    -- Make Living Tombstone
    self.living_tombstone = self.map:addChild(Sprite("objects/trickortreatgame/tombstone/rise", 126, 442))
    self.living_tombstone:setLayer(BATTLE_LAYERS["above_arena"])
    self.living_tombstone.has_started = false
    self.living_tombstone.collider = Hitbox(self.living_tombstone, 0, -self.living_tombstone.height * 2, self.living_tombstone.width * 10, self.living_tombstone.height * 5)

    -- Make ominous well collider
    self.ominous_well = Hitbox(self.map, 1589, 2, 23, 18)

    -- Make house counter
    local h_icon = self:spawnObject(Sprite("objects/trickortreatgame/house_icon"), Game.battle.arena:getLeft() + 4, Game.battle.arena:getTop() + 4)
    self.house_counter = self:spawnObject(Text("[font:main, 32][style:menu]: "..self.houses_looted.." / "..self.houses_max), h_icon.x + h_icon.width + 4, h_icon.y - 2)

    -- Make candy counter
    self.candy_display = 0
    local c_icon = self:spawnObject(Sprite("objects/trickortreatgame/candy_icon"), h_icon.x, h_icon.y + h_icon.height)
    self.candy_counter = self:spawnObject(Text("[font:main, 32][style:menu]: "..self.candy_display), c_icon.x + c_icon.width + 4, c_icon.y - 2)

end

function TrickOrTreatGame:update()
    super.update(self)

    self.siner = self.siner + (DT * DTMULT)

    self.map.prev_x = self.map.x
    self.map.prev_y = self.map.y

    -- Rolling number effect for the candy display + updates candy counter
    if self.candy_display < self.candy then
        self.candy_display = self.candy_display + 1
        self.candy_counter:setText("[font:main, 32][style:menu]: "..self.candy_display)
    elseif self.candy_display > self.candy then
        self.candy_display = self.candy_display - 1
        self.candy_counter:setText("[font:main, 32][style:menu]: "..self.candy_display)
    end

    -- Heart i-frames
    if self.heart.vulnerable == false then
        self.heart.i_frames = self.heart.i_frames - (DT * DTMULT)
        if self.heart.i_frames <= 0 then
            self.heart.vulnerable = true
            self.heart.i_frames = 30/30
        end
    end

    if not self.in_well then
        if self.can_move then
            self:move()
        end

        --self:moveBag()
        self:moveGhosts()
        self:wrapMap()

        local bag_stage
        if self.candy_display == 10 then
            bag_stage = 2
        elseif self.candy_display == 25 then
            bag_stage = 3
        elseif self.candy_display == 50 then
            bag_stage = 4
        end
        if bag_stage then
            local bag_sprite = "player/heart_bag_"..bag_stage
            if not self.heart:isSprite(bag_sprite) then
                self.heart:setSprite(bag_sprite)
            end
        end

        self:checkHeartCollision()

    else
        if self.can_move then
            self:moveWell()
        end

        if not self.has_picked_up_bat and self.heart.collider:collidesWith(self.bat.collider) then
            Assets.playSound("item", 0.7)
            self.bat:setParent(self.heart)
            self.bat.x = self.heart.width/2
            self.bat.y = self.heart.height/2
            self.bat.rotation = ((2 * math.pi)/3)
            self.has_picked_up_bat = true
        end

        if self.has_picked_up_bat then
            if Input.pressed("confirm", false) and not self.bat.swinging then
                self:swing()
            end
        end

        if self.bat.swinging == true and self.pinata.vulnerable == true then
            if self.bat.collider:collidesWith(self.pinata.collider) then
                self:hit()
            end
        end
    end
end

function TrickOrTreatGame:checkHeartCollision()
    Object.startCache()

    for _, h in ipairs(self.houses) do
        if not h.looted then
            if self.heart.collider:collidesWith(h.door_collider) then
                self:loot("house", h)
            end
        end
    end

    for _, m in ipairs(self.mansions) do
        if not m.looted then
            if self.heart.collider:collidesWith(m.door_collider) then
                self:loot("mansion", m)
            end
        end
    end

    for _, g in ipairs(self.ghosts) do
        if self.heart.vulnerable == true then
            if self.heart.collider:collidesWith(g.collider) then
                self:looseCandy()
            end
        end
    end

    if self.heart.collider:collidesWith(self.living_tombstone.collider) and not self.living_tombstone.has_started then
        self.living_tombstone.has_started = true
        self.living_tombstone:shake()
        self.living_tombstone:play(0.2, false, function ()
            self.living_tombstone:setSprite("objects/trickortreatgame/tombstone/run")
            self.living_tombstone:play(0.1, true)
            
            self.living_tombstone:slideTo(self.living_tombstone.x - 1000, self.living_tombstone.y, 4, "linear", function ()
                self.living_tombstone:remove()
            end)
        end)
    end

    if self.heart.collider:collidesWith(self.ominous_well) and not self.transitioning then
        self:enterWell()
    end

    Object.endCache()
end

function TrickOrTreatGame:looseCandy()
    self.heart.vulnerable = false
    self.heart:shake()

    self.candy = self.candy - 5 < 0 and 0 or self.candy - 5 -- Removes 5 from the candy, unless it would be less than zero, then set candy to 0

    Assets.playSound("hurt", 0.5)
    local text_1 = self:spawnObjectTo(self.heart, Text("[font:main, 16][color:red]-5 Stolen!"), self.heart.width + 5, 0, 10, 10)
    text_1:slideTo(text_1.x, text_1.y + 20, 0.5, "out-quad", function ()
        text_1:fadeOutAndRemove(0.5)
    end)
end

function TrickOrTreatGame:loot(type, place)
    place.looted = true
    place:setSprite(place.texture_path.."_open")
    
    self.houses_looted = self.houses_looted + 1 -- Increment the number of houses the player has been to
    self.house_counter:setText("[font:main, 32][style:menu]: "..self.houses_looted.." / "..self.houses_max) -- Update the house counter

    local add = 0
    local reaction = ""
    if type == "house" then
        add = 1
        Assets.playSound("egg", 0.5, 1.1)
    elseif type == "mansion" then
        add = 5
        Assets.playSound("egg", 0.7, 1.4)
    end

    self.candy = self.candy + add

    -- Make "+1" text and slide it upwards
    local text_1 = self:spawnObjectTo(self.heart, Text("[font:main, 16][color:yellow]+"..add), self.heart.width + 5, 0, 10, 10)
    text_1:slideTo(text_1.x, text_1.y - 20, 0.5, "out-quad", function ()
        text_1:fadeOutAndRemove(0.5)
    end)

    -- If you matched up the face in the pumpkin carving game, then add another candy on and do another score popup
    if Game:getFlag("pumpkid_matches", true) then
        self.candy = self.candy + add

        self.timer:after(0.1, function ()
            --Assets.playSound("egg", 0.5, 1.1)
            local text_2 = self:spawnObjectTo(self.heart, Text("[font:main, 16][color:yellow]+"..add.." Bonus!"), self.heart.width + 5, 12, 10, 10)
            text_2:slideTo(text_2.x, text_2.y - 20, 0.5, "out-quad", function ()
                text_2:fadeOutAndRemove(0.5)
            end)
        end)

        -- Pick text depending on which 
        if Game:getFlag("pumpkid_type") == "scary" then
            reaction = TableUtils.pick({"* Ooh so scary!", "* Woah you scared me!", "* [shake:1]AAAAAAAH!!!"})

        elseif Game:getFlag("pumpkid_type") == "cute" then
            reaction = TableUtils.pick({"* OMG so cute!", "* [wave:1]Awwwwww!", "* Adorable!!!"})

        elseif Game:getFlag("pumpkid_type") == "dog" then
            reaction = TableUtils.pick({"* [wave:1]Bark", "* [wave:1]Woof", "* [wave:1]Arf", "* [wave:1]Meow", "* Don't call me radiation"})
        end

        -- Spawn the text object below the house
        local reaction_text = self:spawnObjectTo(place, DialogueText("[font:main, 16]"..reaction), 0, place.height)
        self.timer:after(2, function ()
            reaction_text:fadeOutAndRemove(0.5)
        end)
    end

    -- If the player has looted the max number of houses, end the game
    if self.houses_looted == self.houses_max then
        self:win()
    end
end

function TrickOrTreatGame:move()
    if Input.down("up") then
        self.map.y = self.map.y + self.heart.speed * DTMULT
    end
    if Input.down("down") then
        self.map.y = self.map.y - self.heart.speed * DTMULT
    end
    if Input.down("left") then
        self.map.x = self.map.x + self.heart.speed * DTMULT
    end
    if Input.down("right") then
        self.map.x = self.map.x - self.heart.speed * DTMULT
    end
end

--[[ function TrickOrTreatGame:moveBag()
    -- Sets the bag's x value to whatever the soul was at 3 frames ago
    self.bag.x = self.x_pos_list[1]
    table.remove(self.x_pos_list, 1)
    self.x_pos_list[3] = self.heart.x + (self.map.x - self.map.prev_x)

    -- Sets the bag's y value to whatever the soul was at 3 frames ago
    self.bag.y = self.y_pos_list[1]
    table.remove(self.y_pos_list, 1)
    self.y_pos_list[3] = (self.heart.y + 10) + (self.map.y - self.map.prev_y)
end ]]

function TrickOrTreatGame:moveGhosts()
    for _, g in ipairs(self.ghosts) do
        g.x = g.x + (g.speed * g.dir)
        g.y = g.y + (2 * math.sin(2 * self.siner))

        if g.dir == 1 and g.x > self.map.width then
            g.x = self.map.x
        elseif g.dir == -1 and g.x < self.map.x then
            g.x = self.map.width
        end
    end
end

function TrickOrTreatGame:win()
    self.can_move = false

    local msg = "blank" -- What message to dislpay
    local snd = "error" -- What sound effect to play

    -- All the different self.scores
    if self.candy >= 50 then
        msg = "Perfect"
        snd = "snd_perfect" -- 55 and above
    elseif self.candy >= 35 then
        msg = "Great"
        snd = "snd_great" -- Between 45 and 60
    elseif self.candy >= 20 then
        msg = "Okay"
        snd = "snd_good" -- Between 25 and 50
    elseif self.candy > 10 then
        msg = "Okay"
        snd = "snd_good" -- Between 10 and 25
    else
        if Utils.random() > 0.25 then
            msg = "Bad"
        else
            msg = ":("
        end
        snd = "error" -- Less than or equal to 10
    end

    self:scoreMessage(msg)
    Assets.playSound(snd, 0.6, 1.2)

    self.timer:after(1, function ()
        self.finished = true
    end)
end

-- The 120 and 50 adjust for the map's coordinates not being the same as its screen coordinates
function TrickOrTreatGame:wrapMap()
    if self.heart.x - self.map.x > (self.map.width + 120) + 180 then
        self.map.x = (self.heart.x - 120) + 180
    elseif (self.heart.x - 120) + 180 < self.map.x then
        self.map.x = self.heart.x - (self.map.width + 120) - 180
    end

    if self.heart.y - self.map.y > (self.map.height + 50) + 180 then
        self.map.y = (self.heart.y - 50) + 180
    elseif (self.heart.y - 50) + 180 < self.map.y then
        self.map.y = self.heart.y - (self.map.height + 50) - 180
    end
end

-- v WELL MODE v --

function TrickOrTreatGame:enterWell()
    self.can_move = false
    self.transitioning = true

    self.heart.visible = false
    --self.bag:remove()

    Assets.playSound("pkmn_exit", 0.5)

    local transition = self:spawnObjectTo(Game.battle.arena.mask, Sprite("objects/trickortreatgame/transition/in"), -Game.battle.arena:getLeft(), -Game.battle.arena:getTop())
    transition:setScale(4)
    transition:setLayer(BATTLE_LAYERS["top"])

    transition:play(0.1, false, function ()
        self.map:remove()
        self.well_map = self:spawnObjectTo(Game.battle.arena.mask, Sprite("objects/trickortreatgame/background_well"), 0, 0)
        self.well_map:setLayer(BATTLE_LAYERS["arena"])
        self.well_map:setScale(4)
        self.heart.x = self.arena_x
        self.heart.y = 365
    end)

    self.timer:after(1, function ()
        self.heart:setSprite("player/heart")

        transition:setLayer(BATTLE_LAYERS["top"])
        transition:setScale(-4, 4)
        transition.x = Game.battle.arena:getRight()

        transition:setAnimation({"objects/trickortreatgame/transition/in", 0.1, false, frames={8,7,6,5,4,3,2,1}, callback=function ()
            transition:remove()

            self.heart.visible = true

            self.bat = self:spawnObject(Sprite("objects/trickortreatgame/bat_1"), self.arena_x, self.heart.y - 25)
            self.bat:setOrigin(0.5, 1)
            self.bat:setLayer(BATTLE_LAYERS["above_arena"])
            self.bat.sign = -1
            self.bat.swinging = false
            self.bat.collider = Hitbox(self.bat, 0, 0, self.bat.width, 28)

            self.pinata = self:spawnObject(Sprite("objects/trickortreatgame/toby"), self.arena_x, self.arena_y)
            self.pinata:setOrigin(0.5, 1)
            self.pinata:setScale(0.5)
            self.pinata:setLayer(BATTLE_LAYERS["above_arena"])
            self.pinata.health = 16
            self.pinata.vulnerable = true
            self.pinata.collider = Hitbox(self.pinata, 0, 0, 236, 325)

            self.can_move = true
            self.in_well = true
        end})
    end)
end

function TrickOrTreatGame:hit()
    self.pinata.vulnerable = false
    self.pinata:shake()
    Assets.playSound("damage", 0.5)
    self.pinata.health = self.pinata.health - 1

    self.heart:slideTo(self.heart.x, self.heart.y + 10, 0.2, "out-quad")

    if self.pinata.health <= 0 then
        self:wellWin()
        return
    end

    self.timer:after(0.2, function ()
        self.pinata.vulnerable = true
    end)
end

function TrickOrTreatGame:moveWell()
    if Input.down("up") and self.heart.y > Game.battle.arena:getTop() + 30 then
        self.heart.y = self.heart.y - self.heart.speed * DTMULT
    end
    if Input.down("down") and self.heart.y < Game.battle.arena:getBottom() - 30 then
        self.heart.y = self.heart.y + self.heart.speed * DTMULT
    end
    if Input.down("left") and self.heart.x > Game.battle.arena:getLeft() + 30 then
        self.heart.x = self.heart.x - self.heart.speed * DTMULT
    end
    if Input.down("right") and self.heart.x < Game.battle.arena:getRight() - 30 then
        self.heart.x = self.heart.x + self.heart.speed * DTMULT
    end
end

function TrickOrTreatGame:swing()
    Assets.playSound("ui_cancel", 0.5)
    self.heart:slideTo(self.heart.x + 4 * self.bat.sign, self.heart.y, 0.1, "in-quad")
    self.bat.swinging = true
    self.bat.rotation = 0
    self.bat:setSprite("objects/trickortreatgame/bat_2")
    self.bat.collider = Hitbox(self.bat, 0, 0, self.bat.width, 28)

    self.timer:after(0.1, function ()
        self.bat.rotation = ((2 * math.pi)/3) * self.bat.sign
        self.bat.sign = self.bat.sign * -1
        self.bat:setSprite("objects/trickortreatgame/bat_1")
        self.bat.collider = Hitbox(self.bat, 0, 0, self.bat.width, 28)

        --self.heart.x = self.heart.x + 2 * self.bat.sign
        self.timer:after(0.1, function ()
            self.bat.swinging = false
        end)
    end)
end

function TrickOrTreatGame:wellWin()
    self.pinata:explode()

    self.candy = self.candy + 500
    self.candy_display = self.candy_display + 250

    Assets.playSound("snd_won", 0.8)
    local text_1 = self:spawnObjectTo(self.heart, Text("[font:main, 32][color:yellow][style:dark]+500 Bonus!"), self.heart.width + 5, 0, 10, 10)
    text_1:slideTo(text_1.x, text_1.y - 20, 0.5, "out-quad", function ()
        text_1:fadeOutAndRemove(0.5)
    end)

    self.timer:after(2, function ()
        self.finished = true
    end)
end

function TrickOrTreatGame:onEnd()
    if self.candy >= 50 then
        CustScore:addPoints(7) -- 60 and above
    elseif self.candy >= 35 then
        CustScore:addPoints(5) -- Between 50 and 60
    elseif self.candy >= 20 then
        CustScore:addPoints(4) -- Between 25 and 50
    elseif self.candy > 10 then
        CustScore:addPoints(2) -- Between 10 and 25
    else
        CustScore:addPoints(0) -- Less than or equal to 10
    end
end

function TrickOrTreatGame:draw()
    --[[ if self.bag and not self.transitioning then
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1,1,1)
        love.graphics.line(self.bag.x + 2, self.bag.y + 4, self.heart.x + 5, self.heart.y + 4)
        love.graphics.line(self.bag.x - 2, self.bag.y + 4, self.heart.x - 7, self.heart.y + 3)
    end ]]

    --[[ if self.ghosts then
        for _, g in ipairs(self.ghosts) do
            if g.collider then
                g.collider:drawFor(self,0,1,0,1)
            end
        end
    end ]]
end

return TrickOrTreatGame