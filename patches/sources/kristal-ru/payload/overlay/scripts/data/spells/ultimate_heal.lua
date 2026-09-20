local spell, super = Class(Spell, "ultimate_heal")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "УльтЛечение"
    -- Name displayed when cast (optional)
    self.cast_name = "УЛЬТРАЛЕЧЕНИЕ"

    -- Battle description
    self.effect = "Лучшее\nлечение"
    -- Menu description
    self.description = "Превосходное лечебное заклинание\n...ведь так?"

    -- TP cost
    self.cost = 100

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "ally"

    -- Tags that apply to this spell
    self.tags = {"heal"}
end

function spell:onCast(user, target)
    local base_heal = user.chara:getStat("magic") + 1
    local heal_amount = Game.battle:applyHealBonuses(base_heal, user.chara)

    target:heal(heal_amount)
end

return spell
