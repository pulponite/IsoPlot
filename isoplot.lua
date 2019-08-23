----------------------------------------------------------------------
-- A simple iso rectangle plotter to help with plotting non-axis-
-- aligned boxes.
----------------------------------------------------------------------

--[[
    3x3 Matrix -
    {data = {
        m11, m12, m13,
        m21, m22, m23,
        m31, m32, m33
    }}
]]
local matrix = {}
local matrix_mt = {__index = matrix}

function matrix.identity()
    local m = {
        data = {
            1, 0, 0,
            0, 1, 0,
            0, 0, 1
        }
    }
    setmetatable(m, matrix_mt)
    return m
end

function matrix.rotx(angle)
    local rad = math.rad(angle)
    local m = {
        data = {
            1, 0, 0,
            0, math.cos(rad), -math.sin(rad),
            0, math.sin(rad), math.cos(rad)
        }
    }
    setmetatable(m, matrix_mt)
    return m
end

function matrix.rotz(angle)
    local rad = math.rad(angle)
    local m = {
        data = {
            math.cos(rad), -math.sin(rad), 0,
            math.sin(rad), math.cos(rad), 0,
            0, 0, 1
        }
    }
    setmetatable(m, matrix_mt)
    return m
end

function matrix:mult_matrix(other)
    local m = { data = {
        (self.data[1] * other.data[1]) + (self.data[2] * other.data[4]) + (self.data[3] * other.data[7]),
        (self.data[1] * other.data[2]) + (self.data[2] * other.data[5]) + (self.data[3] * other.data[8]),
        (self.data[1] * other.data[3]) + (self.data[2] * other.data[6]) + (self.data[3] * other.data[9]),

        (self.data[4] * other.data[1]) + (self.data[5] * other.data[4]) + (self.data[6] * other.data[7]),
        (self.data[4] * other.data[2]) + (self.data[5] * other.data[5]) + (self.data[6] * other.data[8]),
        (self.data[4] * other.data[3]) + (self.data[5] * other.data[6]) + (self.data[6] * other.data[9]),

        (self.data[7] * other.data[1]) + (self.data[8] * other.data[4]) + (self.data[9] * other.data[7]),
        (self.data[7] * other.data[2]) + (self.data[8] * other.data[5]) + (self.data[9] * other.data[8]),
        (self.data[7] * other.data[3]) + (self.data[8] * other.data[6]) + (self.data[9] * other.data[9]),
    } }
    setmetatable(m, matrix_mt)
    return m
end

function matrix:mult_vec(vec)
    local v = {
        (self.data[1] * vec[1]) + (self.data[2] * vec[2]) + (self.data[3] * (vec[3] or 0)),
        (self.data[4] * vec[1]) + (self.data[5] * vec[2]) + (self.data[6] * (vec[3] or 0)),
        (self.data[7] * vec[1]) + (self.data[8] * vec[2]) + (self.data[9] * (vec[3] or 0))
    }
    return v
end

local function vec_len(v)
    return math.sqrt((v[1] ^ 2) + (v[2] ^ 2) + ((v[3] or 0) ^ 2))
end

local function vec_dot(v1, v2)
    return (v1[1] * v2[1]) + (v1[2] * v2[2]) + ((v1[3] or 0) * (v2[3] or 0))
end

local function vec_intersect_plane(v, p, n)
    local d = vec_dot(p, n) / vec_dot(v, n)
    return {v[1] * d, v[2] * d, (v[3] or 0) * d}
end

local dlg = Dialog("IsoPlot")

local function round(n)
    return n % 1 >= 0.5 and math.ceil(n) or math.floor(n)
end

local function translate(p, t)
    return {p[1] + t[1], p[2] + t[2]}
end

local function get_direction(p1, p2)
    return {p2[1] - p1[1], p2[2] - p1[2]}
end

local function attempt_fudge(s, r)
    if r[1] < 0 or (r[1] == 0 and r[2] > 0) then
        return translate(s, {-1, 0})
    end
    return s
end

local function plot_line(p1, p2)
    local dir = get_direction(p1, p2)

    p1 = attempt_fudge(p1, dir)
    p2 = attempt_fudge(p2, dir)

    app.useTool{
        tool="line",
        color=app.fgColor,
        brush=Brush(1),
        points={Point(round(p1[1]), round(p1[2])), Point(round(p2[1]), round(p2[2]))}
    }
end

local function center_quad(points)
    local minx, miny, maxx, maxy = 100, 100, -100, -100
    for i,p in ipairs(points) do
        if p[1] < minx then
            minx = p[1]
        end
        if p[1] > maxx then
            maxx = p[1]
        end
        if p[2] < miny then
            miny = p[2]
        end
        if p[2] > maxy then
            maxy = p[2]
        end
    end

    local width = maxx - minx
    local height = maxy - miny

    local bw, bh = app.activeSprite.width, app.activeSprite.height

    local offsetx = ((bw / 2) - (width / 2)) - minx
    local offsety = ((bh / 2) - (height / 2)) - miny

    for i,p in ipairs(points) do
        p[1] = p[1] + offsetx
        p[2] = p[2] + offsety
    end
end

local function make_shape()
    local m = matrix.identity()
    m = m:mult_matrix(matrix.rotx(60))
    m = m:mult_matrix(matrix.rotz(dlg.data.rotation))

    local raxis = m:mult_vec({1, 0})
    local rangle = math.atan(raxis[2] / raxis[1])
    local xlen = (dlg.data.right - 1) / math.cos(rangle)
    local rpoint = {xlen * math.cos(rangle), xlen * math.sin(rangle), 0}
    local rpoint2 = vec_intersect_plane(raxis, rpoint, {1, 0, 0})
    local xlen2 = vec_len(rpoint2)

    local baxis = m:mult_vec({0, 1})
    local bangle = math.abs(math.atan(baxis[2] / baxis[1]))
    local ylen = ((dlg.data.bottom - 1) - (xlen * math.sin(rangle))) / math.sin(bangle)
    local bpoint = {ylen * -math.cos(bangle), ylen * -math.sin(bangle), 0}
    local bpoint2 = vec_intersect_plane(baxis, bpoint, {0, 1, 0})
    local ylen2 = vec_len(bpoint2)

    local p1 = {0, 0}
    local p2 = {0, ylen2}
    local p3 = {xlen2, ylen2}
    local p4 = {xlen2, 0}

    p1 = translate(m:mult_vec(p1), {0.5, 0.5})
    p2 = translate(m:mult_vec(p2), {0.5, 0.5})
    p3 = translate(m:mult_vec(p3), {0.5, 0.5})
    p4 = translate(m:mult_vec(p4), {0.5, 0.5})

    center_quad({p1, p2, p3, p4})

    app.transaction( function()
        app.command.NewLayer()
        plot_line(p1, p2)
        plot_line(p1, p4)
        plot_line(p3, p2)
        plot_line(p3, p4)
    end )

    app.refresh()
end

dlg
    :separator{text="Object Creation Settings"}
    :slider{id="rotation", label="Rotation:", min=0, max=89, value=45}
    :slider{id="right", label="Left:", min=0, max=app.activeSprite.width / 2, value=7}
    :slider{id="bottom", label="Top:", min=0, max=app.activeSprite.height / 2, value=7}
    :separator()
    :button{text="Make Shape",onclick=function() make_shape() end}
    :show{wait=false}