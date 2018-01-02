#!/bin/bash
_= # --[[
#     Copyright (C) 2017,2018   Frank Fuhlbrück <frank@fuhlbrueck.net>
#
#     This program is free software; you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation; either version 2 of the License, or
#     (at your option) any later version.
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#     You should have received a copy of the GNU General Public License along
#     with this program; if not, write to the Free Software Foundation, Inc.,
#     51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

LUA=lua
LUA_PATH=$($LUA -e "print(package.path)")
export LUA_PATH="$LUA_PATH;$(dirname $(realpath $0))/../?.lua"
lua $0 $*
exit
]]{}

local makeclass = require("klangtrabant.ktCommon").makeclass
local dcopy = require("klangtrabant.ktCommon").dcopy
local word16ToBytes = require("klangtrabant.ktCommon").word16ToBytes
local Macro = require("klangtrabant.Macro")
local Command = require("klangtrabant.Command")
local Book = require("klangtrabant.Book")

actions = {
help = function(_)
    io.write([[
Usage: klangtrabant ACTION ARGUMENTS

where ACTION and ARGUMENTS can have the following forms:
    * help: show this help page

    * oufToSource OUFFILE SRCFILE: convert an ouf to a source file
        All mp3 files are stored in the current working directory

    * sourceToOuf SRCFILE MID OUFFILE: compile a src to an ouf file
        MID specifies the medium ID

    * fetch MID SAVEDIR: get .ouf,.png,.txt and if available .src
        from the official ting server.
        MID specifies the medium ID.
        This action needs "wget" installed.

]])
end,

fetch = function(_,id,dir)
dir = dir or "."
local url = "http://system.ting.eu/book-files"
os.execute("wget " .. url .. "/get-description/id/"..id.."/area/en -O "..
    dir .. "/" .. id .. "_en.txt")
os.execute("wget " .. url .. "/get/id/"..id.."/area/en/type/thumb -O "..
    dir .. "/" .. id .. "_en.png")
os.execute("wget " .. url .. "/get/id/"..id.."/area/en/type/archive -O "..
    dir .. "/" .. id .. "_en.ouf")
os.execute("wget " .. url .. "/get/id/"..id.."/area/en/type/script -O "..
    dir .. "/" .. id .. "_en.src")
end,

oufToSource = function(_,oufFile,srcFile)
    assert(oufFile and srcFile,"oufToScript requires two arguments")
    local book = Book.fromOuf(oufFile)
    local srcStr = book:toSource(true)
    local f = io.open(srcFile,"w")
    f:write(srcStr)
    f:close()
end,

sourceToOuf = function(_,srcFile,id,oufFile)
    assert(oufFile and srcFile,"sourceToOuf requires two arguments")
    local f = io.open(srcFile,"r")
    local srcStr = f:read("*all")
    f:close()
    local book = Book.fromSource(srcStr,{id=id})
    book:toOuf(oufFile)
end,
}

(actions[arg[1]] or actions.help)(table.unpack(arg))
