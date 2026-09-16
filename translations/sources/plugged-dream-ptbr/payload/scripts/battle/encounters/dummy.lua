local Dummy, super = Class(Encounter)

function Dummy:init()
    super.init(self)

    -- Text displayed at the bottom of the screen at the start of the encounter
    self.text = "* ESPERO QUE ESTEJA SE DIVERTINDO"

    -- Battle music ("battle" is rude buster)
    self.music = "ramb_boss"
    -- Enables the purple grid battle background
    self.background = true

    -- Add the dummy enemy to the encounter
    self:addEnemy("dummy")

    --- Uncomment this line to add another!
    --self:addEnemy("dummy")
end

function Dummy:createSoul()
    return GridSoul()
end

return Dummy
