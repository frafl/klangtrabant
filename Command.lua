--[[
    Copyright (C) 2015        Martin Dames <martin@bastionbytes.de>
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
            assert(cmd.labelList,"Cannot create bytecode for jump without labellist")
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
    {0x0000,"end","end","Programmende"},
    {0x0100,"clearver","clearver","Löscht alle Variablen"},
    {0x0201,"setRV","set","R","V","Setzt ein Register auf einen Wert"},
    {0x0202,"setRR","set","R","R","Kopiert ein Register in ein anderes"},
    {0x0301,"cmpRV","cmp","R","V","Vergleich zw. einem Register und einem Wert"},
    {0x0302,"cmpRR","cmp","R","R","Vergleich zw. zwei Registern"},
    {0x0401,"andRV","and","R","V","Binäre-Verundung eines Registers mit einem Wert"},
    {0x0402,"andRR","and","R","R","Binäre-Verundung eines Registers mit einem anderen Register"},
    {0x0501,"orRV","or","R","V","Binäre-Veroderung eines Registers mit einem Wert"},
    {0x0502,"orRR","or","R","R","Binäre-Veroderung eines Registers mit einem anderen Register"},
    --not actually uses only one argument, the second is ignored
    --notRR will replace notRV in ocTable, so only the second one
    --is accessibly via opcode
    {0x0602,"notRV","not","R","R","Binäre-Verneinung eines Registers"},
    {0x0602,"notRR","not","R","R","Binäre-Verneinung eines Registers"},
    {0x0800,"jmpL","jmp","L","Sprung"},
    {0x0900,"jeL","je","L","bedingter Sprung bei Gleichheit"},
    {0x0A00,"jneL","jne","L","bedingter Sprung bei Ungleichheit"},
    {0x0B00,"jgL","jg","L","bedingter Sprung wenn größer"},
    {0x0C00,"jgeL","jge","L","bedingter Sprung wenn größer oder gleich"},
    {0x0D00,"jbL","jb","L","bedingter Sprung wenn kleiner"},
    {0x0E00,"jbeL","jbe","L","bedingter Sprung wenn kleiner oder gleich"},
    {0x0F01,"addRV","add","R","V","Addiert einen Wert zu einem Register"},
    {0x0F02,"addRR","add","R","R","Addiert ein Register zu einem anderen"},
    {0x1001,"subRV","sub","R","V","Subtrahiert einen Wert von einem Register"},
    {0x1002,"subRR","sub","R","R","Subtrahiert ein Register von einem anderen Register"},
    {0x1400,"return","return","Rücksrung aus einer Unterroutine"},
    {0x1501,"callidV","callid","V","Auswahl nach ID"},
    {0x1502,"callidR","callid","R","Auswahl nach ID"},
    {0xFFFF,"callV","call","V","Prozeduraufruf nach OID"},
    {0x1601,"playoidV","playoid","V","Spielt eine OID, gegeben als Wert, ab"},
    {0x1602,"playoidR","playoid","R","Spielt eine OID, gegeben als Register, ab"},
    {0x1701,"pauseV","pause","V","Pausiert für x Zehntelsekunden"},
    {0x1702,"pauseR","pause","R","Pausiert für x Zehntelsekunden"}
}

for i=1,#initCmd do
    local cmd = Command(initCmd[i])
    ocTable[initCmd[i][1]] = cmd
    idTable[initCmd[i][2]] = cmd
end

return Command
