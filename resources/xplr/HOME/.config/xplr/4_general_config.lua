-- 4_styling
xplr.config.general.focus_ui.style.bg = "DarkGray"
xplr.config.general.focus_selection_ui.style.bg = "DarkGray"
xplr.fn.builtin.fmt_general_table_row_cols_4 = function(m)
    return tostring(os.date("%Y-%m-%d  %H:%M", m.last_modified / 1000000000))
end
xplr.config.general.show_hidden = true

-- The function below overrides the original function from
-- https://github.com/sayanarijit/xplr/blob/main/src/init.lua
-- in order to not set colors for permissions
xplr.fn.builtin.fmt_general_table_row_cols_2 = function(m)
    local no_color = os.getenv("NO_COLOR")

    local function green(x)
        if no_color == nil then
            return "" .. x .. ""
        else
            return x
        end
    end

    local function yellow(x)
        if no_color == nil then
            return "" .. x .. ""
        else
            return x
        end
    end

    local function red(x)
        if no_color == nil then
            return "" .. x .. ""
        else
            return x
        end
    end

    local function bit(x, color, cond)
        if cond then
            return color(x)
        else
            return color("-")
        end
    end

    local p = m.permissions

    local r = ""

    r = r .. bit("r", green, p.user_read)
    r = r .. bit("w", yellow, p.user_write)

    if p.user_execute == false and p.setuid == false then
        r = r .. bit("-", red, p.user_execute)
    elseif p.user_execute == true and p.setuid == false then
        r = r .. bit("x", red, p.user_execute)
    elseif p.user_execute == false and p.setuid == true then
        r = r .. bit("S", red, p.user_execute)
    else
        r = r .. bit("s", red, p.user_execute)
    end

    r = r .. bit("r", green, p.group_read)
    r = r .. bit("w", yellow, p.group_write)

    if p.group_execute == false and p.setuid == false then
        r = r .. bit("-", red, p.group_execute)
    elseif p.group_execute == true and p.setuid == false then
        r = r .. bit("x", red, p.group_execute)
    elseif p.group_execute == false and p.setuid == true then
        r = r .. bit("S", red, p.group_execute)
    else
        r = r .. bit("s", red, p.group_execute)
    end

    r = r .. bit("r", green, p.other_read)
    r = r .. bit("w", yellow, p.other_write)

    if p.other_execute == false and p.setuid == false then
        r = r .. bit("-", red, p.other_execute)
    elseif p.other_execute == true and p.setuid == false then
        r = r .. bit("x", red, p.other_execute)
    elseif p.other_execute == false and p.setuid == true then
        r = r .. bit("T", red, p.other_execute)
    else
        r = r .. bit("t", red, p.other_execute)
    end

    return r
end
