local SauceEnemy, super = Class(Sprite, "SauceEnemy")

function SauceEnemy:init(x, y, board, data)
    self.board = board

    data = data or {}
    --[[
    data:
        initFunc
        updateFunc
        moveFunc
        shootFunc
        onHit

        collider
        hp
        timeBetweenShots
        color
    ]]--
    if data["sprite"] == "none" then
        super.init(self, nil, x, y)
    else
        super.init(self, data["sprite"] or "objects/saucinshmupgame/test_enemy", x, y)
    end

    self:setOrigin(.5,.5)
    self:setScale(2)

    self.timeBetweenShots = data["timeBetweenShots"] or 1
    self.shootTimer = self.timeBetweenShots
    
    self.color = data["color"] or {1, 1, 1}
    self.initFunc = data["initFunc"] or function(obj) end
    self.updateFunc = data["updateFunc"] or function(obj)
        obj.shootTimer = obj.shootTimer - DT
        if obj.shootTimer <= 0 then
            obj.shootTimer = obj.timeBetweenShots
            obj:shootFunc()
        end
    end
    
    self.moveFunc = data["moveFunc"] or function(obj) end
    self.shootFunc = data["shootFunc"] or function(obj) end
    
    self.onHitExtra = data["onHitExtra"] or function(obj, bullet) end
    self.onHit = data["onHit"] or function(obj, bullet)
        if obj.hitCounts[bullet.sauce] then
            obj.hitCounts[bullet.sauce] = obj.hitCounts[bullet.sauce] + math.min(obj.hp, bullet.damage or 1)
        else
            obj.hitCounts[bullet.sauce] = math.min(obj.hp, bullet.damage or 1)
            obj.hitColors[bullet.sauce] = bullet.color
            --Kristal.Console:log(obj.hitCounts[bullet.sauce])
        end
        
        obj.hp = obj.hp - (bullet.damage or 1)
        local a = Utils.random(0, 2*math.pi)
        obj:shake(obj.shakeStrength*(bullet.power or 1)*math.cos(a), obj.shakeStrength*(bullet.power or 1)*math.sin(a))

        -- obj.changeColor(obj)

        obj.onHitExtra(obj, bullet)
        if obj.hp <= 0 then
            Assets.playSound(obj.killSound)
            obj:remove()
        end
        bullet:remove()
    end
    self.killSound = data["killSound"] or "snd_chop"
    self.shakeStrength = data["shakeStrength"] or 2

    local w = self.width
    local h = self.height
    self.collider = data["collider"] or Hitbox(self, 0, 0, w, h)
    self.hp = data["hp"] or 1
    self.max_hp = self.hp
    self.hitCounts = {}
    self.hitColors = {}

    self.autocull = true
    
    self.isOnPath = false

    self.enemyID = #self.board.enemies
    --Kristal.Console:log(self.enemyID)
    self:initFunc()
end

function SauceEnemy:changeColor(obj)
    local meanColor = {obj.hp, obj.hp, obj.hp}
    for name, count in pairs(obj.hitCounts) do
        local col = obj.hitColors[name]
        meanColor[1] = meanColor[1] + col[1]*count
        meanColor[2] = meanColor[2] + col[2]*count
        meanColor[3] = meanColor[3] + col[3]*count
    end
    meanColor[1] = meanColor[1] / obj.max_hp
    meanColor[2] = meanColor[2] / obj.max_hp
    meanColor[3] = meanColor[3] / obj.max_hp
end

function SauceEnemy:getMainColor()
    local maxHits = 0
    local maxColor = ""
    for name in pairs(self.hitCounts) do
        if self.hitCounts[name] > maxHits then
            maxHits = self.hitCounts[name]
            maxColor = name
        end
        --Kristal.Console:log(name)
        --Kristal.Console:log(self.hitCounts[name])
    end

    return maxColor
end

