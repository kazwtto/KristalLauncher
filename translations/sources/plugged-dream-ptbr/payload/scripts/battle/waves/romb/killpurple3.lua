local KillPurple, super = Class(Wave, "romb/killpurple3")

function KillPurple:init()
    super.init(self)

    self:setArenaSize(210, 210)

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

    self:spawnBullet("killpurple/spark_right", Game.battle.arena.left, Game.battle.soul.y - 87.6)
    self:spawnBullet("killpurple/spark_left", Game.battle.arena.left, Game.battle.soul.y - 29.2)
    self:spawnBullet("killpurple/spark_right", Game.battle.arena.left, Game.battle.soul.y + 29.2)
    self:spawnBullet("killpurple/spark_left", Game.battle.arena.left, Game.battle.soul.y + 87.6)

    self:spawnBullet("killpurple/spark_down_fast", Game.battle.soul.x - 89.6, Game.battle.arena.top)
    self:spawnBullet("killpurple/spark_up_fast", Game.battle.soul.x - 30.2, Game.battle.arena.top)
    self:spawnBullet("killpurple/spark_down_fast", Game.battle.soul.x + 30.2, Game.battle.arena.top)
    self:spawnBullet("killpurple/spark_up_fast", Game.battle.soul.x + 89.6, Game.battle.arena.top)

    --[[self.timer:every(2.5, function()
        self.timer:script(function(wait)
            local bullets = {}
            local x, y = Game.battle.soul.x, Game.battle.soul.y
            local r = 117
            local horizontal = math.random() < 0.5

            local positions
            if horizontal then
                positions = {
                    {x - r, y},
                    {x + r, y},
                }
            else
                positions = {
                    {x, y - r},
                    {x, y + r},
                }
            end

            for i = 1, #positions do
                Assets.playSound("bump")
                local cx, cy = positions[i][1], positions[i][2]
                local bullet = self:spawnBullet("werewire/spark", cx, cy, math.rad(180), 0)
                -- bullet.remove_offscreen = false
                bullet.tp = 0
                bullet.can_graze = false
                bullet.ignore = true
                bullet:setScale(4, 4)
                bullet.physics.direction = Utils.angle(bullet.x, bullet.y, x, y)
                table.insert(bullets, bullet)
                wait(0.01)
            end

            self.timer:after(.5, function()
                Assets.playSound("electric_talk", 1.35)
                for _, b in ipairs(bullets) do
                    self.timer:tween(1, b.physics, {speed = 6}, "in-back")
                end
            end)
        end)
    end)]]
end

function KillPurple:update()
    if self.purplekill_points == 8 then
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
