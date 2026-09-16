local spell, super = Class(Spell, "xslash")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "X-Slash"
    -- Name displayed when cast (optional)
    self.cast_name = "CORTE-X"

    -- Battle description
    self.effect = "Dano\nFísico"
    -- Menu description
    self.description = "Causa grande dano físico a 1 inimigo."
    -- Check description
    self.check = "Causa grande dano físico a 1 inimigo."

    -- TP cost
    self.cost = 35

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "enemy"

    -- Tags that apply to this spell
    self.tags = {"Damage"}
end

function spell:getCastMessage(user, target)
    return "* " .. (user.chara:getName()) .. " usou " .. (self:getCastName()) .. "!"
end

function spell:onCast(user, target)
    local damage = math.floor((((user.chara:getStat("attack") * 140) / 20) - 3 * (target.defense)) * 1.3)

    ---@type XSlashSpell
    local spellobj = XSlashSpell(user,target)
    Game.battle:addChild(spellobj):setLayer(BATTLE_LAYERS["above_battlers"])

    spellobj.damage_callback = function(self, hit_action_command)
        local strikedmg = damage
        target:hurt(strikedmg, user)
    end
    return false
end

return spell
