local KillPurple, super = Class(Wave, "romb/killpurple")

function KillPurple:init()
    super.init(self)

    self:setArenaSize(146, 146)

    self.time = -1
    self.waitVar = 0

    self.purplekill_points = 0
end

function KillPurple:onStart()
    self.enemy = Game.battle.enemies[1]
    Game.battle.soul.inv_timer = 1
    Game.battle.soul.x = Game.battle.arena.x
    Game.battle.soul.y = Game.battle.arena.y
    Game.battle.battle_ui.encounter_text:setText("* Use sua lâmina pra obliterar todos os projéteis [color:purple]roxos[color:reset]!")

    self:spawnBullet("killpurple/spark_right", Game.battle.arena.left, Game.battle.soul.y - 58.4)
    self:spawnBullet("killpurple/spark_left", Game.battle.arena.left, Game.battle.soul.y - 29.2)
    self:spawnBullet("killpurple/spark_right", Game.battle.arena.left, Game.battle.soul.y)
    self:spawnBullet("killpurple/spark_left", Game.battle.arena.left, Game.battle.soul.y + 29.2)
    self:spawnBullet("killpurple/spark_right", Game.battle.arena.left, Game.battle.soul.y + 58.4)
end

function KillPurple:update()
    if self.purplekill_points == 5 then
        self.waitVar = self.waitVar + 1 * DTMULT;
        if (self.waitVar > 50) then
            self.time = 0;
            return
        end
    end
    self.time = -1

    super.update(self)
end

return KillPurple
