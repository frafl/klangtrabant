--[[
    Copyright (C) 2017,2018   Frank Fuhlbrück <frank@fuhlbrueck.net>
  
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


local makeclass = require("klangtrabant.ktCommon").makeclass
local dcopy = require("klangtrabant.ktCommon").dcopy
local word16ToBytes = require("klangtrabant.ktCommon").word16ToBytes

local ocTable, idTable = {}, {}

local Command
Command = {
    new = function(opcode,id,asm,arg1,arg2,desc,val1,val2)
        if type(opcode) == "table" then
            return Command.new(table.unpack(opcode))
        end
        if not arg1 then--no desc, i.e. instance of known command
            --id,asm are actually values
            if type(opcode) == "string" then--opcode is ID
                return Command.fromId(opcode,id,asm)
            else
                return Command.fromOpcode(opcode,id,asm)
            end
        end
        --really new command, but possible with fewer than 2 args
        if not arg2 then
            desc = arg1
            arg1 = nil
        end
        if not desc then
            desc = arg2
            arg2 = nil
        end
        
        local cmd = {opcode=opcode,id=id,asm=asm,
            desc=desc,arg1=arg1,arg2=arg2,val1=val1,val2=val2,
            nargs=(arg2 and 2) or (arg1 and 1) or 0}
        setmetatable(cmd,Command)
        return cmd
    end,
    
    fromOpcode = function(opcode,val1,val2)
        local cmd = dcopy(ocTable[opcode])
        if cmd then
            cmd.val1,cmd.val2 = val1,val2
            setmetatable(cmd,Command)
        end
        return cmd
    end,
    
    fromId = function(id,val1,val2)
        local cmd = dcopy(idTable[id])
        if cmd then
            cmd.val1,cmd.val2 = val1,val2
            setmetatable(cmd,Command)
        end
        return cmd
    end,
    
    __tostring = function(cmd)
        local s = cmd.asm
        if cmd.arg1 == "R" then
            s = s .. " v" .. cmd.val1
        elseif cmd.arg1 == "V" or cmd.arg1 == "L" then
            s = s .. " " .. cmd.val1
        else
            return s
        end
        if cmd.arg2 == "R" then
            return s .. ",v" .. cmd.val2
        elseif cmd.arg2 == "V" then
            return s .. "," .. cmd.val2
        else
            return s
        end
    end,
    
    tobytecode = function(cmd)
        local b = {}
        b[1],b[2] = word16ToBytes(cmd.opcode)
        if cmd.arg1 == "R" or cmd.arg1 == "V" then
            b[3],b[4] = word16ToBytes(cmd.val1)
        elseif cmd.arg1 == "L" then
            assert(cmd.labelList,
                "Cannot create bytecode for jump without labellist")
            b[3],b[4] = word16ToBytes(cmd.labelList[cmd.val1])
            return string.char(table.unpack(b))
        else
            return string.char(table.unpack(b))
        end
        if cmd.arg2 then
            b[5],b[6] = word16ToBytes(cmd.val2)
        end
        return string.char(table.unpack(b))
    end,
    
    nbytes = function(cmd)
        if cmd.arg2 then
            return 6
        elseif cmd.arg1 then
            return 4
        else
            return 2
        end
    end
}
makeclass(Command)

local initCmd = {
    {0x0000,"end","end","ends the script"},
    {0x0100,"clearver","clearver","sets all variables to 0."},
    {0x0201,"setRV","set","R","V",
        "sets first argument to second argument."},
    {0x0202,"setRR","set","R","R",
        "sets first argument to content of second argument."},
    {0x0301,"cmpRV","cmp","R","V",
        "compares a register to a value"},
    {0x0302,"cmpRR","cmp","R","R",
        "compares a register to another register"},
    {0x0401,"andRV","and","R","V",
        "computes bitwise and with given value"},
    {0x0402,"andRR","and","R","R",
        "computes bitwise and with content of given register"},
    {0x0501,"orRV","or","R","V",
        "computes bitwise or with given value"},
    {0x0502,"orRR","or","R","R",
        "computes bitwise or with content of given register"},
    --"not" actually uses only one argument, the second is ignored
    --notRR will replace notRV in ocTable, so only the second one
    --is accessibly via opcode
    {0x0602,"notRV","not","R","R",
        "negates the first argument bitwise"},
    {0x0602,"notRR","not","R","R",
        "negates the first argument bitwise"},
    {0x0800,"jmpL","jmp","L","unconditionally jumps to label"},
    {0x0900,"jeL","je","L",
        "jumps if last comparison resulted in equality"},
    {0x0A00,"jneL","jne","L",
        "jumps if last comparison resulted in inequality"},
    {0x0B00,"jgL","jg","L",
        "jumps if last comparison resulted in \"greater\""},
    {0x0C00,"jgeL","jge","L",
        "jumps if last comparison resulted in \"greater or equal\""},
    {0x0D00,"jbL","jb","L",
        "jumps if last comparison resulted in \"below\""},
    {0x0E00,"jbeL","jbe","L",
        "jumps if last comparison resulted in \"below or equal\""},
    {0x0F01,"addRV","add","R","V",
        "adds second argument to first argument."},
    {0x0F02,"addRR","add","R","R",
        "adds content of second argument to first argument."},
    {0x1001,"subRV","sub","R","V",
        "subtracts second argument from first argument."},
    {0x1002,"subRR","sub","R","R",
        "subtracts content of second argument from first argument."},
    {0x1400,"return","return","returns from subprocedure"},
    {0x1501,"callidV","callid","V","imitates choice by pen"},
    {0x1502,"callidR","callid","R","imitates choice by pen"},
    {0xFFFF,"callV","call","V",
        "replaces itself with content of subprocedure"},
    {0x1601,"playoidV","playoid","V",
        "activates a given oid and returns"},
    {0x1602,"playoidR","playoid","R",
        "activates a given oid and returns"},
    {0x1701,"pauseV","pause","V","pauses for x/10 seconds"},
    {0x1702,"pauseR","pause","R","pauses for x/10 seconds"}
}

for i=1,#initCmd do
    local cmd = Command(initCmd[i])
    ocTable[initCmd[i][1]] = cmd
    idTable[initCmd[i][2]] = cmd
end

return Command