function SauceEnemy:getAllColors()
    local names = {}
    for name in pairs(self.hitCounts) do
        names[#names+1] = name
    end

    return names
end

function SauceEnemy:setMovementType(moveType, args)
    --[[ 
    Static ("static"): no args
        A single point at 
    
    Linear ("linear"): velocity x, velocity y
        Move in a straight line with prescribed velocity
    
    Circular ("orbit"): center x, center y, radius, period (seconds), starting angle (rad), direction (1 (clockwise) or -1 (counterclockwise))
    
    Sharp Square ("square"): center x, center y, width, rotation (rad), starting angle (rad), direction (1 (clockwise) or -1 (counterclockwise))
    
    Smooth Square ("square_orbit"): center x, center y, half-width, rotation period (seconds), rotation (rad), starting angle (rad), direction (1 (clockwise) or -1 (counterclockwise))
        A square-ish orbit with rounded corners. Zero rotation (default) puts the corners
    
    Sinusoid ("sine"): starting/center x, starting/center y, direction ("x","-x","y", or "-y"), speed, wavelength, amplitude
    
    SlideTo ("slideto"): end x, end y, time, ease, after

    SlideToSpeed ("slidetospeed"): end x, end y, speed, after
    
    Path ("path"): path, options
        Uses slidePath to 
    ]]--

    if moveType == "static" then
        self.moveFunc = function(obj) end
    elseif moveType == "linear"  then
        -- for i = 1,2 do
        --     Kristal.Console:log(args[i] or "shit")
        -- end
        self.moveParams = {
            vx = args[1] or 20,
            vy = args[2] or 0
        }
        self.moveFunc = function(obj)
            obj.x = obj.x + DT*self.moveParams.vx
            obj.y = obj.y + DT*self.moveParams.vy
        end
    elseif moveType == "orbit" then
        self.x0 = args[1] or self.x
        self.y0 = args[2] or self.y
        self.moveParams = {
            r = args[3] or 25,
            period = args[4] or 1,
            rotation = args[5] or 0,
            direction = args[6] or 1,
            angularPos = 0
        }
        self.moveFunc = function(obj)
            local r = obj.moveParams.r
            local omega = obj.moveParams.direction * 2*math.pi / obj.moveParams.period
            obj.moveParams.angularPos = obj.moveParams.angularPos + omega*DT
            obj.x = obj.x0 + r*math.cos(obj.moveParams.angularPos + obj.moveParams.rotation)
            obj.y = obj.y0 + r*math.sin(obj.moveParams.angularPos + obj.moveParams.rotation)
        end
    elseif moveType == "square" then
        self.x0 = args[1] or self.x
        self.y0 = args[2] or self.y
        self.moveParams = {
            r = args[3] or 25,
            period = args[4] or 1,
            rotation = args[5] or 0,
            angularPos = args[6] or 0,
            direction = args[7] or 1
        }
    elseif moveType == "square_orbit" then
        self.x0 = args[1] or self.x
        self.y0 = args[2] or self.y
        self.moveParams = {
            r = args[3] or 25,
            period = args[4] or 1,
            rotation = args[5] or 0,
            angularPos = args[6] or 0,
            direction = args[7] or 1
        }
        self.moveFunc = function(obj)
            local r = obj.moveParams.r / 0.88
            local r1 = r
            local r2 = r*0.12
            local sign = obj.moveParams.direction
            local omega = 2*math.pi / obj.moveParams.period
            obj.moveParams.angularPos = obj.moveParams.angularPos + sign*omega*DT
            obj.x = obj.x0 + r1*math.cos(obj.moveParams.angularPos + sign*(math.pi/4 + obj.moveParams.rotation))
            obj.x = obj.x  + r2*math.cos(-3*obj.moveParams.angularPos + sign*(math.pi/4 + obj.moveParams.rotation))
            obj.y = obj.y0 + r1*math.sin(obj.moveParams.angularPos + sign*(math.pi/4 + obj.moveParams.rotation))
            obj.y = obj.y  + r2*math.sin(-3*obj.moveParams.angularPos + sign*(math.pi/4 + obj.moveParams.rotation))
        end
    elseif moveType == "sine" then
        -- Sinusoid ("sine"): starting/center x, starting/center y, direction ("x","-x","y", or "-y"), speed, wavelength, amplitude
    
        self.x0 = args[1] or self.x
        self.y0 = args[2] or self.y

        self.x = self.x0
        self.y = self.y0

        local dir = string.find(args[3] or "x", "y")
        if dir then dir = "y" else dir = "x" end
        local sign = string.find(args[3] or "+", "-")
        if sign then sign = -1 else sign = 1 end

        self.moveParams = {
            dir = dir,
            sign = sign,
            speed = args[4] or 50,
            wavelength = args[5] or 30,
            amplitude = args[6] or args[5]/2 or 15
        }
        self.moveFunc = function(obj)
            if obj.moveParams.dir == "y" then
                obj.y = obj.y + obj.moveParams.sign*obj.moveParams.speed*DT
                obj.x = obj.x0 + obj.moveParams.amplitude * math.sin((obj.y0 - obj.y) * 2*math.pi / obj.moveParams.wavelength)
            else
                obj.x = obj.x + obj.moveParams.sign*obj.moveParams.speed*DT
                obj.y = obj.y0 + obj.moveParams.amplitude * math.sin((obj.x0 - obj.x) * 2*math.pi / obj.moveParams.wavelength)
            end
        end
    elseif moveType == "slideto" then
        self.moveParams = {
            endX = args[1],
            endY = args[2]
        }
        self.isOnPath = true
        local after
        if args[5] then
            after = function()
                args[5]()
                self.isOnPath = false
            end
        else
            after = function()
                self.isOnPath = false
            end
        end
        self.moveFunc = function(obj) end
        self:slideTo(self.moveParams.endX, self.moveParams.endY, args[3] or 1, args[4] or 'linear', after)
    elseif moveType == "slidetospeed" then
        self.moveParams = {
            endX = args[1],
            endY = args[2],
            speed = args[3] or 20
        }
        self.isOnPath = true
        local after
        if args[4] then
            after = function()
                args[4]()
                self.isOnPath = false
            end
        else
            after = function()
                self.isOnPath = false
            end
        end
        self.moveFunc = function(obj) end
        self:slideToSpeed(self.moveParams.endX, self.moveParams.endY, self.moveParams.speed, after)
    elseif moveType == "path" then
        self.isOnPath = true
        self.moveParams = {
            path = args[1],
            options = {}
        }
        for name,_ in pairs(args[2]) do
            if name ~= "after" then
                self.moveParams.options = args[2][name]
            end
        end
        if args[2].after then
            self.moveParams.options.after = function()
                args[2].after()
                self.isOnPath = false
            end
        else
            self.moveParams.options.after = function()
                self.isOnPath = false
            end
        end

        self.moveFunc = function(obj) end
        self:slidePath(path, options)
    end
end

function SauceEnemy:fire(x, y, bullet)
    if type(x) == "table" then
        bullet = x
        x = self.x
        y = self.y
    end
    local bulletObj = self.board:spawnObject(SauceBullet(x, y, {1, 1, 1}, bullet, self.board))
    bulletObj:setLayer(BATTLE_LAYERS["above_arena"])
    bulletObj:setScale(2)
    bulletObj.enemy = self
    table.insert(self.board.enemyBullets, bulletObj)
    --Kristal.Console:log(#self.board.enemyBullets)

    return bulletObj
end

function SauceEnemy:draw()
    super.draw(self)
    if DEBUG_RENDER then
        self.collider:draw(1,0,0)
    end
end

function SauceEnemy:onRemove()
    self.collider = nil
    super.onRemove(self)
end

function SauceEnemy:update()
    if self.autocull then
        if self.x < 0 or self.x > SCREEN_WIDTH or self.y < 0 or self.y > SCREEN_HEIGHT then
            self:remove()
        end
    end
    
    self:updateFunc()
    self:moveFunc()
    super.update(self)
end

return SauceEnemy