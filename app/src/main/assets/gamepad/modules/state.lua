local state = {}

-- Window Config & Screen Mode
state.BASE_W, state.BASE_H = 640, 480
state.SW, state.SH = 640, 480
state.screenMode = 1

-- Control Defaults
state.defaultZx = 0
state.defaultZy = 0
state.defaultXx = 0
state.defaultXy = 0
state.defaultCx = 0
state.defaultCy = 0
state.defaultJx = 0
state.defaultJy = 0

state.settings_x = 0
state.settings_y = 0
state.settings_z = 0
state.speedUp_x = 0
state.speedUp_y = 0

state.speedUp_isActive = false
state.speedUp_hide = true
state.next_key_state = { 0, 0, 0, 0, 0, 0, 0 }
state.next_joystick_fade = { 0 }
state.pointerPool = {}
state.settings_hide = false

state.enable_pop_animations = true
state.pop_timer = 0
state.pops_done = false
state.pops = {
    joy = { s = 0, v = 0, delay = 0.00 },
    z   = { s = 0, v = 0, delay = 0.05 },
    x   = { s = 0, v = 0, delay = 0.10 },
    c   = { s = 0, v = 0, delay = 0.15 },
    s   = { s = 0, v = 0, delay = 0.20 },
    su  = { s = 0, v = 0, delay = 0.25 }
}

state.defaultColor = 1
state.touchscreen_scale = { 2.5, 2.5 }
state.touchscreen_deadzone = 0.5
state.touchscreen_type = 2
state.touchscreen_opacity = 0.7
state.touchscreen_color = 1
state.con = 0
state.config_changed = false

state.touchscreen_x = { 0, 0, 0, 0, 0 }
state.touchscreen_y = { 0, 0, 0, 0, 0 }

state.image_alpha = 0.7
state.settings_alpha = 0

-- Reworked settings UI state
-- Optional button appearance selector.
-- true = hidden (default); false = visible. The Visual tab always remains available.
state.disable_appearance_selector = true
state.menu_page = "controls"
state.menu_return_con = 0
state.menu_pointer = nil
state.menu_pressed_action = nil
state.menu_slider_action = nil
state.menu_reset_confirm = false
state.menu_fonts = nil
state.editor_pointer = nil
state.editor_pressed_action = nil

state.joybase_x = { 0 }
state.joybase_y = { 0 }
state.joystick_x = { 0 }
state.joystick_y = { 0 }
state.joystick_alpha = { 0 }

state.key_state = { 0, 0, 0, 0, 0, 0, 0 }
state.VIRTUAL_KEYS = {
    [1] = "left",
    [2] = "up",
    [3] = "right",
    [4] = "down",
    [5] = "z",
    [6] = "x",
    [7] = "c",
}

state.held = { nil, nil, nil, nil, nil, nil }
state.currentPointers = {}
state.prevPointersDown = {}

state.spr = {
    jb = {},
    js = {},
    z = {},
    x = {},
    c = {},
    s = {},
    su = {},
    dp = {}
}

-- Responsive layout metadata. storage.lua fills/migrates these automatically.
state.layout_custom = {}
state.layout_offset_x = {}
state.layout_offset_y = {}
state.layout_last_gui_w = 640
state.layout_last_gui_h = 480

state.script_folder = ""

return state
