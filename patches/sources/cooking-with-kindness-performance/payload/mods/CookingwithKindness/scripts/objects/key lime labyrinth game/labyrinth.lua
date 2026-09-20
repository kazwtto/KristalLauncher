local Labyrinth, super = Class(Sprite, "Labyrinth")

function Labyrinth:init(x, y, width, height, wave)
    local n = tostring(Utils.random(4,5,1))
    local locString = "objects/keylimelabyrinthgame/"..tostring(width).."x"..tostring(height).."/maze_circle_"..n
    super.init(self, locString, x, y)

    self:setOrigin(0, 0)
    self:setScale(2)
    
    self.w = width
    self.h = height
    
    self.wave = wave

    --local imageData = love.image.newImageData("mods/CookingwithKindness/assets/sprites/"..locString.."_locations.png")
    --local imageData = love.image.newImageData(Mod.info.path.."/assets/sprites/"..locString.."_locations.png")
    local imageData = Assets.getTextureData(locString.."_locations")
    self.board = {}
    self.SOULSpawnPoint = {self.w/2, self.h/2}
    self.keySpawnPoints = {}
    for y = 0, self.h-1 do
        self.board[y] = {}
        for x = 0, self.w-1 do
            local r,g,b,a = imageData:getPixel(x, y)
            self.board[y][x] = b
            
            if b == 0 and g == 1 then
                self.SOULSpawnPoint = {x, y}
                -- Kristal.Console:log("SOUL spawn point found! "..tostring(x).."  "..tostring(y))
            end
            if b == 0 and r == 1 then
                table.insert(self.keySpawnPoints, {x, y})
                -- Kristal.Console:log("Key spawn point found! "..tostring(x).."  "..tostring(y))
            end
        end
    end

    --Game.battle.soul.x = Game.battle.arena.left + 2*self.SOULSpawnPoint[1]
    --Game.battle.soul.y = Game.battle.arena.top  + 2*self.SOULSpawnPoint[2]
    --Game.battle.soul:transitionTo(Game.battle.arena.left + 2*self.SOULSpawnPoint[1], Game.battle.arena.top  + 2*self.SOULSpawnPoint[2])
    self.soulCollider = self:addChild(LabyrinthSOULCollider(-1000, -1000, self.SOULSpawnPoint[1], self.SOULSpawnPoint[2]))
    
    local keySpawnPoint = TableUtils.pick(self.keySpawnPoints) or {0,0}
    self.key = self:addChild(LabyrinthKey(keySpawnPoint[1], keySpawnPoint[2]))
    --self.key = self:addChild(Sprite("objects/keylimelabyrinthgame/key_temp", keySpawnPoint[1], keySpawnPoint[2]))
    --self.key:setOrigin(0.5, 0.5)

    self.collisionCount = 0


    self.soulSpeedFromCollision = 9
    self.collisionDamping = 75
    self.collisionSpeed = 0
    self.collisionNormal = {0,0}
    self.collisionNormalRotationRate = math.rad(2.5*30)
end



function Labyrinth:checkPerPixelCollision()
    local soul = self.soulCollider
    local xOffset = math.floor(soul.x - soul.rotOrigin[1])
    local yOffset = math.floor(soul.y - soul.rotOrigin[2])

    local x0 = soul.baseBounds[1]
    local x1 = soul.baseBounds[2]
    local y0 = soul.baseBounds[3]
    local y1 = soul.baseBounds[4]
    local xPrime = (x1 + x0) / 2
    local yPrime = (y1 + y0) / 2

    local board = self.board
    local mask = soul.maskMatrix
    local collided = false
    local cx = 0
    local cy = 0

    -- The old implementation allocated a 2-D collision matrix every frame and
    -- walked it a second time. Accumulate the exact same normal in the first pass.
    for y = y0, y1 do
        local board_row = board[y + yOffset]
        local mask_row = mask[y]
        if board_row and mask_row then
            for x = x0, x1 do
                if board_row[x + xOffset] == 1 and mask_row[x] == 1 then
                    collided = true
                    local vx, vy = Vector.normalize(xPrime - x, yPrime - y)
                    cx = cx + vx
                    cy = cy + vy
                end
            end
        end
    end

    return collided, cx, cy
end

function Labyrinth:update()
    
    if self.soulCollider.position_initialized then
        local collided, cx, cy = self:checkPerPixelCollision()
        if collided then
            self.soulCollider:takeDamage(1)
            self.collisionCount = self.collisionCount + 1
            self.collisionNormal[1], self.collisionNormal[2] = Vector.normalize(cx, cy)

            if DEBUG_RENDER then
                self.soulCollider.debugArrow.rotation = math.atan2(self.collisionNormal[2], self.collisionNormal[1])
            end

            self.collisionSpeed = self.soulSpeedFromCollision
        end
    end

    -- rotate collisionNormal toward input direction a little bit each frame:
    -- (see https://www.desmos.com/calculator/l3iidpqwnv )
    local input_x, input_y = 0, 0
    if Input.down("right") then
        input_x = 1
    elseif Input.down("left") then
        input_x = -1
    end
    if Input.down("down") then
        input_y = 1
    elseif Input.down("up") then
        input_y = -1
    end
    if input_x ~= 0 or input_y ~= 0 then
        local angle = math.acos(Vector.dot(self.collisionNormal[1], self.collisionNormal[2], input_x, input_y) / (Vector.len(self.collisionNormal[1], self.collisionNormal[2])*Vector.len(input_x, input_y)))
        local sign = Utils.sign(Vector.dot(self.collisionNormal[1], self.collisionNormal[2], input_y, -input_x))

        self.collisionNormal[1], self.collisionNormal[2] = Vector.rotate(sign*math.min(angle, self.collisionNormalRotationRate*DT), self.collisionNormal[1], self.collisionNormal[2])
        --Kristal.Console:log("Rotated normal by "..tostring(math.deg(sign*math.min(angle, self.collisionNormalRotationRate*DT))).." degrees!")
    end
    --Game.battle.soul:move(self.collisionNormal[1], self.collisionNormal[2], self.collisionSpeed)
    Game.battle.soul.x = Game.battle.soul.x + self.collisionNormal[1] * self.collisionSpeed * (30*DT)
    Game.battle.soul.y = Game.battle.soul.y + self.collisionNormal[2] * self.collisionSpeed * (30*DT)
    self.collisionSpeed = math.max(0, self.collisionSpeed - self.collisionDamping*DT)

    if self.soulCollider.debug_mode then
        self.soulCollider.debugArrow.rotation = math.atan2(self.collisionNormal[2], self.collisionNormal[1])
    end

    if self.soulCollider.position_initialized and not self.wave.keyGet and self.key.parent and self.soulCollider:collidesWith(self.key) then
        self.key:collect()
        self.wave:scoreDisplay()
        Game.battle.timer:after(0.5, function()
            self.wave.finished = true
        end)
    end

    super.update(self)
end

return Labyrinth