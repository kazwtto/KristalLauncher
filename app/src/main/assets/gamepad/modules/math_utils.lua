local math_utils = {}

function math_utils.point_distance(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

function math_utils.point_direction(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dir = math.atan2(-dy, dx) * 180 / math.pi
    if dir < 0 then dir = dir + 360 end
    return dir
end

function math_utils.lengthdir_x(len, dir)
    return len * math.cos(dir * math.pi / 180)
end

function math_utils.lengthdir_y(len, dir)
    return -len * math.sin(dir * math.pi / 180)
end

function math_utils.lerp(a, b, t)
    return a + (b - a) * t
end

function math_utils.clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

return math_utils
