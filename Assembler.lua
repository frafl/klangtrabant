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

--[[As this code was converted from Java code it uses 0 based 
    addressing in some places to keep its semantics close
    to the original.]]
local makeclass = require("klangtrabant.ktCommon").makeclass
local compileTable = require("klangtrabant.ktCommon").compileTable
local Command = require("klangtrabant.Command")
local lpeg = require "lpeg"

local defs = {tonumber = tonumber}

--nur Debugging, Rekursionstiefe ~= 1 angeben
dump = function(t,l)
    l = l or 1
    if type(t) == 'table' and l > 0 then
        local s = "{"
        for k,v in pairs(t) do
            s = s .. dump(k,l-1) .. ":"  .. dump(v,l-1) .. ", "
        end
        return s .. "}"
    else
        return tostring(t)
    end
end


local grammarTbl = {
    "COMMAND";
    COMMAND = [[%s* 
        (JUMP/NOARGC/V_COMM/R_COMM/RV_COMM/RR_COMM/LABELLINE/COMMENT)
        %s*]],
    REGISTERNUM = [[ ([1-9][0-9]? / '0')->tonumber ]],
    VALUE = [[ (([0][xX]([1-9A-Fa-f][0-9A-Fa-f]*/'0')
       ('.'[0-9A-Fa-f]+)?([pP][1-9A-Fa-f][0-9A-Fa-f]*)?) /
       (([1-9][0-9]*/'0')('.'[0-9]+)?([eE][1-9][0-9]*)?))
       -> tonumber ]],
    NOARGC = [[ {| {:type:('end'/'clearver'/'return'):} 
            {:arg:'':} %s* |}]],
    R_COMM = [[ {| {:type:('callid'/'playoid'/'pause'):} 
            {:arg:(''->'R'):} %s* 'v'{:one: REGISTERNUM:} %s* |}]],
    V_COMM = [[ {| {:type:('callid'/'playoid'/'pause'/'call'):}
            {:arg:(''->'V'):} %s* {:one: VALUE:} %s* |}]],
    RR_COMM = [[ {| {:type:('set'/'cmp'/'add'/'sub'/'and'/'or'/'not'):}
            {:arg:(''->'RR'):} %s* 'v'{:one: REGISTERNUM:} %s* ',' 
            %s* 'v'{:two:REGISTERNUM:} |}]],
    RV_COMM = [[ {| {:type:('set'/'cmp'/'add'/'sub'/'and'/'or'/'not'):} 
            {:arg:(''->'RV'):} %s* 'v'{:one: REGISTERNUM:} %s* ',' %s* {:two:VALUE:} |}]],
    JUMP = [[ {| {:type:('jmp'/'je'/'jne'/'jge'/'jg'/'jbe'/'jb'):}
            {:arg:(''->'L'):} %s* {:one: LABEL :} %s* |}]],
    LABEL = [[ [a-zA-Z][a-zA-Z0-9_]* ]],
    LABELLINE = [[{|{:type:(':'->'labelline'):} %s* {:one: LABEL :} %s*|}]],
    COMMENT = [[{|{:type:('//'->'comment'):} [^%nl]* %nl |}]],
}

local grammar =  compileTable(grammarTbl,defs)*lpeg.Cp()


local captureToCommand = function(cap,labelList)
    local cmd = Command(cap.type..cap.arg,cap.one,cap.two)
    cmd.labelList = labelList
    if type(cap.one) == "number" and cap.one > 65535 then
        error("Constant bigger than 16bit unsigned value.")
    end
    if type(cap.two) == "number" and cap.two > 65535 then
        error("Constant bigger than 16bit unsigned value.")
    end
    return cmd
end


local Assembler
Assembler = {
    
    new = function(s,offset)
        local as = {}
        as.s = s
        as.offset = offset or 1
        as.labels = {}
        as.byteCount = 0
        as.cmdList = {}
        setmetatable(as,Assembler)
        return as
    end,

    assemble = function(as,s,offset)
        as.s = s or as.s
        local cmdList,labels = as.cmdList,as.labels
        as.offset = offset or as.offset

        local len=as.s:len()
        local last=nil
        repeat
            local cap
            cap,as.offset = lpeg.match(grammar,as.s,as.offset)
            if not cap then
                break
            end
            if cap.type == "labelline" then
                as.labels[cap.one] = as.byteCount
            elseif cap.type == "comment" then
            else
                local cmd = captureToCommand(cap,as.labels)
                cmdList[#cmdList+1] = cmd
                as.byteCount = as.byteCount + cmd:nbytes()
            end
        until as.offset > len
        
        local bb = {}
        for i=1,#cmdList do
            bb[i] = cmdList[i]:tobytecode()
        end
        bb[#bb+1] = string.char(0)
        
        return table.concat(bb)
    end,

} 
makeclass(Assembler)
return Assembler
