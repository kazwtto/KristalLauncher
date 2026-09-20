local ItemDescBox, super = Class(Object)

function ItemDescBox:init(x,y,w,h,icon_sprite,check_text,category_text)
    super.init(self,x,y,w,h)

    if Game.state == "OVERWORLD" then
        self.textbox = Textbox(0,0,530,104)
        self:addChild(self.textbox)
        

        self.icon_separator = UIBox(402,-86,128,34)
        self:addChild(self.icon_separator)

        if icon_sprite then
            self.item_icon = Sprite(icon_sprite,self.icon_separator.x+8,self.icon_separator.y+self.icon_separator.height/2)
            self.item_icon:setScale(2)
            self.item_icon:setOrigin(0.5,0.5)
            self:addChild(self.item_icon)
        end

        if check_text then
            self:setInfoText(check_text)
        end

        if category_text then
            self:setCategoryText("[font:small]"..category_text)
        end

        --[[self.check_text_obj = DialogueText(self.check_text,85,-17,500,100)
        self.check_text_obj.advance_callback = function()
            if self.check_text_obj.done == true then
                local menu = Game.world.menu ---@type LightMenu
                if menu and menu:includes(LightMenu) and menu.state == "TEXT" then
                    menu.state = "ITEMMENU"
                    Input.clear("confirm")
                    menu.box = LightItemMenu()
                    menu.box.layer = 1
                    menu:addChild(menu.box)
                    Kristal.Console:log(menu.state)
                end
                self:remove()
            end 
        end]]
        --self:addChild(self.check_text_obj)
    elseif Game.state == "BATTLE" then
        self.uibox = UIBox(0,0,w,h)
        self:addChild(self.uibox)

        self.icon_separator = UIBox(0,0,22,22)
        self:addChild(self.icon_separator)
    
        self.item_icon = Sprite("",self.icon_separator.width/2,self.icon_separator.height/2)
    
        self.item_description_text = ""
    
        self.item_icon:setScale(2)
        self.item_icon:setOrigin(0.5,0.5)
        self:addChild(self.item_icon)

        self.category_display = Text("[font:small]Test",343,-13,200,100, {align = "right"})
        self:addChild(self.category_display)
    end

    self._cwk_draw_font = Assets.getFont("main_mono",16)
end

function ItemDescBox:update()
    super.update(self)
    
    if Game.state == "OVERWORLD" then
        
    elseif Game.state == "BATTLE" then
        if Game.battle.state == "MENUSELECT" and #Game.battle.menu_items > 0 and Game.battle.state_reason == "ITEM" then
            self.currently_selecting = Game.inventory:getStorage("items")[Game.battle:getItemIndex()]
            if self.currently_selecting then
                local icon = self.currently_selecting.menu_icon
                if not self.item_icon:isSprite(icon) then
                    self.item_icon:setSprite(icon)
                end

                self.item_description_text = tostring(self.currently_selecting.description)
                self.category_text = self.currently_selecting.category or "[NIL]"
                local category_text = "[font:small]"..self.category_text
                if self.category_display.text ~= category_text then
                    self.category_display:setText(category_text, {align = "center"})
                end
            end
        end
    end
end

function ItemDescBox:draw()
    super.draw(self)

    love.graphics.setFont(self._cwk_draw_font)
    --love.graphics.print("* ",self.item_icon.x+48,self.item_icon.y-18)

    if Game.state == "OVERWORLD" then
        
    elseif Game.state == "BATTLE" then
        love.graphics.print(self.item_description_text,self.item_icon.x+48,self.item_icon.y-18)
    end
    
end

function ItemDescBox:setInfoText(text)
    local text_table = {}
    if type(text) == "table" then

        for _,v in ipairs(text) do
            table.insert(text_table,v)
        end

    else
        table.insert(text_table,text)
    end
    
    self.textbox:setText(text_table, function()
        local menu = Game.world.menu ---@type LightMenu
        if menu and menu:includes(LightMenu) and menu.state == "TEXT" then
            menu.state = "ITEMMENU"
            menu.box = LightItemMenu()
            menu.box.layer = 1
            menu:addChild(menu.box)
        end
        self:remove()
    end)
end

function ItemDescBox:setCategoryText(text)
    self.category_display = Text(text.."\n\n",0,0,500,500, {align = "right", auto_size = true, preprocess = false})
    self.category_display:setOrigin(1,0)
    self.category_display:setPosition(144,self.icon_separator.height/2-self.category_display.height/2)
    self.icon_separator:addChild(self.category_display)
end

function ItemDescBox:setDescription(text)
    local str = text:gsub('\n', ' ')


    --self.item_description_text = str
end

return ItemDescBox




