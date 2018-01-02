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
local Macro = require("klangtrabant.Macro")
local Command = require("klangtrabant.Command")
local Assembler = require("klangtrabant.Assembler")
local Disassembler = require("klangtrabant.Disassembler")

local ordipairs = function(t)
    local keys = {}
    for k,_ in pairs(t) do
        if type(k) == "number" then
            keys[#keys+1] = k
        end
    end
    table.sort(keys)
    local i=0
    return function()
        i = i+1
        return keys[i],t[keys[i] or 0]
    end
end

local int32FromBytes = function(b1,b2,b3,b4)
    return ((b1*256+b2)*256+b3)*256+b4
end

local int32ToBytes = function(i)
    local b1,b2,b3,b4
    b4 = i % 256
    i = (i-b4)/256
    b3 = i % 256
    i = (i-b3)/256
    b2 = i % 256
    b1 = (i-b2)/256
    return b1,b2,b3,b4
end

local intIt = function(s,state)
    return function()
        state.offset = state.offset + 4
        return int32FromBytes(s:byte(state.offset-4,state.offset-1))
    end
end

local isMp3Data = function(data)
    if #data <= 3 then
        return false
    end
    --check for id3
    if data[1] == ("I"):byte() and data[2] == ("D"):byte() and
            data[3] == ("3"):byte() then
        return true
    end

    --check for mp3
    if((data[1] == 0xFF and data[2] == 0xF2) or -- mpeg v2 layer 3 (crc)
            (data[1] == 0xFF and data[2] == 0xF3) or -- mpeg v2 layer 3
            (data[1] == 0xFF and data[2] == 0xFA) or -- mpeg v1 layer 3 (crc)
            (data[1] == 0xFF and data[2] == 0xFB) or -- mpeg v1 layer 3
            (data[1] == 0xFF and data[2] == 0x00)) then -- ? (seems to be valid)
        return true
    end
    return false
end

local isScriptData = function(data)
    if (#data >= 3) and 
            (data[1] == 0 and data[2] == 0 and 
            data[3] == 0 and data[4] == 0) then
        return false
    end
    local p = 1
    while p + 1 <= #data do
            local opcode = data[p + 1] + data[p] * 256
            local cmd = Command.fromOpcode(opcode)
            if not cmd then
                return false
            end
            p = p + cmd.nargs * 2 + 2
    end
    return true
end

local biti = function(x,i)
    local powtwo = 2^i
    x = (x - (x % powtwo))/powtwo
    return x % 2
end

local E = {578, 562, 546, 530, 514, 498, 482, 466, 322, 306, 290, 274,
    258, 242, 226, 210, -446, -462, -478, -494, -510, -526, -542,
    -558, -702, -718, -734, -750, -766, -782, -798, -814}
local getPositionInFileFromCode = function(posCode,idShift)
        if ((posCode % 256 ~= 0) or (idShift < 0)) then
            return nil
        end
        idShift=idShift-1
        posCode = posCode / 256
        local c = biti(posCode,3) + 2*biti(posCode,4) + 
            4*biti(posCode,5) + 8*biti(posCode,7) + 16*biti(posCode,9)
        posCode = posCode - (idShift * 26 - E[c+1])
        return posCode*256
end

local getCodeFromPositionInFile = function(position,idShift)
    if ((position % 256 ~= 0) or (idShift < 0)) then
        return math.mininteger
    end
    idShift = idShift-1
    local b = position / 256 + idShift * 26
    for k=1,#E  do
        local v = (b - E[k]) * 256
        if getPositionInFileFromCode(v,idShift+1) == position then
            return v
        end
    end
    return nil
end

local ensureDirExists = function(path)
    local dir = path:sub(1,#path - path:reverse():find("/") + 1)
    os.execute("mkdir -p " .. dir)
end

local stringToFile = function(s,fn)
    local f = assert(io.open(fn, "w"))
    f:write(s)
    f:close()
end

local defaultTTSGenerator = function(text,filepath)
    local espeakCommand = "espeak --stdin --stdout " ..
            "-b 1 -z -a 160 -p 40 -s 100 " ..
            "-v german-mbrola-5 > " .. filepath .. ".wav"
    local encCommand = "lame " .. filepath .. ".wav " ..
            filepath
    local esp = io.popen(espeakCommand,"w")
    esp:write(text)
    esp:close()
    os.execute(encCommand)
    os.remove(filepath..".wav")
end


local Entry
Entry = {
    new = function(oid,book,stype,content,note)
        local etr
        if type(oid) == "table" then
            etr = dcopy(oid)
            etr.book = book or etr.book
            setmetatable(etr,Entry)
            return etr
        end
        etr = {oid=oid,book=book,
            mtype=(stype and stype%2) or nil,
            stype=stype,note=note or ""}
        setmetatable(etr,Entry)
        if etr.mtype == Entry.CODE then
            etr.code = content
        elseif etr.stype == Entry.FILE then
            etr.filepath = content
        elseif etr.stype == Entry.TTS then
            if type(content) == string then
                content = {content}
            end
            etr.filepath = content[1]
            etr.tts = content[2]
        end
        return etr
    end,

    assemble = function(etr)
        if not etr.code then
            return
        end
        --Macros are applied in reverse order
        --later defined Macros can use earlier ones
        local cd = etr.code
        etr.book.callMacro = etr.book.callMacro or
                Macro.callMacro(etr.book)
        cd = Macro.applyList(etr.book.macros,cd)
        cd = etr.book.callMacro:apply(cd)
        etr.bin = Assembler(cd):assemble()
    end,

    size = function(etr)
        if etr.filepath then
            local f = io.open(etr.filepath, "r")
            if not f and etr.tts then
                etr.book.ttsgen(etr.tts,etr.filepath)
                f = io.open(etr.filepath, "r")
            end
            assert(f)
            local s = f:seek("end")
            f:close()
            return s
        elseif etr.code then
            if not etr.bin then
                etr:assemble()
            end
            return etr.bin:len()
        end
        return nil
    end,

    CODE = 0,
    MP3 = 1,
    MAINCODE = 0,
    SUBCODE = 2,
    FILE = 1,
    TTS = 3,
}
makeclass(Entry)



local Book
Book = {
    new = function(init,meta,macros)
        init = init or {}
        local book = {}
        for i=1,#init do
            book[i] = Entry(init[i],book)
        end
        book.meta = init.meta or meta
        book.meta = dcopy(book.meta)
        macros = init.macros or macros
        book.macros = {}
        local nmcr = (macros and #macros) or 0
        for i=1,nmcr do
            book.macros[i] = Macro(macros[i])
        end
        book.nameToOid = dcopy(init.nameToOid) or {}
        book.ttsgen = init.ttsgen or defaultTTSGenerator
        book.registers = dcopy(init.registers) or {}
        setmetatable(book,Book)
        return book
    end,

    entryByName = function(book,name)
        if book.nameToOid[name] then
            return book[book.nameToOid[name]]
        end
        local m = book:maxOid()+1
        m = (m>=15001) or 15001
        local etr = Entry(#book+1,book)
        book[etr.oid] = etr
        return etr
    end,

    entry = function(book,which)
        if type(which) == "string" then
            return book:entryByName(which)
        end
        if book[which] then
            return book[which]
        end
        local etr = Entry(which,book)
        book[which] = etr
        return etr
    end,

    maxOid = function(book)
        local m=0
        for i,_ in pairs(book) do
            if type(i) == "number" and i>m then
                m = i
            end
        end
        return m
    end,

    toSource = function(book,plain)--plain: apply macros,types: 0/1
        local scrTab = {}
        if not plain then
            scrTab[#scrTab+1] = "[Macros]"
            for _,mcr in ipairs(book.macros) do
                scrTab[#scrTab+1] = tostring(mcr):gsub("\n","\r\n")
            end
            scrTab[#scrTab+1] = "[MacrosEnd]"
        end

        for _,etr in ordipairs(book) do
            scrTab[#scrTab+1] = "Precode=" .. etr.oid
            scrTab[#scrTab+1] = "TYPE=" ..
                    ((plain and etr.mtype) or etr.stype)
            scrTab[#scrTab+1] = "[Note]"
            if etr.stype == TTS and not etr.note:match("\nTTS:") then
                scrTab[#scrTab+1] = etr.note .. "\nTTS:\n" ..
                        etr.tts
            else
                scrTab[#scrTab+1] = etr.note
            end
            scrTab[#scrTab+1] = "[Content]"
            if etr.mtype == Entry.MP3 and etr.filepath then
                scrTab[#scrTab+1] = etr.filepath
            elseif etr.mtype == Entry.CODE then
                local cd = etr.code
                if plain then
                    --Macros are applied in reverse order
                    --later defined Macros can use earlier ones
                    cd = Macro.applyList(book.macros,cd)
                end
                if cd:sub(#cd) == "\n" then
                    cd = cd:sub(1,#cd-1)
                end
                scrTab[#scrTab+1] = cd:gsub("\n","\r\n")
            end
            scrTab[#scrTab+1] = ""
        end
        return table.concat(scrTab,"\r\n")
    end,

    fromSource = function(source,meta)
        local book = Book({},meta,nil)
        local buffer,etr,inNote,inContent,inMacros,inTTS
        source = source:gsub("\r","")
        for l in source:gmatch("[^\n]*\n") do
            if l:sub(1,8) == "[Macros]" then
                inMacros = true
                buffer = {}
            elseif l:sub(1,11) == "[MacrosEnd]" then
                inMacros = false
                book.macros = Macro.fromDef(table.concat(buffer))
                buffer = nil
            elseif l:sub(1,8) == "Precode=" then
                assert(not inNote,"Precode after Note")
                if inContent then
                    inContent = false
                    if etr.mtype == Entry.MP3 then
                        --TODO:possible positions of MP3 file name
                        etr.filepath = buffer[1]:sub(1,#(buffer[1])-1)
                    end
                    if etr.mtype == Entry.CODE then
                        etr.code = table.concat(buffer)
                    end
                    buffer = nil
                end
                etr = Entry(tonumber(l:sub(9,#l-1)),book)
                book[etr.oid] = etr
            elseif l:sub(1,5) == "TYPE=" then
                assert(etr,"TYPE before Precode")
                --Types other than 0,1 are not standard!
                etr.stype = tonumber(l:sub(6,#l-1))
                etr.mtype = etr.stype % 2
            elseif l:sub(1,6) == "[Note]" then
                assert(etr,"Note before Precode")
                buffer = {}
                inNote = true
            elseif l:sub(1,4) == "TTS:"  and inNote then
                buffer[#buffer+1] = l
                inTTS = #buffer
            elseif l:sub(1,9) == "[Content]" then
                assert(etr,"Content before Precode")
                if inNote then
                    etr.note = table.concat(buffer)
                    inNote = false
                    if inTTS then
                        local ttsBuf = {}
                        for i=1,#buffer-inTTS do
                            ttsBuf[i] = buffer[i+inTTS]
                        end
                        etr.stype = Entry.TTS
                        etr.tts = table.concat(ttsBuf)
                        inTTS = false
                    end
                end
                buffer = {}
                inContent = true
            elseif buffer then
                buffer[#buffer+1] = l
            end
        end
        if inContent then
            if etr.mtype == Entry.MP3 then
                --TODO: s.a.
                etr.filepath = buffer[1]:sub(1,#(buffer[1])-1)
            end
            if etr.mtype == Entry.CODE then
                etr.code = table.concat(buffer)
            end
        end
        return book
    end,

    toOuf = function(book,oufFile)
        local ouf = {}
        local state = {size = 0, offset = 1}
        local writeInt = function(i)
            state.size = state.size + 1
            state.offset = state.offset + 4
            ouf[state.size] = string.char(int32ToBytes(i))
        end
        local writeStr = function(s)
            state.size = state.size + 1
            state.offset = state.offset + s:len()
            ouf[state.size] = s
        end
        local paddBytes = function(n)
            state.size = state.size + 1
            state.offset=state.offset+n
            local zeros = {}
            for i=1,n do
                zeros[i] = string.char(0)
            end
            ouf[state.size] = table.concat(zeros)
        end

        local startOfIndex = 104
        local lastID = book:maxOid()
        local size = lastID - 15000

        writeInt(startOfIndex)
        writeInt(2)
        writeInt(15001)
        writeInt(lastID)
        writeInt(size)
        writeInt(book.meta.id)
        writeInt(book.meta.magic or 11)
        writeInt(book.meta.date or os.time(os.date("!*t")))
        writeInt(0)
        writeInt(0xffff)

        --Padding until startOfIndex
        paddBytes(startOfIndex - 40)

        local pos = startOfIndex + 12 * size

        for i=0,size-1 do
            local etr = book[i + 15001]
            if not etr then
                paddBytes(12)
            else
                pos = pos + (-(pos+1) % 512) + 1
                local poscode =
                    getCodeFromPositionInFile(pos,i)
                local etrsize = etr:size()
                writeInt(poscode)
                writeInt(etrsize or 0)
                writeInt(2-etr.mtype)
                pos = pos + (etrsize or 0)
            end
        end

        pos = startOfIndex + 12 * size
        for i=0,size-1 do
            local etr = book[i + 15001]
            if etr then
                local pad = (-(pos+1) % 512) + 1
                pos = pos + pad
                paddBytes(pad)

                if etr.stype == Entry.TTS then
                    local f = io.open(etr.filepath,"r")
                    if not f then
                        book.ttsgen(etr.tts,etr.filepath)
                    else
                        f:close()
                    end
                end
                if etr.mtype == Entry.MP3 and etr.filepath then
                    local f = assert(io.open(etr.filepath, "r"))
                    local mp3 = f:read("*all")
                    f:close()
                    writeStr(mp3)
                    pos = pos + mp3:len()
                else
                    if not etr.bin then
                        etr:assemble()
                    end
                    writeStr(etr.bin)
                    pos = pos + etr.bin:len()
                end
            end
        end
        local f = assert(io.open(oufFile,"w"))
        for i=1,#ouf do
            f:write(ouf[i])
        end
        f:close()
    end,

    fromOuf = function(oufFile,mp3FilePrefix)
        mp3FilePrefix = mp3FilePrefix or ""
        local book = Book({},{},{})
        local f = assert(io.open(oufFile,"r"))
        local ouf = f:read("*all")
        f:close()
        local state = {offset = 1}
        local readInt = intIt(ouf,state)
        local skipBytes = function(n) state.offset=state.offset+n end
--         local seekTo = function(n) state.offset=n end

        local startOfIndex = readInt()
        skipBytes(4)--usually 2

        local firstTingID = readInt()
        local lastTingID = readInt()
        local tingIDCount = readInt()
        assert(tingIDCount == lastTingID - firstTingID + 1,
            "index count missmatch (first=".. firstTingID .. 
            ", last=" .. lastTingID .. ", count=" .. 
            tingIDCount .. ")")

        book.meta.id = readInt()
        book.meta.magic = readInt()
        book.meta.date = readInt()
        skipBytes(8)--unknown, usually 4 zero,2 0xff, 2 zero

        --currently we do not correct the first Ting ID
        --use tingeltangel to convert your ouf to a correct one
        --tingeltangel: boolean firstTingIdCorrected = false; etc.

        --Padding until startOfIndex
        skipBytes(startOfIndex - 40)

        local index = {}
        local firstEntryPosCode,firstEntryN,firstEntryLength,
            firstEntryTypeIsScript

        for i=firstTingID,lastTingID  do
            local e = {
                poscode=readInt(),
                length=readInt(),
                type=readInt()
            }
            if e.type ~= 0 then
                e.id = i
                --still nil and new entry non empty
                if not firstEntryPosCode and e.length > 0 then
                    firstEntryPosCode = e.poscode
                    firstEntryN = e.id - 15001
                    firstEntryTypeIsScript = (e.type == 2)
                    firstEntryLength = e.length
                end
                index[#index+1] = e
            end
        end

        --tingeltangel does this:
        --local pos = 12 * (lastTingID - firstTingID + 1) + startOfIndex
        --we do not need this, we have (state.offset - 1)
        --diff is additive inverse to pos modulo 256:
        local diff = (-(state.offset - 1)) % 256
        skipBytes(diff)

        local nTestBytes = math.min(firstEntryLength, 50)
        local isCorrectType = (firstEntryTypeIsScript and isScriptData)
            or isMp3Data
        while not isCorrectType(
            {ouf:byte(state.offset,state.offset+nTestBytes-1)}) do
                skipBytes(256)
        end

        local entryOffset = (state.offset-1) - 
            getPositionInFileFromCode(firstEntryPosCode, firstEntryN)

        for _,e in ipairs(index) do
            local epos = getPositionInFileFromCode(e.poscode,
                e.id-15001) + entryOffset
--             seekTo(epos)
            local eidstr = e.id .. ""
            while eidstr:len() < 5 do
                eidstr = "0" .. eidstr
            end

            etr = Entry(e.id,book)
            --CODE is 0 in sources, but 2 in ouf:
            etr.mtype = e.type % 2
            etr.stype = etr.mtype
            book[e.id] = etr


            if etr.mtype == Entry.MP3 then
                etr.stype = Entry.FILE
                etr.filepath = mp3FilePrefix ..
                    "mp3_" .. book.meta.id .. "/" .. eidstr .. ".mp3"
                ensureDirExists(etr.filepath)
                stringToFile(ouf:sub(epos+1,epos+e.length),etr.filepath)
            else
                local da = Disassembler(ouf:sub(epos+1,epos+e.length))
                local cd,sub = da:disassemble()
                etr.stype = (sub and Entry.SUBCODE) or Entry.MAINCODE
                etr.code = cd
            end
        end
        return book
    end,


}
makeclass(Book)

Book.Entry = Entry
return Book
