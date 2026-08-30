--Code written by Mose & Sharks & Holton!

local TorielCatch, super = Class("LightMinigameWave")

function TorielCatch:init()
    super.init(self, _s("minigame_popup-torielcatchgame", "Catch!"), "horiz_layout_alt")

    self.time = -1
    self:setArenaSize(450,300)
    self:setArenaPosition(SCREEN_WIDTH/2, SCREEN_HEIGHT/2 + 30)

    self.ingrs = {} -- A table of all the currently tossed ingredients that haven't been put into the bowl yet

    self.score = 0 -- Number of ingredients caught
    self.maxScore = 9 -- Max score to win
    self.scoring = false -- ensure scoring doesn't happen 1 billion times
end

function TorielCatch:onStart()
    self.centerX = (Game.battle.arena.left + Game.battle.arena.right) / 2
    self.centerY = (Game.battle.arena.top + Game.battle.arena.bottom) / 2

    -- Create bowl
    self.bowl = self:spawnObject(Sprite("objects/piecatchgame/bowl"), self.centerX, Game.battle.arena.bottom - 55)
    self.bowl:setScale(4)
    self.bowl:setOrigin(0.5)
    self.bowl:setLayer(BATTLE_LAYERS["above_bullets"])
    self.bowl.collider = Hitbox(self.bowl, 0.5 * self.bowl.height, 0.2 * self.bowl.width, self.bowl.width * 0.3, self.bowl.height * 0.05)

    self.bowl.speed = 10

    -- Create counter
    self.counter = self:spawnObject(Text("[font:bignumbers]"..self.score.."/"..self.maxScore), Game.battle.arena.right - 80, Game.battle.arena.top + 20, 100, 100)

    -- Show controls
    self.controls = self:spawnObject(ControlsDisplay(self.centerX, Game.battle.arena.top + 50, "horiz_layout_alt"))
    self.controls:setOrigin(0.5)
    self.controls:setScale(2)
    self.timer:after(2, function ()
        self.controls:fadeOutAndRemove(0.01)
    end)

    self.timer:everyInstant(1.3, function ()
        local x = math.random(1, 3)
        if x==1 then
            self:tossLeft()
        elseif x==2 then
            self:tossRight()
        elseif x==3 then
            self:tossTop()
        end
    end)
end

function TorielCatch:update()
    super.update(self)

    self:moveBowl()

    for i,v in ipairs(self.ingrs) do -- Loop through all the tossed ingredients every frame,

        --If an ingredient collides with the bowl, remove it from the table, battle, shake the bowl, increment the score, update the counter, and play a sound
        if v.collider:collidesWith(self.bowl.collider) and not self.scoring then -- If collides
            v.released = true -- Release the ingredient (This makes Toriel stop holding it)
            table.remove(self.ingrs,i) --Remove it from the table
            v:remove() --Remove it from the battle
            self:shakeBowl() --Shake bowl
            self.score = self.score + 1 -- Increment score
            self.counter:setText("[font:bignumbers]"..self.score.."/"..self.maxScore) -- Update the counter
            Assets.playSound("item") --Play sound

            if self.score >= self.maxScore then -- When %100 progress is reached, play "perfect" effect and end the game
                self.scoring = true
                self:win()
            end
        end

        --If an ingredient is in bounds, make toriel catch it
        if v.y > self.bowl.y and not self.scoring then -- IF in bounds
            if v.catchable == false then --Check if the current ingredient isn't catchable currently (this makes sure toriel doesn't grab the same ing twice)
                v.catchable = true --Make it catchable!
                self:toriCatch(v) --Catch it
            end
        end
    end
end

function TorielCatch:moveBowl()

    if Input.down("left") and self.bowl.x >= (Game.battle.arena.left + 10 + self.bowl.width/2 * self.bowl.scale_x) then
        self.bowl:setSpeed(-self.bowl.speed,0)
    elseif Input.down("right") and self.bowl.x <= (Game.battle.arena.right - 10 - self.bowl.width/2 * self.bowl.scale_x) then
        self.bowl:setSpeed(self.bowl.speed,0)
    else
        self.bowl:setSpeed(0,0)
    end

end

function TorielCatch:tossLeft()
    self.flour = self:spawnObject(Sprite("objects/piecatchgame/flour"), -60, 320)
    self.flour:setScale(2)
    self.flour:setOrigin(0.5)
    self.flour:setLayer(BATTLE_LAYERS["bullets"])
    self.flour.collider = Hitbox(self.flour, 0, 0, self.flour.width, self.flour.height)
    self.flour.physics.gravity = 9.8/30
    self.flour.physics.match_rotation = true -- Needed to set spin
    self.flour.physics.spin = 0.02 + (love.math.random() * 0.2) -- Make it spin a random amount between 0.02 and 0.22 radians per frame
    self.flour.catchable = false --Not catchable by default, only when in bounds does this become true
    self.flour.caught = false --Checks if the ingredient has been caught by toriel yet
    self.flour.released = false --Checks if toriel has released the ingredient yet

    table.insert(self.ingrs,self.flour) --Insert the ingredient into the self.ingrs table upon initialization

    self.flour.x = -60
    self.flour.y = 320

    local t = 2.5
    local d = love.math.random(Game.battle.arena.left + 50, self.centerX + 50)
    local x = self.flour.x
    local vx = (d-x)/t

    -- My sinister formulas (SUCKS ASS):
    --local y = 3000/(d - x - 100)
    --local y = 16
    --local vy = (y / (t/2)) - (0.5 * (9.8/30) * (t/2))

    self.flour:setSpeed(vx/30, -12.5)

end

