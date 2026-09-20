local LightMinigameWave, super = Class(LightWave)

function LightMinigameWave:init(popup_text, popup_controls, use_soul)
    super.init(self)

    self.has_soul = use_soul or false

    popup_text = popup_text or "Cook!"

    self.popup_txt = nil

    self.popup_msg = popup_text
    self.popup_ctrl = popup_controls or ""
end

function LightMinigameWave:popupInit()
    -- Wait for the arena to take shape, then spawn the popups
    -- This is called at line 689 of the lightbattle hook
    self:spawnPopupText(self.popup_msg, self.popup_ctrl)
end

function LightMinigameWave:spawnPopupText(text, controls)

    --Had to rewrite this entire thing, i'll comment it later, DM me if you're confused
    local txt_init_y = self.arena_y

    self.popup_txt = Game.battle:addChild(Text("[color:yellow]" .. text, self.arena_x, txt_init_y, SCREEN_WIDTH, 128, {align="center"}))

    self.popup_txt:setScale(1)
    self.popup_txt:setLayer(BATTLE_LAYERS["top"])
    self.popup_txt:setOrigin(0.5, 0)

    local controls_popup = Game.battle:addChild(ControlsDisplay(self.arena_x, self.arena_y, controls))

    controls_popup:setLayer(BATTLE_LAYERS["top"] - 1)
    controls_popup:setScale(0)
    controls_popup.y = controls_popup.y + controls_popup.height/2
    
    local arena_top = self.arena_y - (self.arena_height / 2)
    local arena_bottom = self.arena_y + (self.arena_height / 2)

    local txt_y_target = arena_top + (self.arena_height * (1/20))

    if self.popup_txt.y - txt_y_target > 110 then
        txt_y_target = self.popup_txt.y - 110
    end

    local txt_target_width = self.arena_width * (2/3)
    local txt_initial_width = self.popup_txt:getTextWidth()

    local txt_target_scale = txt_target_width / txt_initial_width

    if txt_target_scale > 3 then
        txt_target_scale = 3
    end

    local scaled_text_height = self.popup_txt.text_height * txt_target_scale
    local text_bottom = txt_y_target + scaled_text_height

    local ctrl_y_target = (text_bottom + arena_bottom) / 2
    local ctrl_target_width = self.arena_width

    local ctrl_initial_width = controls_popup.width
    local ctrl_initial_height = controls_popup.height

    local width_scale = ctrl_target_width / ctrl_initial_width

    local available_height = arena_bottom - text_bottom

    local ctrl_target_height = available_height

    local height_scale = ctrl_target_height / ctrl_initial_height

    local ctrl_target_scale = math.min(width_scale, height_scale)

    if ctrl_target_scale > 2.4 then
        ctrl_target_scale = 2
    elseif ctrl_target_scale < 1.2 then
        ctrl_target_scale = 1
    else
        ctrl_target_scale = 1.4
    end

    if ctrl_initial_width * ctrl_target_scale > self.arena_width/3 then
        ctrl_target_scale = 1.4
    elseif ctrl_initial_height * ctrl_target_scale > self.arena_height/3 then
        ctrl_target_scale = 1.4
    end

    local time = 0.4

    Game.battle.timer:tween(time, self.popup_txt, {y = txt_y_target,scale_x = txt_target_scale,scale_y = txt_target_scale}, "in-quad")

    Game.battle.timer:tween(time, controls_popup, {y = ctrl_y_target,scale_x = ctrl_target_scale,scale_y = ctrl_target_scale}, "in-quad")

    Game.battle.timer:after(1.5, function()
        self.popup_txt:remove()
        controls_popup:remove()
    end)
end

---Creates a text object containing a score message, moves it to a random spot, and fades it out
---@param text       string The text the score message will display
---@param x?         number The x-position to spawn the text at, defaults to the center of the arena
---@param y?         number The y-position to spawn the text at, defaults to the center of the arena
---@param dx_l?      number How far to the left the text could move, defaults to -100
---@param dx_r?      number How far to the right the text could move, defaults to 100
---@param dy?        number How far up the text will move, defaults to 100
---@param scale?     number The scale of the text, defaults to 3
---@param color?     table  Override the automatic color of the text, can use SCORECOLORS or just a hex code
function LightMinigameWave:scoreMessage(text, x, y, dx_l, dx_r, dy, scale, color)
    text = text or "MissingText!"
    x = x or self.arena_x
    y = y or self.arena_y
    dx_l = dx_l or -100
    dx_r = dx_r or 100
    dy = dy or 100
    scale = scale or 3

    -- Look at the first word in the scoretext, if it matches a common word, automatically set the color
    -- If there is a color override, don't do this
    if not color then
        if text == ":(" then
            text = "[font:score_lower]:("
            color = SCORECOLORS.red
        end
        for w in string.gmatch(text, "%a+") do
            w = string.lower(w) -- Set the tester string to all lowercase, so you only have to check one version of the word
            print(w)
            if w == "perfect" then
                color = SCORECOLORS.yellow
            elseif w == "great" then
                color = SCORECOLORS.green
            elseif w == "bad" or w == "too" or w == "miss" then
                color = SCORECOLORS.red
            end
            break
        end
    end

    -- Using lua black magic, I can insert the proper font calls into the string... in just one line!!
    -- Basically, it finds every instance of an uppercase letter, and adds "[font:score_caps]_[font:score_lower]" around it
    text = string.gsub(text, "(%u+)", "[font:score_caps]%1[font:score_lower]")
    --text = "[color:"..color.."]"..text -- Append "[color:color]" to the beginning of the string
    Kristal.Console:log(text)

    local message = self:spawnObject(Text(text, x, y, SCREEN_WIDTH, 128, {["align"] = "center"})) -- Spawn the text object
    message:setScale(scale)
    message:setOrigin(0.5,0)
    message:setLayer(BATTLE_LAYERS["top"])

    -- If, we have to change the text color, unpack the rgb of the color tables, and pass them through this colorizer function
    if color then
        local r_top, g_top, b_top = TableUtils.unpack(color.top)
        local r_bot, g_bot, b_bot = TableUtils.unpack(color.bot)
        MoistLib.colorizeFromGrayscale(message, r_top, g_top, b_top, r_bot, g_bot, b_bot)
    end

    -- Slide the text away and fade it out
    message:slideTo(message.x + love.math.random(dx_l, dx_r), message.y - dy, 1/3, "out-cubic", function()
        message:fadeOutAndRemove(0.5)
    end)
end

return LightMinigameWave