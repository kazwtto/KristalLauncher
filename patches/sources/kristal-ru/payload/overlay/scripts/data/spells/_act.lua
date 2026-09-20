-- This spell is only used for display in the POWER menu.

local spell, super = Class(Spell, "_act")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Действие"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    self.effect = ""
    -- Menu description
    if Game.chapter == 1 then
        self.description = "Делает всё, что угодно.\nЭто не магия."
    elseif Game.chapter == 2 then
        self.description = "Выполняйте различные действия.\nНе путайте с магией."
    elseif Game.chapter == 3 then
        self.description = "Множество различных навыков.\nНичего общего с магией."
    else
        self.description = "Выполняйте различные действия.\nНельзя считать магией."
    end

    -- TP cost
    self.cost = 0

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "enemy"

    -- Tags that apply to this spell
    self.tags = {}
end

return spell