function TorielCatch:tossRight()
    self.egg = self:spawnObject(Sprite("objects/piecatchgame/egg"), 700, 320)
    self.egg:setScale(4)
    self.egg:setOrigin(0.5)
    self.egg:setLayer(BATTLE_LAYERS["bullets"])
    self.egg.collider = Hitbox(self.egg, 0, 0, self.egg.width, self.egg.height)
    self.egg.physics.gravity = 9.8/30
    self.egg.physics.match_rotation = true -- Needed to set spin
    self.egg.physics.spin = -0.02 - (love.math.random() * 0.2) -- Make it spin a random amount between -0.02 and -0.22 radians per frame
    self.egg.catchable = false --Not catchable by default, only when in bounds does this become true
    self.egg.caught = false --Checks if the ingredient has been caught by toriel yet
    self.egg.released = false --Checks if toriel has released the ingredient yet

    table.insert(self.ingrs,1,self.egg) --Insert the ingredient into the self.ingrs table upon initialization

    self.egg.x = 700
    self.egg.y = 320

    local t = 2.5
    local d = math.random(self.centerX - 75, Game.battle.arena.right - 75)
    local x = self.egg.x
    local vx = (d-x)/t

    self.egg:setSpeed(vx/30, -12.5)
end

function TorielCatch:tossTop()
    self.milk = self:spawnObject(Sprite("objects/piecatchgame/milk"), self.centerX, -10)
    self.milk:setScale(3)
    self.milk:setOrigin(0.5)
    self.milk:setLayer(BATTLE_LAYERS["bullets"])
    self.milk.collider = Hitbox(self.milk, 0, 0, self.milk.width, self.milk.height)
    self.milk.catchable = false -- I reverted this [Catchable by default, this is for an admittedly cheeky hack in a bit]
    self.milk.physics.match_rotation = true -- Needed to set spin
    self.milk.physics.spin = -0.1 + (love.math.random() * 0.2) -- Make it spin a random amount between -0.1 and 0.1 radians per frame

    table.insert(self.ingrs,self.milk) --Insert the ingredient into the self.ingrs table upon initialization

    self.milk.x = math.random(Game.battle.arena.left + 50, Game.battle.arena.right - 50)
    self.milk.y = -10

    --[[Thank you Sharks but I'm changing how this works because whole cartons of milk falling from the sky is objectively funnier]]
    --[[This is a bit of a cheeky way to do this, but by far the least complicated,
    basically for the TOP milk drops, we set catchable to true BUT don't spawn it in bounds so toriel doesn't try and catch it immediately,
    then we wait 2.5 seconds and start setting the gravity, then wait another 0.20 seconds and THEN set catchable to false,
    that way when it's in bounds again, it becomes catchable again and therefore toriel grabs it properly]]
    --Game.stage.timer:after(2.5, function ()
    --    self.milk.physics.gravity = 9.8/30
    --    Game.battle.timer:after(0.2, function()
    --        self.milk.catchable = false
    --    end)
    --end)

    self.milk.physics.gravity = (9.8 * DT)

end


function TorielCatch:toriCatch(ing)
    local x = -40
    if ing.x > self.centerX then
        x = SCREEN_WIDTH + 40
    end
    local hand = self:spawnObject(Sprite("objects/piecatchgame/hand_right_open"), x, Game.battle.arena.bottom)
    hand:setScale(2)
    hand:setOrigin(0.5)
    hand:setLayer(BATTLE_LAYERS["top"])
    hand.alpha = 0

    self.timer:every(1/30, function ()
        if not ing.caught then
            hand.alpha = Utils.approach(hand.alpha, 1, 0.15)
            hand.x = Utils.approach(hand.x, ing.x, 30)
            hand.y = Utils.approach(hand.y, ing.y, 30)

            if hand.x == ing.x and hand.y == ing.y then
                ing.caught = true
                ing:setSpeed(0)
                ing.physics.spin = 0
                hand:setSprite("objects/piecatchgame/hand_right")
            end
        elseif not ing.released then
            ing.x = hand.x
            ing.y = hand.y
            hand.x = Utils.approach(hand.x, self.bowl.x, 15 - 5)
            hand.y = Utils.approach(hand.y, self.bowl.y - 30, 15 - 5)
        else
            hand:setSprite("objects/piecatchgame/hand_right_open")
            self.timer:tween(10*DT, hand, {y = Game.battle.arena.top})
            self.timer:tween(10*DT, hand, {alpha = 0}, "linear", function()
                hand:remove()
            -- fixed! -Holton
            end)
            return false
        end
    end)
end

function TorielCatch:shakeBowl()
    self.bowl:slideTo(self.bowl.x, self.bowl.y + 10, 2/30, "linear", function ()
        self.bowl:slideTo(self.bowl.x, Game.battle.arena.bottom - 55, 2/30, "linear")
    end)
end

-- When %100 progress is reached, play "perfect" effect and end the game
function TorielCatch:win()
    self:scoreMessage("Perfect", self.bowl.x, self.bowl.y)
    Assets.playSound("snd_perfect", 0.6, 1.2)

    self.timer:after(1, function () -- End the wave
        self.finished = true
    end)
end

function TorielCatch:onEnd()
    -- add whatever if necessary
    --flag for toriel custcenes that indicate the first step is done
    Game:setFlag("TorielSteps", 1)
end

--[[ function TorielCatch:draw()
    if self.bowl then
        self.bowl.collider:drawFor(self, 0, 1, 0, 1)
    end
    if self.flour then
        self.flour.collider:drawFor(self, 0, 1, 0, 1)
    end
    if self.egg then
        self.egg.collider:drawFor(self, 0, 1, 0, 1)
    end
    if self.milk then
        self.milk.collider:drawFor(self, 0, 1, 0, 1)
    end
end ]]

return TorielCatch
