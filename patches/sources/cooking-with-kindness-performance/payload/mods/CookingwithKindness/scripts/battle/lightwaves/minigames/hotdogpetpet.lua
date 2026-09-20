local HotDogPetPet, super = Class("LightMinigameWave")

function HotDogPetPet:init()
    super.init(self, _s("minigame_popup-hotdogpetpet", "PETPET!"), "button_alt")

    self:setArenaSize(300,200)
    self:setArenaPosition(320,290)
    self.time = 5
    -- measure cps for animation speed??
    self.timesPetted_total = 0
    self.timesPetted = 0

    local x, y = Game.battle.arena:getCenter()
    self.dog = Sprite("objects/dogwalkgame/dog",x-20,y)
    self.dog:setScale(4,4)
    self.dog:setScaleOrigin(0.5,1)
    self.dog:play(1)

    self.dogScale = {4.0, 3.8, 3.3, 3.7, 3.9}

    self.hand = Sprite("objects/hotdog_hand/Hotdog_Pet",x - 35,y - 80)
    self.hand:setColor(0,1,0)
    self.hand.anim_speed = 0
    self.hand:play(1/30)
end

function HotDogPetPet:onStart()
    self:spawnObject(self.dog)
    self:spawnObject(self.hand)

    Game.battle.timer:after(self.time - 1, function ()
        self:score()
    end)

    self:update()
end

function HotDogPetPet:update()
    local wasConfirm = Input.pressed("confirm",false)
    if wasConfirm then
        self.timesPetted = self.timesPetted + 1
        self.timesPetted_total = self.timesPetted_total + 1
    end

    if self.timesPetted > 0 then
        self.anim_speed = self.timesPetted / (Game.battle.wave_timer)
        self.hand.anim_speed = self.anim_speed / 6
        if self.hand.anim_speed >= 2 then self.hand.anim_speed = 2 end
        self.timesPetted = self.timesPetted - (0.1 * self.hand.anim_speed)
        self.hand:resume()

        if self.dog_tween then
            Game.battle.timer:cancel(self.dog_tween)
        end
        self.dog_tween = Game.battle.timer:tween(self.hand.anim_delay*2, self.dog, {scale_y = self.dogScale[self.hand.frame]})
        if Kristal.getLibConfig("moist-lib","debug_prints") then print("TP"..self.timesPetted..", RATE:"..string.format("%.2f", self.anim_speed)..", Sprite's rate:"..string.format("%.2f", self.hand.anim_speed) ) end
    end
    --print(self.hand.anim_speed)

    
end

function HotDogPetPet:score()
    self:scoreMessage("Perfect", self.dog.x, self.dog.y)
    Assets.playSound("snd_perfect", 0.6, 1.2)
end

function HotDogPetPet:onEnd()
    if Kristal.getLibConfig("moist-lib","debug_prints") then
        print("petted:"..self.timesPetted_total)
        print("rate:"..self.hand.anim_speed)
    end
    CustScore:addPoints(5)
    Game.battle:getEnemyBattler("vulkin").metrecs = true

    -- put relevant stuff here
end

return HotDogPetPet