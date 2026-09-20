local lib = {}

local translations_patterns = {
    --  экран ВЕЩИ
    { "^USE$", "ИСП" },
    { "^TOSS$", "БРОС" },
    { "^KEY$", "КЛЮЧ" },

    --  экран ЭКИПИРОВКА И МАГИЯ
    { "^Attack:$", "Атака:" },
    { "^Defense:$", "Защита:" },
    { "^Magic:$", "Магия:" },
    { "No ability.", "Нет умения." },
    { "^Yes$", "Да" },
    { "^No$", "Нет" },

    --  экран НАСТРОЙКИ
    { "^CONFIG$", "НАСТРОЙКИ" },
    { "^OFF$", "ВЫКЛ" },
    { "^ON$", "ВКЛ" },
    { "^Master Volume$", "Громкость" },
    { "^Controls$", "Управление" },
    { "^Simplify VFX$", "Упрощённый VFX" },
    { "^Fullscreen$", "Полный экран" },
    { "^Auto%-Run$", "Авто-бег" },
    { "^Return to Title$", "В главное меню" },
    { "^Back$", "Назад" },

    --  экран УПРАВЛЕНИЕ
    { "^Function", "Функция" },
    { "^Key", "Кнопка" },
    { "^DOWN", "ВНИЗ" },
    { "^RIGHT", "ВПРАВО" },
    { "^UP$", "ВВЕРХ" },
    { "^LEFT$", "ВЛЕВО" },
    { "^CONFIRM$", "ПРИНЯТЬ" },
    { "^CANCEL$", "ОТМЕНА" },
    { "^MENU$", "МЕНЮ" },
    { "^Reset to default$", "Сбросить настройки" },
    { "^Finish$", "Сохранить" },

    --  экран СОХРАНЕНИЯ
    { "^Save$", "Сохранить" },
    { "^Return$", "Вернуться" },
    { "^Storage$", "Склад" },
    { "^Recruits$", "Жители" },
    { "^New File$", "Новый файл" },
    { "^File Saved$", "Файл сохранен" },
    { "LV (%d+)", "УР %1" },
    { "Overwrite Slot (%d+)%?", "Перезаписать слот %1?" },

    --  экран СКЛАД
    { "^POCKET$", "КАРМАНЫ" },
    { "^STORAGE$", "СКЛАД" },
    { "^Page$", "Стр." },
    
    --  экран БИТВЫ
    { "^HP$", "ОЗ" },
    { "^MERCY$", "ПОЩАДА" },
    { "^Check$", "Проверить" },
    { "^(Tired)$", "(Устал)" },





}

Utils.hook(love.graphics, "print", function(orig, text, ...)
    if type(text) == "string" then
        for _, pat in ipairs(translations_patterns) do
            local find, repl = pat[1], pat[2]
            if text:match(find) then
                text = text:gsub(find, repl)
                break
            end
        end
    end
    return orig(text, ...)
end)

Utils.hook(Encounter, "getVictoryText", function(orig, self, text, money, xp)
    -- переводим слова
    text = text:gsub("You won!", "Победа!")
    text = text:gsub("Got " , "Получено ")
    -- переводим EXP и Т$
    text = text:gsub("(%d+) EXP and (%d+) (%S+)%." , "%1 ОП и %2 %3.")
    -- переводим геноцид 
    text = text:gsub("(%w+) became stronger", "Вы стали сильнее")
    return text
end)

Utils.hook(EnemyBattler, "getSpareText", function(orig, self, battler, success)
    local text = orig(self, battler, success)

    local function translate_line(line)
        if type(line) ~= "string" then return line end

        -- перевод ключевых слов
        line = line:gsub("spared", "щадит")
        line = line:gsub("But its name wasn't", "Но его имя не было")
        line = line:gsub("Try using", "Попробуй использовать")
        line = line:gsub("ACTs", "ДЕЙСТВИЯ")
        line = line:gsub("YELLOW", "ЖЁЛТЫЙ")

        return line
    end

    if type(text) == "table" then
        for i, line in ipairs(text) do
            text[i] = translate_line(line)
        end
    else
        text = translate_line(text)
    end

    return text
end)

Utils.hook(Spell, "getCastMessage", function(orig, self, user, target)
    local text = orig(self, user, target)

    -- переводим ключевое слово
    text = text:gsub(" cast ", " использует ")

    return text
end)

return lib