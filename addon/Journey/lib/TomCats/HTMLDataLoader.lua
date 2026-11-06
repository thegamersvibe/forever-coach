--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local emptySandbox = { }

local bxor = bit.bxor

local function xorDecrypt(data, key)
    if (not key or #key == 0) then return data end
    local keyBytes = { string.byte(key, 1, #key) }
    local keyLen = #keyBytes
    local parts = {}
    local CHUNK = 4096
    for i = 1, #data, CHUNK do
        local chunk = {}
        local last = i + CHUNK - 1
        if (last > #data) then last = #data end
        for j = i, last do
            chunk[#chunk + 1] = bxor(data:byte(j), keyBytes[((j - 1) % keyLen) + 1])
        end
        parts[#parts + 1] = string.char(unpack(chunk))
    end
    return table.concat(parts)
end

function ReadHTMLTemplate(templateName)
    local html = CreateFrame("SimpleHTML", nil, nil, templateName)
    local regions = { html:GetRegions() }
    if (#regions == 0) then return nil end
    local parts = { }
    for _, region in ipairs(regions) do
        table.insert(parts, RemoveSpaces(region:GetText()))
    end
    return Base64.decode(table.concat(parts))
end

function LoadHTMLData(templateName, sandbox, decryptKey, expectedHash)
    local decoded = ReadHTMLTemplate(templateName)
    if (not decoded) then return nil end
    if (decryptKey) then
        decoded = xorDecrypt(decoded, decryptKey)
    end
    if (expectedHash and expectedHash ~= "") then
        local actualHash = CryptoService.Adler32Hex(decoded)
        if (actualHash ~= expectedHash) then
            return nil, "hash_mismatch"
        end
    end
    local f = loadstring("return " .. decoded)
    if (not f) then return nil end
    setfenv(f, sandbox or emptySandbox)
    local results = { pcall(f) }
    if (not results[1]) then return nil end
    return select(2, unpack(results))
end
