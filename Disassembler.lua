--[[
    Copyright (C) 2015   Jesper Zedlitz <jesper@zedlitz.de>
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

--[[As this code was converted from Java code it uses 0 based 
    addressing in some places to keep its semantics close
    to the original.]]
local makeclass = require("klangtrabant.ktCommon").makeclass
local Command = require("klangtrabant.Command")
local hex = {
  "1","2","3","4","5","6","7","8","9","a","b","c","d","e","f",[0]="0"}
for i=255,0,-1 do
  local r = i % 16
  local d = (i-r)/16
  hex[i] = "0x"..hex[d]..hex[r]
end

local Disassembler
Disassembler = {
    
    new = function(s,offset)
        local da = {}
        da.b = {}
        if s then
            for i=1,s:len() do
              da.b[i-1]= s:byte(i)
            end
        end
        da.isSub = false
        da.offset = offset or 0
        da.labels = {}
        da.labelCount = 1
        da.sb = {}
        setmetatable(da,Disassembler)
        return da
    end,

    disassembleCommandRegisterRegister = function(da,command)
        local sb,b = da.sb,da.b
        sb[#sb+1] =  command
        sb[#sb+1] =  " v"
        local register1 = ((b[da.offset + 2]) * 256) + (b[da.offset + 3])
        local register2 = ((b[da.offset + 4]) * 256) + (b[da.offset + 5])
        sb[#sb+1] =  register1
        sb[#sb+1] =  ",v"
        sb[#sb+1] =  register2
        sb[#sb+1] =  '\n'

        da.offset = da.offset + 6
    end,
    
    disassembleCommandRegister = function(da,command)
        local sb,b = da.sb,da.b
        sb[#sb+1] =  command
        sb[#sb+1] =  " v"
        local register1 = ((b[da.offset + 2]) * 256) + (b[da.offset + 3])
        sb[#sb+1] =  register1
        sb[#sb+1] =  '\n'

        da.offset = da.offset + 4
    end,

    disassembleCommandRegisterValue = function(da,command)
        local sb,b = da.sb,da.b
        sb[#sb+1] =  command
        sb[#sb+1] =  " v"
        local register = ((b[da.offset + 2]) * 256) + (b[da.offset + 3])
        local value = ((b[da.offset + 4]) * 256) + (b[da.offset + 5])
        sb[#sb+1] =  register
        sb[#sb+1] =  ","
        sb[#sb+1] =  value
        sb[#sb+1] =  '\n'

        da.offset = da.offset + 6
    end,

    disassembleJump = function(da,command)
        local sb,b,labels = da.sb,da.b,da.labels
        sb[#sb+1] =  command
        sb[#sb+1] =  " "
        local label = ((b[da.offset + 2]) * 256) + (b[da.offset + 3])
        --labels[label]= labelCount
        sb[#sb+1] =  'l'
        sb[#sb+1] = labels[label]
        sb[#sb+1] =  '\n'
        --labelCount = labelCount+1
        da.offset = da.offset + 4
    end,

    --[[
     - Disassemble the specified binary and set the script.
     ]]
    disassemble = function(da,s,offset,maxpos)
        if s then
            da.b = {}
            for i=1,s:len() do
              da.b[i-1]= s:byte(i)
            end
            --reset sub detecttion flag
            da.isSub = false
        end
        local sb,b,labels = da.sb,da.b,da.labels
        da.offset = offset or da.offset
        offset = da.offset
        maxpos = maxpos or #b

        if b[0] == 0 and b[1] == 0 and b[2] == 0 and b[3] == 0 then
            error ("Script starts with 0x00000000. That's an invalid script.")
        end

        -- first pass (collect jump targets)
        while (da.offset <= maxpos) do
            if da.offset == #b then
                if b[da.offset] ~= 0 then
                    error("Last byte must be 0x00.")
                end
                da.offset = da.offset + 1
             else
                local opcode = ((b[da.offset]) * 256) + (b[da.offset + 1])
                local command = Command(opcode)
                if not command then
                    error("unknown byte code" .. hex[b[da.offset]] .. hex[b[da.offset+1]] .. "@ " .. hex[da.offset])
		elseif command.arg1 == "L" then --was: firstArgumentIsLabel()
                    -- jump
                    local label = ((b[da.offset + 2]) * 256) + (b[da.offset + 3])
                    if not labels[label] then
                        labels[label] = da.labelCount
			da.labelCount = da.labelCount + 1
                    end
                    da.offset = da.offset + 4
                else
                    da.offset = da.offset + (command.nargs + 1) * 2
                end
            end
        end

        -- second pass
        da.offset = offset or 0
        while (da.offset <= maxpos) do
            if labels[da.offset] then
                sb[#sb+1] =  "\n:l"
                sb[#sb+1] = labels[da.offset]
                sb[#sb+1] =  '\n'
            end

            if da.offset == #b then
                if b[da.offset] ~= 0 then
                    error("Last byte must be 0x00.")
                end
                da.offset = da.offset + 1
            elseif b[da.offset] == 0x00 and b[da.offset + 1] == 0x00 then
                sb[#sb+1] =  "end\n"
                da.offset = da.offset + 2
            elseif b[da.offset] == 0x01 and b[da.offset + 1] == 0x00 then
                sb[#sb+1] =  "clearver\n"
                da.offset = da.offset + 2
            elseif b[da.offset] == 0x02 and b[da.offset + 1] == 0x01 then
                da:disassembleCommandRegisterValue("set")
            elseif b[da.offset] == 0x02 and b[da.offset + 1] == 0x02 then
                da:disassembleCommandRegisterRegister("set")
            elseif b[da.offset] == 0x03 and b[da.offset + 1] == 0x01 then
                da:disassembleCommandRegisterValue("cmp")
            elseif b[da.offset] == 0x03 and b[da.offset + 1] == 0x02 then
                da:disassembleCommandRegisterRegister("cmp")
            elseif b[da.offset] == 0x04 and b[da.offset + 1] == 0x01 then
                da:disassembleCommandRegisterValue("and")
            elseif b[da.offset] == 0x04 and b[da.offset + 1] == 0x02 then
                da:disassembleCommandRegisterRegister("and")
            elseif b[da.offset] == 0x05 and b[da.offset + 1] == 0x01 then
                da:disassembleCommandRegisterRegister("or")
            elseif b[da.offset] == 0x05 and b[da.offset + 1] == 0x02 then
                da:disassembleCommandRegisterRegister("or")
            elseif b[da.offset] == 0x06 and b[da.offset + 1] == 0x02 then
                -- ignore last register!
                sb[#sb+1] =  "not v"
                sb[#sb+1] =  ((b[da.offset + 2]) * 256) + (b[da.offset + 3])
                sb[#sb+1] =  '\n'
                da.offset = da.offset + 6
            elseif b[da.offset] == 0x08 and b[da.offset + 1] == 0x00 then
                da:disassembleJump("jmp")
            elseif b[da.offset] == 0x09 and b[da.offset + 1] == 0x00 then
                da:disassembleJump("je")
            elseif b[da.offset] == 0x0A and b[da.offset + 1] == 0x00 then
                da:disassembleJump("jne")
            elseif b[da.offset] == 0x0B and b[da.offset + 1] == 0x00 then
                da:disassembleJump("jg")
            elseif b[da.offset] == 0x0C and b[da.offset + 1] == 0x00 then
                da:disassembleJump("jge")
            elseif b[da.offset] == 0x0D and b[da.offset + 1] == 0x00 then
                da:disassembleJump("jb")
            elseif b[da.offset] == 0x0E and b[da.offset + 1] == 0x00 then
                da:disassembleJump("jbe")
            elseif b[da.offset] == 0x0F and b[da.offset + 1] == 0x01 then
                da:disassembleCommandRegisterValue( "add")
            elseif b[da.offset] == 0x0F and b[da.offset + 1] == 0x02 then
                da:disassembleCommandRegisterRegister("add")
            elseif b[da.offset] == 0x10 and b[da.offset + 1] == 0x01 then
                da:disassembleCommandRegisterValue( "sub")
            elseif b[da.offset] == 0x10 and b[da.offset + 1] == 0x02 then
                da:disassembleCommandRegisterRegister("sub")
            elseif b[da.offset] == 0x14 and b[da.offset + 1] == 0x00 then
                sb[#sb+1] =  "return\n"
                da.offset = da.offset + 2
                da.isSub = true
            elseif (b[da.offset] == 0x15 and (b[da.offset + 1] == 0x01 or b[da.offset + 1] == 0x02)) then
                sb[#sb+1] =  "callid "
                sb[#sb+1] =  ((b[da.offset + 2]) * 256) + (b[da.offset + 3])
                sb[#sb+1] =  '\n'
                da.offset = da.offset + 4
            elseif b[da.offset] == 0x16 and b[da.offset + 1] == 0x01 then
                sb[#sb+1] =  "playoid "
                sb[#sb+1] =  ((b[da.offset + 2]) * 256) + (b[da.offset + 3])
                sb[#sb+1] =  '\n'
                da.offset = da.offset + 4
            elseif b[da.offset] == 0x16 and b[da.offset + 1] == 0x02 then
                sb[#sb+1] =  "playoid v"
                sb[#sb+1] =  ((b[da.offset + 2]) * 256) + (b[da.offset + 3])
                sb[#sb+1] =  '\n'
                da.offset = da.offset + 4
            elseif b[da.offset] == 0x17 and b[da.offset + 1] == 0x01 then
                sb[#sb+1] =  "pause "
                sb[#sb+1] =  ((b[da.offset + 2]) * 256) + (b[da.offset + 3])
                sb[#sb+1] =  '\n'
                da.offset = da.offset + 4
            elseif b[da.offset] == 0x17 and b[da.offset + 1] == 0x02 then
                sb[#sb+1] =  "pause v"
                sb[#sb+1] =  ((b[da.offset + 2]) * 256) + (b[da.offset + 3])
                sb[#sb+1] =  '\n'
                da.offset = da.offset + 4
            else
                error("unknown byte code " .. hex[b[da.offset]] .. hex[b[da.offset+1]])
            end
        end
        return table.concat(sb), da.isSub
    end,

} 
makeclass(Disassembler)
return Disassembler
