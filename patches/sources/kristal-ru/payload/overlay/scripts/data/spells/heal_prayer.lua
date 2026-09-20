local spell, super = Class(Spell, "heal_prayer")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Исцеление"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    if Game.chapter <= 3 then
        self.effect = "Лечит\nсоюзника"
    else
        self.effect = "Лечит\nсоюзника"
    end
    -- Menu description
    self.description = "Небесный свет восполняет немного ОЗ\nодному члену команды. Зависит от магии."

    -- TP cost
    self.cost = 32

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "ally"

    -- Tags that apply to this spell
    self.tags = {"heal"}
end

function spell:onCast(user, target)
    local base_heal = user.chara:getStat("magic") * 5
    local heal_amount = Game.battle:applyHealBonuses(base_heal, user.chara)

    target:heal(heal_amount)
end

function spell:hasWorldUsage(chara)
    return true
end

function spell:onWorldCast(chara)
    Game.world:heal(chara, 100)
end

return spell