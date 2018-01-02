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
local compileTable = require("klangtrabant.ktCommon").compileTable
local Assembler = require("klangtrabant.Assembler")
local lpeg = require "lpeg"


--Syntax for definition:
--macroname(argname1,argname2,...)
-- ... replacement code ...
--mend

--Syntax1 for application:
--macroname(arg1,arg2,...)
--Syntax2 for application:
--macroname arg1,arg2,.... NEWLINE
--Syntax2 provides a subprocedure like syntax
--and is for instance used for compatibility to tingeltangel

local applTbl = {
    "ALL";
    ALL = [[{~ (MAPPL/%s/.)* ~}]],--substitution capture
    MAPPL = [[ MAPPL1/MAPPL2/MAPPL3 ]],
    MAPPL1 = [[ (MNAME '(')->''
        {| ({BALPARNOCOM}',')* {BALPARNOCOM} |}-> apply
        ')'->'' %s*]],
    MAPPL2 = [[ (MNAME ' ')->''
        {| ({[^%nl,]+}','?)* |}-> apply 
        %nl]],
    MAPPL3 = [[ ('$' MNAME)->'' ({||}-> apply) ]],
    BALPARNOCOM = [[ ([^(),]/'('BALPARNOCOM')')* ]],
    MNAME = [['Insert Macro name here']],
}

local labelRename = {
    "ALL";
    ALL = [[{~ (COMMAND/%s/.)* ~}]],
    COMMAND = [[ ACTION LABEL ]],
    ACTION = [[('jmp'/'je'/'jne'/'jge'/'jg'/'jbe'/'jb')%s+/':'%s* ]],
    LABEL = "",
}

local defineTbl = {
    "DEF";
    DEF = [[ COMMENT
        {| %s* DEFSTART (!(%nl'mend')%nl)? {:repl: (!(%s'mend').)* :} 
        %s 'mend' COMMENT |} ]],--table capture
    COMMENT = [[ (!([A-Za-z_0-9]+'(').)* ]],
    DEFSTART = [[ MNAME '(' ({ARG}(','?))* ')']],
    MNAME = [[{:mname:  [A-Za-z_][A-Za-z_0-9]* :} ]],
    --formal arguments:
    ARG = [[[a-zA-Z_0-9]+/"'"[^']*"'"]],
}
local defGrammar = compileTable(defineTbl)*lpeg.Cp()

local replTbl = {
    "REPL";
    REPL = [[ {| ({|{:arg: ARG :}|}/{|{:plain: (!ARG.)+ :}|})* |} ]],
    ARG = [['arg1'/'arg2']],
}


--mcr is a partially defined macro with replacement, args and name
local replacementToAppl = function(mcr)
    local atl = dcopy(applTbl)
    atl.MNAME = "'" .. mcr.name .. "'"
    local defs = {}
    defs.apply = function(t)
        local avpairs = {}
        for i=1,#t do
            if mcr.args[i] then
                avpairs[mcr.args[i]] = t[i]
            end
        end
        return mcr:replacement(avpairs)
    end
    local atlGr = compileTable(atl,defs)
    return function(mcr,cd)
        --can be called with and without mcr
        if type(mcr) == "string" then
            cd = mcr
        end
        return lpeg.match(atlGr,cd)
    end
end




local Macro
Macro = {
    new = function(init)
        if type(init) == "string" then
            return Macro.fromDef(init)[1]
        else
            local mcr = {
                name=init.name,
                args=dcopy(init.args),
                replacement=init.replacement,
                complex=init.complex,
                registers=dcopy(init.registers)
            }
            mcr.apply = replacementToAppl(mcr)
            setmetatable(mcr,Macro)
            return mcr
        end
    end,
    
    __tostring = function(mcr)
        local s = mcr.name .. "("
        local aapairs = {}
        for i=1,#mcr.args do
            local comma = (i < #mcr.args and ",") or ""
            s = s .. mcr.args[i] .. comma
            aapairs[mcr.args[i]] = mcr.args[i]
        end
        s = s ..")\n"
        s = s .. mcr:replacement(aapairs)
        s = s .. "\nmend"
        return s
    end,
    
    __add = function(m1,m2)
        if not m1.complex then
            return Macro(m2:apply(tostring(m1)))
        else
            local mcr = Macro(m1)
            mcr.replacement = function(...)
                local cd1 = m1.replacement(...)
                return m2:apply(cd1)
            end
            mcr.apply = replacementToAppl(mcr)
            return mcr
        end
    end,
    
    --returns a list of macros
    fromDef = function(str,book)
        local mlist = {}
        local offset,len = 1,str:len()
        repeat
            local cap
            cap,offset = lpeg.match(defGrammar,str,offset)
            if not cap then
                break
            end
            local mcr = {name=cap.mname}
            mcr.args = {}
            local rtl = dcopy(replTbl)
            rtl.ARG = ""
            for i=1,#cap do
                mcr.args[i] = cap[i]
                local q = (cap[i]:sub(1,1) == "'" and [["'"]]) or ""
                local sl = (i < #cap and "/") or ""
                rtl.ARG = rtl.ARG .. q .. "'" .. 
                        cap[i] .. "'" ..q .. sl
            end
            if #cap > 0 then
                local rtlGr = compileTable(rtl)
                local replList = lpeg.match(rtlGr,cap.repl)
                --mcr is an argument, so the function can be copied
                mcr.replacement = function(mcr,avpairs)
                    local ret = {}
                    for i=1,#replList do
                        ret[i] = replList[i].plain or 
                                (avpairs[replList[i].arg] or "")
                    end
                    return table.concat(ret)
                end
            else
                mcr.replacement = function()
                    return cap.repl
                end
            end
            mcr.apply = replacementToAppl(mcr)
            --compute a set of registers that will most likely
            --be used by any invocation of this macro
            --there may be other registers depending on macro arguments
            mcr.registers = {}
            if book then
                cap.repl = Macro.applyList(book.macros,cap.repl)
            end
            for s in cap.repl:gmatch("v[0-9]+") do
                mcr.registers[tonumber(s:sub(2))] = true
            end
            if book then
                for r,_ in pairs(mcr.registers) do
                    book.registers[r] = true
                end
            end

            setmetatable(mcr,Macro)
            mlist[#mlist+1] = mcr
        until offset > len
        return mlist
    end,

    callMacro = function(book)
        local mcrcall = Macro({name="call",args={"oid"}})
        mcrcall.replacement = function(_,avpairs)
            local oid = tonumber(avpairs.oid)
            local cd = book[oid].code
            cd = Macro.applyList(book.macros,cd)
            cd = mcrcall:apply(cd)
            if cd:sub(1,6) == "return" then
                return ""
            end
            local as = Assembler(cd)
            as:assemble()
            local lgr = dcopy(labelRename)
            for l,_ in pairs(as.labels) do
                lgr.LABEL = lgr.LABEL ..
                    "('".. l .. "' -> 'call_"..oid.."_"..l.."')/"
            end
            cd = lpeg.match(compileTable(lgr),cd)
            --search for whitespace before return
            --since return could be in some label
            cd = cd:gsub("%sreturn","\njmp callreturn_"..oid)
            cd = cd .. "\n:callreturn_"..oid .."\n"
            return cd
        end
        mcrcall.apply = replacementToAppl(mcrcall)
        return mcrcall
    end,
    
    --Macros are applied in reverse order
    --later defined Macros can use earlier ones
    applyList = function(mcrList,cd)
        for i=#mcrList,1,-1 do
            cd = mcrList[i]:apply(cd)
        end
        return cd
    end
}
makeclass(Macro)
return Macro
