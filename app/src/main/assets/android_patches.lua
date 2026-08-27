-- android_patches.lua
-- Runtime compatibility hook system.
-- Loaded from the staged package after main.lua declares the game's callbacks.

local Patches = {}

function Patches.apply()
    -- Read patch flags injected by the Kotlin staging pipeline.
    local enableFullscreen = _G.PATCH_FULLSCREEN == true
    local enableShaders = _G.PATCH_SHADERS == true
    local enableGamepad = _G.PATCH_GAMEPAD == true
    local enableRgba16 = _G.PATCH_RGBA16 == true
    local enablePhysFs = _G.PATCH_PHYSFS == true
    local enableNilArithmetic = _G.PATCH_NIL_ARITHMETIC == true
    local enableBorders = _G.PATCH_BORDERS == true

    -- 1. FULLSCREEN PATCH (hook love.conf when available, then apply directly to love.window)
    if enableFullscreen then
        local orig_conf = love.conf
        love.conf = function(t)
            if orig_conf then orig_conf(t) end
            t.window = t.window or {}
            t.window.fullscreen = true
            t.window.fullscreentype = "desktop"
        end
        if love.window and love.window.setFullscreen then
            local success, message = love.window.setFullscreen(true, "desktop")
            if success == false then
                print("Kristal Launcher: fullscreen could not be enabled: " .. tostring(message))
            end
        end

        -- Keep the engine's option state synchronized with immersive fullscreen.
        local orig_load_fs = love.load
        love.load = function(...)
            if orig_load_fs then orig_load_fs(...) end
            if _G.Kristal and _G.Kristal.Config then _G.Kristal.Config["fullscreen"] = true end
        end
    end

    -- 2. PATCH SHADERS GLSL ES
    -- Each known GLSL ES compatibility issue has an independent fix that first checks
    -- whether the target pattern exists in the shader source. A fix leaves unrelated
    -- shaders unchanged instead of applying every transformation indiscriminately.
    if enableShaders then
        local orig_newShader = love.graphics.newShader

        -- Add ".0" to integer-literal arguments only inside the functions listed in
        -- `funcNames`. This deliberately avoids array sizes, indexes, and loop counters,
        -- which must remain integers in GLSL ES.
        local function fixIntLiteralArgs(code, funcNames)
            for _, fname in ipairs(funcNames) do
                local res = ""
                local idx = 1
                while true do
                    local s_idx, e_idx = code:find("%f[%w_]" .. fname .. "%s*%(", idx)
                    if not s_idx then
                        res = res .. code:sub(idx)
                        break
                    end
                    res = res .. code:sub(idx, e_idx)
                    idx = e_idx + 1

                    local p_level = 0
                    local last_arg_start = idx
                    for i = idx, #code do
                        local c = code:sub(i, i)
                        if c == "(" then
                            p_level = p_level + 1
                        elseif c == ")" then
                            if p_level == 0 then
                                local arg = code:sub(last_arg_start, i - 1)
                                if arg:match("^%s*%-?%d+%s*$") then
                                    res = res .. arg .. ".0"
                                else
                                    res = res .. arg
                                end
                                res = res .. ")"
                                idx = i + 1
                                break
                            end
                            p_level = p_level - 1
                        elseif c == "," and p_level == 0 then
                            local arg = code:sub(last_arg_start, i - 1)
                            if arg:match("^%s*%-?%d+%s*$") then
                                res = res .. arg .. ".0,"
                            else
                                res = res .. arg .. ","
                            end
                            last_arg_start = i + 1
                        end
                    end
                end
                code = res
            end
            return code
        end

        -- Each fix detects its own target pattern and returns the source unchanged when
        -- the corresponding compatibility issue is absent.
        local shaderFixes = {

            -- "sample" is reserved in GLSL ES 3.00 but not in LÖVE's default GLSL ES
            -- 1.00 mode, so rename it only when the shader declares glsl3 and uses the
            -- word as an identifier.
            {
                name = "reserved_word_sample",
                apply = function(s)
                    if not s:match("#pragma%s+language%s+glsl3") then
                        return s
                    end
                    if not s:find("%f[%w_]sample%f[^%w_]") then
                        return s
                    end
                    -- Avoid collisions when the replacement identifier already exists.
                    if s:find("%f[%w_]_smp_reserved_fix%f[^%w_]") then
                        return s
                    end
                    return s:gsub("%f[%w_]sample%f[^%w_]", "_smp_reserved_fix")
                end,
            },

            -- Some shaders use LÖVE's "number" alias for "float". Replace it only when
            -- the alias is present in the shader source.
            {
                name = "number_type_alias",
                apply = function(s)
                    if not s:find("%f[%w_]number%f[^%w_]") then
                        return s
                    end
                    return s:gsub("%f[%w_]number%f[^%w_]", "float")
                end,
            },

            -- Some mobile GLSL ES drivers reject mod() for particular argument types.
            -- Add the compatibility macro only when mod() is called and no mod macro
            -- already exists.
            {
                name = "mod_builtin_compat",
                apply = function(s)
                    if not s:find("%f[%w_]mod%s*%(") then
                        return s
                    end
                    if s:find("#define%s+mod%f[^%w_]") then
                        return s
                    end
                    local macro = "#define mod(x, y) ((x) - (y) * floor((x) / (y)))\n"
                    if s:match("^%s*#pragma%s+language") then
                        return (s:gsub("^(%s*#pragma%s+language[^\n]*\n)", "%1" .. macro, 1))
                    else
                        return macro .. s
                    end
                end,
            },

            -- Strict GLSL ES compilers may reject integer literals passed to functions
            -- expecting floats, such as mod(x, 1) or vec2(a, 0). Restrict conversion to
            -- selected call arguments so array sizes, indexes, and loop counters remain
            -- untouched.
            {
                name = "int_literal_args_to_float",
                apply = function(s)
                    local targets = {}
                    for _, fname in ipairs({ "mod", "max", "min", "vec2", "vec3", "vec4" }) do
                        if s:find("%f[%w_]" .. fname .. "%s*%(") then
                            table.insert(targets, fname)
                        end
                    end
                    if #targets == 0 then
                        return s
                    end
                    return fixIntLiteralArgs(s, targets)
                end,
            },

            -- Comparisons such as "color.a == 0" may fail when a compiler does not
            -- implicitly convert the integer literal to the color channel's float type.
            {
                name = "color_channel_equality",
                apply = function(s)
                    if not s:find("%.[rgba]%s*==%s*[01]%f[^%w_%.]") then
                        return s
                    end
                    s = s:gsub("(%.[rgba]%s*==%s*)0%f[^%w_%.]", "%10.0")
                    s = s:gsub("(%.[rgba]%s*==%s*)1%f[^%w_%.]", "%11.0")
                    return s
                end,
            },

            -- GLSL ES rejects initializers on uniform declarations, such as
            -- "uniform float tex_offset = 0;", even when desktop GLSL accepts them.
            -- LÖVE defines "extern" as a uniform alias, so both qualifiers require the
            -- same handling. Remove only the initializer while preserving qualifier,
            -- type, and name. A game that depends on the default must send the value
            -- through shader:send(...). Restrict matching to declaration lines so
            -- assignments and comparisons inside main()/effect() are never changed.
            {
                name = "uniform_initializer_strip",
                apply = function(s)
                    local pattern = "([ \t]*[Ee]xtern%s+[%w_]+%s+[%w_]+)%s*(=[^;]*)(;)"
                    local patternUniform = "([ \t]*uniform%s+[%w_]+%s+[%w_]+)%s*(=[^;]*)(;)"
                    local matched = false
                    if s:find(pattern) then
                        s = s:gsub(pattern, "%1%3")
                        matched = true
                    end
                    if s:find(patternUniform) then
                        s = s:gsub(patternUniform, "%1%3")
                        matched = true
                    end
                    if not matched then
                        return s
                    end
                    return s
                end,
            },
        }

        local function sanitizeGLSL(glsl)
            if type(glsl) == "string" and not glsl:find("\n") and #glsl < 256 then
                if love.filesystem.getInfo(glsl) then
                    local content = love.filesystem.read(glsl)
                    if content then glsl = content end
                end
            end

            if type(glsl) ~= "string" then return glsl end

            local s = glsl
            for _, fix in ipairs(shaderFixes) do
                local ok, result = pcall(fix.apply, s)
                if ok and type(result) == "string" then
                    s = result
                end
                -- If one fix fails or returns an unexpected value, keep the last valid
                -- source and continue instead of aborting the entire shader compilation.
            end
            return s
        end

        love.graphics.newShader = function(code, code2)
            if code and type(code) == "string" then
                code = sanitizeGLSL(code)
            end
            if code2 and type(code2) == "string" then
                code2 = sanitizeGLSL(code2)
            end

            return orig_newShader(code, code2)
        end
    end

    -- 3. PATCH RGBA16 -> RGBA8
    if enableRgba16 then
        local orig_newImage = love.graphics.newImage
        love.graphics.newImage = function(imageData, ...)
            local ok, img = pcall(orig_newImage, imageData, ...)
            if not ok and type(imageData) == "userdata" and imageData:type() == "ImageData" then
                local w, h = imageData:getWidth(), imageData:getHeight()
                local nd = love.image.newImageData(w, h)
                for y = 0, h - 1 do
                    for x = 0, w - 1 do
                        nd:setPixel(x, y, imageData:getPixel(x, y))
                    end
                end
                return orig_newImage(nd, ...)
            end
            if not ok then error(img) end
            return img
        end
    end

    -- 4. KRISTAL CLASS AND VIRTUAL-GAMEPAD PATCHES
    -- The script is injected before the Kristal Engine exists, so hooks that require
    -- initialized engine objects are installed from love.load.
    local orig_load = love.load
    love.load = function(...)
        if orig_load then orig_load(...) end

        -- A. PHYS FS STACK OVERFLOW
        if enablePhysFs and _G.FileSystemUtils then
            _G.FileSystemUtils.getFilesRecursive = function(dir, ext)
                local result = {}
                local stack = { { dir = dir, prefix = "" } }
                local visited_dirs = {}

                while #stack > 0 do
                    local current = table.remove(stack)
                    local curr_dir = current.dir
                    local curr_prefix = current.prefix
                    if not visited_dirs[curr_dir] then
                        visited_dirs[curr_dir] = true
                        local items = love.filesystem.getDirectoryItems(curr_dir)
                        if items then
                            local parent_items_str = table.concat(items, ",")
                            for _, item in ipairs(items) do
                                if item ~= "." and item ~= ".." then
                                    local full_path = (curr_dir == "" or curr_dir == ".") and item or (curr_dir .. "/" .. item)
                                    local rel_path = (curr_prefix == "") and item or (curr_prefix .. "/" .. item)
                                    local info = love.filesystem.getInfo(full_path)
                                    if info then
                                        if info.type == "directory" then
                                            local child_items = love.filesystem.getDirectoryItems(full_path)
                                            local child_items_str = child_items and table.concat(child_items, ",") or ""
                                            if child_items_str ~= "" and child_items_str ~= parent_items_str and not visited_dirs[full_path] then
                                                table.insert(stack, { dir = full_path, prefix = rel_path })
                                            end
                                        elseif info.type == "file" then
                                            if not ext or rel_path:sub(-#ext) == ext then
                                                local file_name = ext and rel_path:sub(1, -#ext - 1) or rel_path
                                                table.insert(result, file_name)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                return result
            end

            _G.FileSystemUtils.findFiles = function(folder, base, path)
                local base_folder = base or (folder .. "/")
                local path_prefix = path or ""
                local files = {}
                local stack = { { dir = folder, rel = path_prefix } }
                local visited = {}

                while #stack > 0 do
                    local curr = table.remove(stack)
                    if not visited[curr.dir] then
                        visited[curr.dir] = true
                        local items = love.filesystem.getDirectoryItems(curr.dir)
                        if items then
                            local parent_str = table.concat(items, ",")
                            for _, f in ipairs(items) do
                                if f ~= "." and f ~= ".." then
                                    local full_path = curr.dir .. "/" .. f
                                    local info = love.filesystem.getInfo(full_path)
                                    if info then
                                        if info.type == "directory" then
                                            local rel_item = curr.rel .. (f:gsub(base_folder, "", 1))
                                            table.insert(files, rel_item)
                                            local new_rel = curr.rel .. f .. "/"
                                            local child_items = love.filesystem.getDirectoryItems(full_path)
                                            local child_str = child_items and table.concat(child_items, ",") or ""
                                            if child_str ~= "" and child_str ~= parent_str and not visited[full_path] then
                                                table.insert(stack, { dir = full_path, rel = new_rel })
                                            end
                                        elseif info.type == "file" then
                                            table.insert(files, ((full_path):gsub(base_folder, "", 1)))
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                return files
            end
        end

        -- B. NIL ARITHMETIC (MainMenuOptions & Music)
        if enableNilArithmetic then
            if _G.Kristal and _G.Kristal.Config then
                if _G.Kristal.Config.menuPitch == nil then _G.Kristal.Config.menuPitch = 1.0 end
                if _G.Kristal.Config.menuSong == nil then _G.Kristal.Config.menuSong = 1 end
            end
            if _G.Music then
                local orig_setPitch = _G.Music.setPitch
                if type(orig_setPitch) == "function" then
                    _G.Music.setPitch = function(self, pitch)
                        return orig_setPitch(self, pitch or 1)
                    end
                end
                local orig_setVolume = _G.Music.setVolume
                if type(orig_setVolume) == "function" then
                    _G.Music.setVolume = function(self, vol)
                        return orig_setVolume(self, vol or 1)
                    end
                end
            end
        end

        -- C. BORDERS
        if enableBorders and _G.ImageBorder then
            if _G.Kristal and _G.Kristal.Config then _G.Kristal.Config["borders"] = "dynamic" end
            local orig_border_draw = _G.ImageBorder.draw
            _G.ImageBorder.draw = function(self)
                if orig_border_draw then
                    local ok, err = xpcall(function()
                        orig_border_draw(self)
                    end, debug.traceback)
                    if not ok then
                        print("Kristal Launcher: using the Android border fallback after an engine error:\n" .. tostring(err))
                    end
                end

                if self.texture and (self.alpha or 1) > 0 then
                    local bw = _G.BORDER_WIDTH or 0
                    local bs = _G.BORDER_SCALE or 1
                    _G.Draw.draw(self.texture, 0, 0, 0, -bs, bs)
                    _G.Draw.draw(self.texture, 2 * bw * bs, 0, 0, -bs, bs)
                end
            end
        end

        -- D. VIRTUAL GAMEPAD
        if enableGamepad then
            require("kristal_launcher.gamepad.main").hook()
        end
    end
end

Patches.apply()
return Patches
