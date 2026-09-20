local SaladBowl, super = Class(Sprite, "SaladBowl")

local function setColorIfNeeded(object, r, g, b)
    local color = object.color
    if color[1] ~= r or color[2] ~= g or color[3] ~= b then
        object:setColor(r, g, b)
    end
end

function SaladBowl:init(x, y)
    super.init(self, "objects/saladtosser/bowl", x, y)
    local layer

    self.fillLevel = 0
    self.flashTimer = 0
    self.lastfill = 0
    self.momentum = 0
    self.waste = 0
    self.recipe = "objects/saladtosser/fruitsalad"
    self.layers = {}
    self.collider = Hitbox(self, 5, 26, 98, 2)

    self.back = Game.battle.waves[1]:spawnObject(Sprite(self.recipe.."/fill1",x,y))
    self.back:setLayer(BATTLE_LAYERS["below_soul"])
    for i = 1, 4 do
        layer = Game.battle.waves[1]:spawnObject(Sprite(self.recipe.."/layer"..i,x,y))
        layer:setLayer(BATTLE_LAYERS["soul"])
        layer:setOrigin(0.5, 1)
        self.layers[i] = layer
    end
    self.glaze = Game.battle.waves[1]:spawnObject(Sprite(self.recipe.."/glaze1",x,y))
    self.glaze:setLayer(BATTLE_LAYERS["above_soul"])

    self:setOrigin(0.5, 1)
    self.glaze:setOrigin(0.5, 1)
    self.back:setOrigin(0.5, 1)
    self.timer = 0
end

function SaladBowl:update()
    local quantity = Utils.random(1,2,1)
    local thrustfactor = Utils.random(-3, 3)
    local wave = Game.battle.waves[1]
    local part
    self.flashTimer = self.flashTimer + DT
    local amt = math.floor(self.flashTimer / (2/15))
    local color_state = 0

    if self.frozen then
        self:setSpeed(0,0)
        self.back:setSpeed(0,0)
        color_state = (amt % 2 == 1) and 1 or 2

        if not self._cwk_unfreeze_timer_started then
            self._cwk_unfreeze_timer_started = true
            wave.timer:after(1, function()
                self.frozen = false
                self._cwk_unfreeze_timer_started = false
            end)
        end
    end

    local r = 1
    local gb = 1
    if color_state == 1 then
        gb = 0
    elseif color_state == 2 then
        r = 0.5
        gb = 0
    end

    setColorIfNeeded(self, r, gb, gb)
    setColorIfNeeded(self.back, r, gb, gb)
    setColorIfNeeded(self.glaze, r, gb, gb)
    for i = 1, #self.layers do
        setColorIfNeeded(self.layers[i], r, gb, gb)
    end

    if Input.keyDown("up") and not self.moving and not self.frozen then
        local starty = self.y
        local mult = Utils.floor(self.fillLevel*4/100)

        self.moving = true
        wave.timer:tween(0.2, self, {y=starty-20}, "out-quad")
        wave.timer:tween(0.2, self.back, {y=starty-20}, "out-quad")        

        for i = 1, 4 do
            wave.timer:tween(0.2, self.layers[i], {y=starty-(24 + (math.max(i-mult, 0))*8)}, "out-quad")
        end
        wave.timer:tween(0.2, self.glaze, {y=starty-(28 + (math.max(5-mult, 0))*8)}, "out-quad")

        wave.timer:after(0.2, function ()
            local sprite, xthrust, ythrust, star
            for i = 1, quantity do
                sprite = self.recipe.."/part"..Utils.random(1, 6, 1)
                xthrust = Utils.random(-2.5,2.5) + thrustfactor + self.momentum
                ythrust = Utils.random(30,50) + ((80*i)/quantity)

                part = wave:spawnObject(SaladPart(sprite, self.x, self.y - 50, xthrust, ythrust))
                part.bowl = self
                part:setOrigin(0.5, 0.5)
                part:setLayer(BATTLE_LAYERS["below_soul"])
            end

            if quantity > 1 then
                Assets.playSound("ui_cancel")
            else
                Assets.playSound("ui_cancel_small")
            end

            for i = 1, 4 do
                wave.timer:tween(0.4, self.layers[i], {y=starty}, "in-quad")
            end
            wave.timer:tween(0.4, self.glaze, {y=starty}, "in-quad")
            wave.timer:tween(0.3, self, {y=starty}, "in-quad")
            wave.timer:tween(0.3, self.back, {y=starty}, "in-quad")
            wave.timer:after(0.4, function ()
                self.moving = false
                self.fillLevel = Utils.absMin(self.fillLevel + 8, 100)
                --
                if self.lastfill < Utils.floor(self.fillLevel*5/100)+1 then
                    self.back:set(self.recipe.."/fill"..(Utils.floor(self.fillLevel*5/100))+1)
                    if self.fillLevel == 100 then
                        Assets.playSound("saber3")
                        Assets.playSound("noise")
                        for i = 1, 3 do
                            --star = self:createSprite("effects/lightattack/frypan_star")

                        end
                    else
                        Assets.playSound("noise")
                    end
                end

                if Utils.floor(self.fillLevel*9/100) >= 8 then
                    self.glaze:set(nil)
                else
                    self.glaze:set(self.recipe.."/glaze"..(Utils.floor(self.fillLevel*8/100))+1)
                end
                self.lastfill = Utils.floor(self.fillLevel*5/100)+1
            end)
        end)
    end

    if Input.keyDown("left") and self.x >= (Game.battle.arena.left + 68) and not self.frozen then
        self:setSpeed(-7,0)
        self.back.x = self.x - 7
        self.momentum = -3
    elseif Input.keyDown("right") and self.x <= (Game.battle.arena.right - 68) and not self.frozen then
        self:setSpeed(7,0)
        self.back.x = self.x + 7
        self.momentum = 3
    else
        self:setSpeed(0,0)
        self.back:setSpeed(0,0)
    end

    for i = 1, 4 do
        self.layers[i].physics.speed_x = self.physics.speed_x
        self.layers[i].x = self.x
    end
    self.glaze.physics.speed_x = self.physics.speed_x
    self.glaze.x = self.x

    super.update(self)
end

return SaladBowl