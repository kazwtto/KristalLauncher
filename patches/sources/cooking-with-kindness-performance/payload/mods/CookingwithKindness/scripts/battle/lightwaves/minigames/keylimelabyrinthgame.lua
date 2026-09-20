local KeyLimeLabyrinthGame, super = Class("LightMinigameWave")

function KeyLimeLabyrinthGame:init()
    super.init(self, _s("minigame_popup-keylimelabyrinthgame", "COLLECT KEY!"), "full_layout_alt", true)
    Kristal.Console:log("minigame init start")
    self.w = 170
    self.h = 170

    self.time = 23.5
    self.failDisplayTime = self.time - 0.5 -- for displaying the "fail" text before the minigame ends.

    self:setArenaSize(2 * self.w, 2 * self.h)
    self:setArenaPosition(320, 240)
end

function KeyLimeLabyrinthGame:onStart()
    self.maze = self:spawnObject(Labyrinth(Game.battle.arena.left, Game.battle.arena.top, self.w, self.h, self))
    self.maze:setLayer(BATTLE_LAYERS["arena"] + 4)

    self.HPMeter = self:spawnObject(LabyrinthLimeMeter(Game.battle.arena.left - 40, Game.battle.arena.top,
        self.maze.soulCollider))
    self.HPMeter:setLayer(BATTLE_LAYERS["arena"] + 5)


    self.score = 5
    Game.battle.timer:after(7, function ()
        self.score = 3
    end)
    Game.battle.timer:after(15, function ()
        self.score = 1
    end)
    --[[Game.battle.timer:after(self.failDisplayTime, function () 
        self:scoreDisplay()
    end)]]
end

function KeyLimeLabyrinthGame:update()
    -- Code here gets called every frame
    local touching_key = self.maze.soulCollider:collidesWith(self.maze.key)
    if touching_key and not self._cwk_touching_key then
        Kristal.Console:log("KEY GET")
        -- Game:setFlag("mimiLock", false)
    end
    self._cwk_touching_key = touching_key
    -- super.update(self)
end

function KeyLimeLabyrinthGame:scoreDisplay() -- we really need to make these base functions in lightwave or smth ( I DID IT >:] )
    local msg = "" -- What message to dislpay
    local snd = "error" -- What sound effect to player

    if not self.keyGet then
        if Utils.random() > 0.25 then
            msg = "Bad"
        else
            msg = ":("
        end
        snd = "error"
        self.actualScore = 0
        Game.battle.soul.canMove = false
    elseif self.score == 5 then
        msg = "Perfect"
        snd = "snd_perfect"
        self.actualScore = 5
    elseif self.score == 3 then
        msg = "Great"
        snd = "snd_great"
        self.actualScore = 3
    elseif self.score == 1 then 
        msg = "Okay"
        snd = "snd_good"
        self.actualScore = 1
    end

    -- Set text to appropriate message and play corresponding sound
    self:scoreMessage(msg)
    Assets.playSound(snd, 0.6, 1.2)
end

function KeyLimeLabyrinthGame:onEnd()
    if not self.keyGet then
        Game:setFlag("Results", "noKey")
        Kristal.Console:log("Did not grab key.")
        Stepscript:backStep("labyrinth")
    else
        Game:setFlag("Results", "yesKey")
        Game:setFlag("mimiLocked", false)
        CustScore:addPoints(6)
        Game.battle:getEnemyBattler("mimi").metrecs = true
    end
end

return KeyLimeLabyrinthGame
