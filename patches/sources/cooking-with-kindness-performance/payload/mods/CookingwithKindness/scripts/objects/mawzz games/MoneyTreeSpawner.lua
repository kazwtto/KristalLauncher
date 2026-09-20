--Code by Sharks!

local MoneyTreeSpawner, super = Class(Object, "MoneyTreeSpawner")

function MoneyTreeSpawner:init(x,y,w,h)
    super.init(self,x,y,200,230)

    self.time = 0
    self.spawning_speed = 0.7

    self.item_drop_speed = 5
    self.coins_collected = 0

    --Table of all the potential items that can spawn
    self.potential_items = {
        {
            type = "TAXES", --Kills you when touched
            sprite = "objects/mawzz_games/moneytree/taxes",
            spawn_rate = 50, --% chance to spawn
            speed = 2, --How fast they fall
        },
        {
            type = "BILL", --Gives more money. Rarer
            sprite = "objects/mawzz_games/moneytree/bill",
            spawn_rate = 10, --% chance to spawn
            speed = 3, --How fast they fall
        },
        {
            type = "COIN", --Gives you G (and increases the mawzz boss timer iirc?)
            sprite = "objects/mawzz_games/surfinggame/coin",
            spawn_rate = 30, --% chance to spawn
            speed = 2, --How fast they fall
        }
    }

    self.current_items = {} --Table of the current spawned items that have yet to be collected or despawned
end

function MoneyTreeSpawner:update()
    super.update(self)

    self.time = self.time + love.math.random(1,3) --Randomize the spawn time a little (idk just makes it more interesting i guess)
    --self.time = self.time + 1

    --Spawn an item after a certain elapsed time
    if self.time/30 >= self.spawning_speed then
        self.time = 0
        local x = love.math.random(1,3)

        local item_spawnrates = self:getItemSpawnRates()
        self:spawnAnItem(item_spawnrates)
    end

    --If past the battle box barrier, despawn and release the reference.
    local item_write = 1
    for item_read = 1, #self.current_items do
        local v = self.current_items[item_read]
        if not v.parent or v.y > 250 then
            if v.parent then v:remove() end
        else
            self.current_items[item_write] = v
            item_write = item_write + 1
        end
    end
    for i = #self.current_items, item_write, -1 do
        self.current_items[i] = nil
    end
end

--Attempt to spawn an item, if it tries to spawn an item too close to the previously spawned item, reroll and find another position
function MoneyTreeSpawner:spawnAnItem(index)

    local rand_x --Randomized x position
    local max_attempts = 10 --How many attempts it will reroll to find another position.
    local attempts = 0

    --Randomize the x position, but if it's too close to the most recently spawned, reroll
    --If it fails to find a viable position 10 times, just spawn it anyway
    repeat
        rand_x = love.math.random(0,173)
        attempts = attempts + 1

        local last_item = self.current_items[#self.current_items]

        if not last_item then
            break
        end

    until math.abs(rand_x - last_item.x) > 10 --or attempts >= max_attempts


    --Spawn the chosen item
    local item = Sprite(self.potential_items[index].sprite, rand_x, 0)

    if self.potential_items[index].type == "TAXES" then
        item.collider = Hitbox(item,item.width/2-7,item.height/2-5,15,10)
    elseif self.potential_items[index].type == "COIN" then
        item.collider = CircleCollider(item,6.5,6.5,6)
    elseif self.potential_items[index].type == "BILL" then
        item.collider = Hitbox(item,0,0,item.width,item.height)
    end

    item.type = self.potential_items[index].type
    item.physics.speed_y = self.item_drop_speed+self.potential_items[index].speed
    item:setScale(2)
    item:play(0.2)
    self:addChild(item)
    table.insert(self.current_items, item)
end

--Uses the item spawn rate to choose an item
function MoneyTreeSpawner:getItemSpawnRates()
    local total_spawnrate = 0

    for _,item in ipairs(self.potential_items) do
        total_spawnrate = total_spawnrate + item.spawn_rate
    end

    local roll = love.math.random(0,total_spawnrate)
    local current = 0

    for i,item in ipairs(self.potential_items) do
        current = current+item.spawn_rate
        if roll <= current then
            return i
        end
    end
end

function MoneyTreeSpawner:draw()
    super.draw(self)

    --[[for i,v in ipairs(self.current_items) do
        v.collider:drawFor(self, 0,1,0,1)
    end]]
end

return MoneyTreeSpawner