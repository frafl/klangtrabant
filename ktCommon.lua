--[[
    Copyright (C) 2017   Frank Fuhlbrück <frank@fuhlbrueck.net>
  
    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
  
]]


local lpeg = require "lpeg"
getModuleTex = function(module)
    for s in package.path:gmatch("[^;]+") do
        s = s:gsub("?",module)
        local f = io.open(s,"r")
        if f then
            f:close()
            return dofile(s)
        end
    end
end
local re = getModuleTex("re")


local concatWithToString = function(t1,t2)
    return  tostring(t1) ..  tostring(t2)
end

local makeclass = function(c)
    setmetatable(c, {
        __call = function (cls, ...)
            return cls.new(...)
        end,
    })
    --[[normal and metamethods can be defined in the same class
    table as this table is metatable and fallback table]]
    if c.__index == nil then
        c.__index = c
    end

    if c.__concat == nil then
        c.__concat = concatWithToString
    end
end

--l depth, copies only values
function dcopy(t,l)
    l = l or 1
    if type(t) == 'table' and l > 0 then
        local ret = {}
        for k,v in pairs(t) do
            ret[k] =  dcopy(v,l-1)
        end
        return ret
    else
        return t
    end
end

local word16ToBytes = function(w)
    local l = w % 256
    local m = (w - l)/256
    return m,l
end

local compileTable = function(grammarTbl,defs)
    local initgr = grammarTbl[1]
    local grStr = ""
    for k,v in pairs(grammarTbl) do
        if k ~= initgr and k ~= 1 then
            grStr = grStr .. k .. " <- (" .. v ..")\n"
        elseif k == initgr then
            grStr = k .. " <- (" .. v ..")\n" .. grStr
        end
    end
    return re.compile(grStr,defs)
end

return {
    makeclass=makeclass,
    dcopy=dcopy,
    word16ToBytes=word16ToBytes,
    compileTable=compileTable,
    re=re
}


