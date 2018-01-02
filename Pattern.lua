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

local PatternCache = {}

local testcolors = {
    {"green","red","red","red"},
    {"blue","red","red","red"},
    {"green","black","red","red"},
    {"green","green","green","green"},
}

local Pattern
Pattern = {
    new = function(value,dotsize,blocksize,shift,dpi)
        local pn = Pattern.pgfpatname(value,dotsize,blocksize,shift,dpi)
        if PatternCache[pn] then
            return PatternCache[pn]
        end
        local pat = {value=value,dotsize=dotsize,shift=shift,
            blocksize=blocksize,dpi=dpi}
        local SHMPL = Pattern.SHMPL
        local w = {}
        for i=0,7 do
            w[i] = value % 4
            value = (value - w[i])/4
        end
        local ck = 2*((w[1]+w[4]+w[6]+w[7])%2)+(w[0]+w[2]+w[3]+w[5])%2
        pat[1] = {SHMPL[Pattern.CC],SHMPL[w[2]],SHMPL[w[1]],SHMPL[w[0]]}
        pat[2] = {SHMPL[Pattern.CR],SHMPL[w[5]],SHMPL[w[4]],SHMPL[w[3]]}
        pat[3] = {SHMPL[Pattern.CC],SHMPL[ck],SHMPL[w[7]],SHMPL[w[6]]}
        pat[4] = {SHMPL[Pattern.CC],SHMPL[Pattern.CC],
            SHMPL[Pattern.CC],SHMPL[Pattern.CC]}
        setmetatable(pat,Pattern)
        PatternCache[pn] = pat
        return pat
    end,

    pgfpatname = function(pat,dotsize,blocksize,shift,dpi)
        local value
        if type(pat) == "number" then
            value = pat
        else
            value = pat.value
            dotsize = pat.dotsize
            blocksize = pat.blocksize
            shift = pat.shift
            dpi = pat.dpi
        end
        return "tingoid".. value.."."..dotsize.."."..blocksize.."."..
            shift.."."..dpi
    end,

    pgfdim = function(pat,pixels)
        return (pixels/pat.dpi).."in"
    end,

    pgfpoint = function(pat,x,y)
        return "\\pgfpoint{"..
            pat:pgfdim(x).."}{"..
            pat:pgfdim(y).."}"
    end,

    pgfmoveto = function(pat,x,y)
        return "\\pgfmoveto{\\pgfpoint{"..
            pat:pgfdim(x).."}{"..
            pat:pgfdim(y).."}}"
    end,

    pgfdot = function(pat,x,y,hr)
        return pat:pgfmoveto(x,y) .. ((hr and"\n")or"") ..
            "\\pgfpathrectangle{" .. pat:pgfpoint(x,y) ..
            "}{" .. pat:pgfpoint(pat.dotsize,pat.dotsize) .."}"
    end,

    topgf = function(pat,hr,debug)--hr: human readable
        local nbl = (debug and 8) or 4
        if pat.pgf then
            return pat.pgf
        end
        local twh = pat:pgfpoint(nbl*pat.blocksize,nbl*pat.blocksize)
        local pgf = {
            (debug and "\\pgfdeclarepatterninherentlycolored{") or
            "\\pgfdeclarepatternformonly{",
            pat:pgfpatname(),
            "}{\\pgfpointorigin}{",twh,"}{",twh,
            ((hr and "}\n{\n")or"}{"),
        }
        for i=1,4 do for j = 1,4 do
            if debug then
                pgf[#pgf+1] = "\\pgfsetfillcolor{"..
                    testcolors[i][j] .."}"
            end
            local x = (j-0.5)*pat.blocksize +
                pat.shift*pat[i][j].x - 0.5*pat.dotsize
            local y = (i-0.5)*pat.blocksize +
                pat.shift*pat[i][j].y - 0.5*pat.dotsize
            pgf[#pgf+1] = pat:pgfdot(x,y,hr) ..((hr and "\n%\n")or"")
            if debug then
                pgf[#pgf+1] = "\\pgfpathclose\\pgfusepath{fill}"
            end
        end end
        pgf[#pgf+1] = "\\pgfpathclose\\pgfusepath{fill}}"
        pat.pgf = table.concat(pgf)
        return pat.pgf
    end,

    ensureDefinedInPgf = function(pat)
        if pat.pgfDefined then
            return
        end
        tex.print(pat:topgf())
        pat.pgfDefined = true
        return
    end,

    oidToVal = require("klangtrabant.patternOid"),
    valToOid = {},
    
    fromOid = function(oid,dotsize,blocksize,shift,dpi)
        return Pattern(Pattern.oidToVal[oid],dotsize,blocksize,
            shift,dpi)
    end,

    TL = 2,
    TR = 3,
    BL = 1,
    BR = 0,
    CC = 4,
    CR = 5,

    POS={[0]="BR","BL","TL","TR","CC","CR"},
    SHMPL={--shift mutiples
        [0]={x=1,y=-1},{x=-1,y=-1},{x=-1,y=1},{x=1,y=1},
        {x=0,y=0},{x=1,y=0}}
}
makeclass(Pattern)

for o,v in pairs(Pattern.oidToVal) do
    Pattern.valToOid[v] = o
end


return Pattern
