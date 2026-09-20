---@class ControlsDisplay : Object
local ControlsDisplay, super = Class(Object)

function ControlsDisplay:init(x, y, layout, blink)
    super.init(self, x, y, 0, 0)

    self.path = "objects/buttons/keys/"

    if blink ~= false then
        blink = true
    end
    self.blink = blink

    if Input.usingGamepad() then
        self.controls = {
            left = Input.getTexture("left", true),
            right = Input.getTexture("right", true),
            up = Input.getTexture("up", true),
            down = Input.getTexture("down", true),
            confirm = Input.getTexture("confirm", true),
            cancel = Input.getTexture("cancel", true),
            menu = Input.getTexture("menu", true),
            press = Assets.getTexture(self.path .. "press")
        }
    else
        local function keyTexture(action)
            local bind = Input.getPrimaryBind(action)
            if type(bind) ~= "string" then
                return nil
            end
            return Assets.getTexture(self.path .. bind .. "_button")
        end

        self.controls = {
            left = keyTexture("left"),
            right = keyTexture("right"),
            up = keyTexture("up"),
            down = keyTexture("down"),
            confirm = keyTexture("confirm"),
            cancel = keyTexture("cancel"),
            menu = keyTexture("menu"),
            press = Assets.getTexture(self.path .. "press")
        }
    end
    
    local placeholder = Assets.getTexture(self.path .. "placeholder_button")
    if not self.controls["confirm"] then self.controls["confirm"] = placeholder end
    if not self.controls["cancel"] then self.controls["cancel"] = placeholder end
    if not self.controls["menu"] then self.controls["menu"] = placeholder end
    if not self.controls["left"] then self.controls["left"] = placeholder end
    if not self.controls["right"] then self.controls["right"] = placeholder end
    if not self.controls["up"] then self.controls["up"] = placeholder end
    if not self.controls["down"] then self.controls["down"] = placeholder end


    self.layout_controls = {
        confirm = false,
        cancel = false,
        menu = false,
        left = false,
        right = false,
        up = false,
        down = false
    }

    layout = layout or "button"
    if layout == "button" then
        self.layout_controls.confirm = true
    elseif layout == "button_alt" then
        self.layout_controls.confirm = true
        self.press = true
    elseif layout == "button_x" then
        self.layout_controls.cancel = true
    elseif layout == "full_layout" then
        self.layout_controls.up = true
        self.layout_controls.down = true
        self.layout_controls.left = true
        self.layout_controls.right = true
        self.layout_controls.confirm = true
    elseif layout == "full_layout_alt" then
        self.layout_controls.up = true
        self.layout_controls.down = true
        self.layout_controls.left = true
        self.layout_controls.right = true
    elseif layout == "full_layout_x" then
        self.layout_controls.up = true
        self.layout_controls.down = true
        self.layout_controls.left = true
        self.layout_controls.right = true
        self.layout_controls.confirm = true
        self.layout_controls.cancel = true
    elseif layout == "horiz_layout" then
        self.layout_controls.left = true
        self.layout_controls.right = true
        self.layout_controls.confirm = true
    elseif layout == "horiz_layout_alt" then
        self.layout_controls.left = true
        self.layout_controls.right = true
    elseif layout == "no_down_layout" then
        self.layout_controls.left = true
        self.layout_controls.right = true
        self.layout_controls.up = true
        self.layout_controls.confirm = true
    elseif layout == "vert_layout" then
        self.layout_controls.down = true
        self.layout_controls.up = true
        self.layout_controls.confirm = true
    elseif layout == "vert_layout_alt" then
        self.layout_controls.down = true
        self.layout_controls.up = true
    end
    self.layout = layout or "button"

    self.lastbutton = Assets.getTexture(self.path .. "z_button")
    self.debug_select = true

    for button, state in pairs(self.layout_controls) do
        if state then

            local buttonimg = self.controls[button]
            if button == "confirm" then
                self.width = self.width + buttonimg:getWidth()
                if not self.layout_controls.cancel then
                    self.height = self.height + buttonimg:getHeight() 
                end
            elseif button == "cancel" then
                self.width = self.width + buttonimg:getWidth()
                if not self.layout_controls.confirm then
                    self.height = self.height + buttonimg:getHeight() 
                end
            elseif button == "left" then
                self.width = self.width + buttonimg:getWidth()
            elseif button == "right" then
                self.width = self.width + buttonimg:getWidth()
            elseif button == "up" then
                self.height = self.height + buttonimg:getHeight()
            elseif button == "down" then
                self.height = self.height + buttonimg:getHeight()
            end
        end
    end

    if (not self.layout_controls.confirm and not self.layout_controls.cancel) then
        if self.layout_controls.up and self.layout_controls.down then
            self.height = self.height + 11
        elseif self.layout_controls.left and self.layout_controls.right then
            self.width = self.width + 11
        end
    end

    self:setOrigin(0.5)

    if not Game.battle then
        Game.world.timer:after(1/30, function ()
            self.width = self.width * self.scale_x
            self.height = self.height * self.scale_y
        end)
    else
        Game.battle.timer:after(1/30, function ()
            self.width = self.width * self.scale_x
            self.height = self.height * self.scale_y
        end)
    end

    --self.height = self.height+30
    --self.width = self.width+30

    self.flash = true
    self.flash_timer = 0
