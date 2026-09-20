local barTimer, super = Class(Object, "barTimer")

function barTimer:init()
    super.init(self)
    self.time = 60
    self.originaltime = 60
    self.ticket = Assets.getTexture("objects/ticket")
    self.font = Assets.getFont("Sunny")
    self.name = (love.graphics.newText(self.font, "Def."))
    self.numtime = love.graphics.newText(self.font, "60s")
    self.displayed_time = "60"
    self.employs = {}
    self.uses = {}
    self.lookup = {}
end

function barTimer:getEmploys(employs)
    if employs ~= nil then
        for i = 1, #employs do
            if employs[i] == nil then
                table.insert(self.employs, love.graphics.newText(self.font, "_")) -- Draw blank if employee is marked blank.
            else
                local employname = employs[i]['id']
                table.insert(self.employs, Assets.getTexture("ui/employ/" .. employname))
                table.insert(self.uses, love.graphics.newText(self.font, employs[i]['uses']))
                self.lookup[employs[i]['id']] = i -- Position storage.
            end
        end
    end
end

function barTimer:updateUses(uses, employ)
    table.insert(self.uses, self.lookup[employ], love.graphics.newText(self.font, uses))
end


function barTimer:getstartTime()
    self.originaltime = Timerscript:grabStartTime()
end

function barTimer:getTime()
    self.time = Timerscript:grabTime() or 60
    local displayed_time = tostring(self.time or 60)
    if self.displayed_time ~= displayed_time then
        self.displayed_time = displayed_time
        self.numtime:set(displayed_time .. "s")
    end
end

function barTimer:update()
    super.update(self)
    self:getTime()
    self:getstartTime()
end

function barTimer:draw()
    super.draw(self)



    self.time = self.time or 60

    self.originaltime = self.originaltime or 60

    self.numtime = self.numtime or love.graphics.newText(self.font, tostring(self.time or 60) .. "s")

    local ratio = self.time/self.originaltime
    love.graphics.setColor(1,0,0, self.alpha)
    love.graphics.rectangle("fill", 500, 60, 100, 10)

    love.graphics.setColor(0.4,0.8,0.24*self.alpha)
    love.graphics.rectangle("fill", 500, 60, 100 * ratio, 10)

    love.graphics.draw(self.numtime, 500, 75)

    love.graphics.draw(self.ticket, 487, 0, 0, 1.25, 1)

    if self.nametext ~= Timerscript:returnName() then
        self.nametext = Timerscript:returnName()
        self.name:set(self.nametext)
    end

    local width, _ = self.name:getDimensions()
    local factor = 1
    if width > 100 then factor = 100/width end
    love.graphics.draw(self.name, 500, 20, 0, factor)

    --employees

    for i= 1, #self.employs do
        local pos = 95 + 10 * i
        local width, _ = self.employs[i]:getDimensions()
        local factor = 20 / width
        love.graphics.draw(self.employs[i], 500, pos, 0, factor, factor)
        love.graphics.draw(self.uses[i], 550, pos, 0)
    end

    --clockhands
    if not Game:getFlag("noclock") then
        Draw.setColor (1, 1, 1, self.alpha)

        love.graphics.setLineWidth(3)

        Draw.setColor(102/255, 204/255, 61/255, 1)
        love.graphics.line(71, 139, 71 + 20 * math.cos(Game:getFlag("clockAngle")), 139 + 20 * math.sin(Game:getFlag("clockAngle")))
    end
end

return barTimer