end

function ControlsDisplay:draw()
    super.draw(self)

    if self.blink then
        self.flash_timer = self.flash_timer + DT
        if self.press then
            self.flash_timer = self.flash_timer + DT
        end
        if self.flash_timer >= 0.5 then
            self.flash = not self.flash
            self.flash_timer = 0
        end
    end
    
    --print(self.color[1], self.color[2], self.color[3]) PLEASE MAKE SURE TO REMOVe DEBUG PRINTS WHEN YOURE DONE WITH THEM
    love.graphics.setColor(1*self.color[1], 1*self.color[2], (self.flash and (1*self.color[3])) or (0*self.color[3]), self.alpha)

    for button, state in pairs(self.layout_controls) do
        if state then
            if self.layout_controls.confirm and self.layout_controls.cancel then
                local buttonimg = self.controls[button]
                if button == "confirm" then
                    love.graphics.draw(buttonimg, self.width/2+buttonimg:getWidth(), self.height/2, 0, self.scale_x, self.scale_y, buttonimg:getWidth()/2, buttonimg:getHeight()/2)
                elseif button == "cancel" then
                    love.graphics.draw(buttonimg, self.width/2-buttonimg:getWidth(), self.height/2, 0, self.scale_x, self.scale_y, buttonimg:getWidth()/2, buttonimg:getHeight()/2)
                elseif button == "left" then
                    love.graphics.draw(buttonimg, -self.controls.cancel:getWidth()*self.scale_x+self.width/2, self.height/2, 0, self.scale_x, self.scale_y, buttonimg:getWidth(), buttonimg:getHeight()/2)
                elseif button == "right" then
                    love.graphics.draw(buttonimg, self.controls.confirm:getWidth()*self.scale_x+self.width/2, self.height/2, 0, self.scale_x, self.scale_y, 0, buttonimg:getHeight()/2)
                elseif button == "up" then
                    love.graphics.draw(buttonimg, self.width/2, -self.controls.cancel:getHeight()/2*self.scale_y+self.height/2, 0, self.scale_x, self.scale_y, buttonimg:getWidth()/2, buttonimg:getHeight())
                elseif button == "down" then
                    love.graphics.draw(buttonimg, self.width/2, self.controls.cancel:getHeight()/2*self.scale_y+self.height/2, 0, self.scale_x, self.scale_y, buttonimg:getWidth()/2, 0)
                end
            else
                local offset = 0
                if self.layout == "no_down_layout" then
                    offset = 0.25
                end
                local buttonimg = self.controls[button]
                if button == "confirm" then
                    love.graphics.draw(buttonimg, self.width/2, self.height/2+self.height*offset, 0, self.scale_x, self.scale_y, buttonimg:getWidth()/2, buttonimg:getHeight()/2)
                    if not self.flash and self.press then
                        love.graphics.draw(self.controls.press, self.width/2, self.height/2+self.height*offset, 0, self.scale_x, self.scale_y, self.controls.press:getWidth()/2, self.controls.press:getHeight()/2)
                    end
                    self.lastbutton = buttonimg
                elseif button == "cancel" then
                    love.graphics.draw(buttonimg, self.width/2, self.height/2+self.height*offset, 0, self.scale_x, self.scale_y, buttonimg:getWidth()/2, buttonimg:getHeight()/2)
                    self.lastbutton = buttonimg
                elseif button == "left" then
                    love.graphics.draw(buttonimg, -self.lastbutton:getWidth()/2*self.scale_x+self.width/2, self.height/2+self.height*offset, 0, self.scale_x, self.scale_y, buttonimg:getWidth(), buttonimg:getHeight()/2)
                elseif button == "right" then
                    love.graphics.draw(buttonimg, self.lastbutton:getWidth()/2*self.scale_x+self.width/2, self.height/2+self.height*offset, 0, self.scale_x, self.scale_y, 0, buttonimg:getHeight()/2)
                elseif button == "up" then
                    love.graphics.draw(buttonimg, self.width/2, -self.lastbutton:getHeight()/2*self.scale_y+self.height/2+self.height*offset, 0, self.scale_x, self.scale_y, buttonimg:getWidth()/2, buttonimg:getHeight())
                elseif button == "down" then
                    love.graphics.draw(buttonimg, self.width/2, self.lastbutton:getHeight()/2*self.scale_y+self.height/2+self.height*offset, 0, self.scale_x, self.scale_y, buttonimg:getWidth()/2, 0)
                end
            end
        end
    end
end

return ControlsDisplay