--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local band, bor, bxor, bnot = bit.band, bit.bor, bit.bxor, bit.bnot
local rshift, lshift = bit.rshift, bit.lshift
local floor, fmod = math.floor, math.fmod

local K256 = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function rrotate(x, n)
    return bor(rshift(x, n), lshift(band(x, 2^n - 1), 32 - n))
end

local function uint32(x)
    return band(x, 0xFFFFFFFF)
end

local function sha256Prepare(msg)
    local len = #msg
    local bits = len * 8
    msg = msg .. "\128"
    while (#msg % 64) ~= 56 do
        msg = msg .. "\0"
    end
    msg = msg .. "\0\0\0\0"
    msg = msg .. string.char(band(rshift(bits, 24), 0xFF))
    msg = msg .. string.char(band(rshift(bits, 16), 0xFF))
    msg = msg .. string.char(band(rshift(bits, 8), 0xFF))
    msg = msg .. string.char(band(bits, 0xFF))
    return {
        msg = msg,
        H = {
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
        },
        pos = 1,
    }
end

local function sha256Resume(state)
    local msg, H = state.msg, state.H
    while state.pos <= #msg do
        local i = state.pos
        local W = {}
        for t = 1, 16 do
            local offset = i + (t - 1) * 4
            W[t] = lshift(msg:byte(offset), 24) + lshift(msg:byte(offset + 1), 16)
                 + lshift(msg:byte(offset + 2), 8) + msg:byte(offset + 3)
        end
        for t = 17, 64 do
            local s0 = bxor(rrotate(W[t-15], 7), rrotate(W[t-15], 18), rshift(W[t-15], 3))
            local s1 = bxor(rrotate(W[t-2], 17), rrotate(W[t-2], 19), rshift(W[t-2], 10))
            W[t] = uint32(W[t-16] + s0 + W[t-7] + s1)
        end
        local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
        for t = 1, 64 do
            local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
            local ch = bxor(band(e, f), band(bnot(e), g))
            local temp1 = uint32(h + S1 + ch + K256[t] + W[t])
            local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
            local maj = bxor(band(a, b), band(a, c), band(b, c))
            local temp2 = uint32(S0 + maj)
            h = g; g = f; f = e; e = uint32(d + temp1)
            d = c; c = b; b = a; a = uint32(temp1 + temp2)
        end
        H[1] = uint32(H[1] + a)
        H[2] = uint32(H[2] + b)
        H[3] = uint32(H[3] + c)
        H[4] = uint32(H[4] + d)
        H[5] = uint32(H[5] + e)
        H[6] = uint32(H[6] + f)
        H[7] = uint32(H[7] + g)
        H[8] = uint32(H[8] + h)
        state.pos = state.pos + 64
    end
    local result = ""
    for i = 1, 8 do
        result = result .. string.char(band(rshift(H[i], 24), 0xFF))
        result = result .. string.char(band(rshift(H[i], 16), 0xFF))
        result = result .. string.char(band(rshift(H[i], 8), 0xFF))
        result = result .. string.char(band(H[i], 0xFF))
    end
    state.result = result
    state.done = true
end

local function sha256(msg)
    local state = sha256Prepare(msg)
    sha256Resume(state)
    return state.result
end

local LIMB_BITS = 24
local LIMB_BASE = 2^LIMB_BITS
local LIMB_MASK = LIMB_BASE - 1

local function bigFromBytes(bytes)
    local n = {}
    for i = 1, #bytes do
        local byte = bytes:byte(i)
        local carry = byte
        for j = 1, #n do
            local val = n[j] * 256 + carry
            n[j] = band(val, LIMB_MASK)
            carry = rshift(val, LIMB_BITS)
        end
        while carry > 0 do
            n[#n + 1] = band(carry, LIMB_MASK)
            carry = rshift(carry, LIMB_BITS)
        end
    end
    if #n == 0 then n[1] = 0 end
    return n
end

local function bigFromHex(hex)
    local bytes = ""
    for i = 1, #hex, 2 do
        bytes = bytes .. string.char(tonumber(hex:sub(i, i + 1), 16))
    end
    return bigFromBytes(bytes)
end

local function bigToBytes(n, length)
    local temp = {}
    for i = 1, #n do temp[i] = n[i] end

    local bytes = {}
    while #temp > 0 do
        local carry = 0
        local newTemp = {}
        for i = #temp, 1, -1 do
            local val = carry * LIMB_BASE + temp[i]
            local q = floor(val / 256)
            carry = val - q * 256
            if q > 0 or #newTemp > 0 then
                newTemp[#newTemp + 1] = q
            end
        end
        bytes[#bytes + 1] = carry
        local reversed = {}
        for i = #newTemp, 1, -1 do
            reversed[#reversed + 1] = newTemp[i]
        end
        temp = reversed
    end

    local result = ""
    for i = #bytes, 1, -1 do
        result = result .. string.char(bytes[i])
    end

    if length and #result < length then
        result = string.rep("\0", length - #result) .. result
    end

    return result
end

local function bigCompare(a, b)
    if #a ~= #b then return #a > #b and 1 or -1 end
    for i = #a, 1, -1 do
        if a[i] ~= b[i] then return a[i] > b[i] and 1 or -1 end
    end
    return 0
end

local function bigTrim(n)
    while #n > 1 and n[#n] == 0 do
        n[#n] = nil
    end
    return n
end

local function bigSub(a, b)
    local result = {}
    local borrow = 0
    for i = 1, #a do
        local diff = (a[i] or 0) - (b[i] or 0) - borrow
        if diff < 0 then
            diff = diff + LIMB_BASE
            borrow = 1
        else
            borrow = 0
        end
        result[i] = diff
    end
    return bigTrim(result)
end

local function bigMul(a, b)
    local result = {}
    for i = 1, #a + #b do result[i] = 0 end
    for i = 1, #a do
        local carry = 0
        local ai = a[i]
        for j = 1, #b do
            local prod = result[i + j - 1] + ai * b[j] + carry
            result[i + j - 1] = fmod(prod, LIMB_BASE)
            carry = floor(prod / LIMB_BASE)
        end
        if carry > 0 then
            result[i + #b] = result[i + #b] + carry
        end
    end
    return bigTrim(result)
end

local function bigMulLow(a, b, maxLimbs)
    local result = {}
    for i = 1, maxLimbs do result[i] = 0 end
    for i = 1, #a do
        if i > maxLimbs then break end
        local carry = 0
        local ai = a[i]
        local jmax = maxLimbs - i + 1
        if jmax > #b then jmax = #b end
        for j = 1, jmax do
            local prod = result[i + j - 1] + ai * b[j] + carry
            result[i + j - 1] = fmod(prod, LIMB_BASE)
            carry = floor(prod / LIMB_BASE)
        end
        if i + jmax <= maxLimbs and carry > 0 then
            result[i + jmax] = result[i + jmax] + carry
        end
    end
    return result
end

local function bigShiftRight(a, limbs)
    if limbs >= #a then return {0} end
    local result = {}
    for i = limbs + 1, #a do
        result[#result + 1] = a[i]
    end
    if #result == 0 then result[1] = 0 end
    return result
end

local function bigTruncate(a, limbs)
    local result = {}
    for i = 1, limbs do
        result[i] = a[i] or 0
    end
    return bigTrim(result)
end

local function bigDivModSlow(a, b)
    if bigCompare(a, b) < 0 then
        local rem = {}
        for i = 1, #a do rem[i] = a[i] end
        return {0}, rem
    end
    local u = {}
    for i = 1, #a do u[i] = a[i] end
    local q = {}
    for i = 1, #a do q[i] = 0 end
    local rem = {0}
    local totalBits = #a * LIMB_BITS
    for i = totalBits - 1, 0, -1 do
        local carry = 0
        for j = 1, #rem do
            local val = lshift(rem[j], 1) + carry
            rem[j] = band(val, LIMB_MASK)
            carry = rshift(val, LIMB_BITS)
        end
        if carry > 0 then rem[#rem + 1] = carry end
        local limbIdx = floor(i / LIMB_BITS) + 1
        local bitIdx = i - (limbIdx - 1) * LIMB_BITS
        local bitVal = band(rshift(u[limbIdx] or 0, bitIdx), 1)
        rem[1] = bor(rem[1], bitVal)
        if bigCompare(rem, b) >= 0 then
            rem = bigSub(rem, b)
            local qLimb = floor(i / LIMB_BITS) + 1
            local qBit = i - (qLimb - 1) * LIMB_BITS
            q[qLimb] = bor(q[qLimb] or 0, lshift(1, qBit))
        end
    end
    return bigTrim(q), bigTrim(rem)
end

local function createBarrettContext(n)
    local k = #n
    local b2k = {}
    for i = 1, 2 * k + 1 do b2k[i] = 0 end
    b2k[2 * k + 1] = 1
    local mu = bigDivModSlow(b2k, n)
    return { n = n, k = k, mu = mu }
end

local function barrettReduce(x, ctx)
    local n, k, mu = ctx.n, ctx.k, ctx.mu
    if bigCompare(x, n) < 0 then return x end

    local q1 = bigShiftRight(x, k - 1)
    local q2 = bigMul(q1, mu)
    local q3 = bigShiftRight(q2, k + 1)

    local r1 = bigTruncate(x, k + 1)
    local r2 = bigMulLow(q3, n, k + 1)

    local r
    if bigCompare(r1, r2) >= 0 then
        r = bigSub(r1, r2)
    else
        local borrow = {}
        for i = 1, k + 2 do borrow[i] = 0 end
        borrow[k + 2] = 1
        r = bigSub(bigTrim(borrow), bigSub(r2, r1))
    end

    while bigCompare(r, n) >= 0 do
        r = bigSub(r, n)
    end
    return bigTrim(r)
end

local function bigModPowPrepare(base, mod)
    local ctx = createBarrettContext(mod)
    local power = {}
    for i = 1, #base do power[i] = base[i] end
    local result = {}
    for i = 1, #base do result[i] = base[i] end
    return {
        ctx = ctx,
        power = power,
        result = result,
        step = 1,
    }
end

local function bigModPowResume(state)
    local ctx = state.ctx
    local function mulmod(a, b)
        return barrettReduce(bigMul(a, b), ctx)
    end
    while state.step <= 17 do
        if (state.step <= 16) then
            state.power = mulmod(state.power, state.power)
        else
            state.result = mulmod(state.result, state.power)
        end
        state.step = state.step + 1
    end
    state.done = true
end

local PKCS1_SHA256_PREFIX = "\048\049\048\013\006\009\096\134\072\001\101\003\004\002\001\005\000\004\032"

local function rsaVerifyResumable(state)
    if (state.phase == "init") then
        state.n = bigFromHex(state.nHex)
        state.sig = bigFromBytes(state.sigBytes)
        state.modpow = bigModPowPrepare(state.sig, state.n)
        state.phase = "modpow"
    end
    if (state.phase == "modpow") then
        bigModPowResume(state.modpow)
        if (not state.modpow.done) then return end
        local decBytes = bigToBytes(state.modpow.result, 256)
        if (decBytes:byte(1) ~= 0 or decBytes:byte(2) ~= 1) then
            state.done = true
            state.result = false
            return
        end
        local i = 3
        while i <= #decBytes and decBytes:byte(i) == 0xFF do
            i = i + 1
        end
        if (i <= #decBytes and decBytes:byte(i) ~= 0) then
            state.done = true
            state.result = false
            return
        end
        i = i + 1
        local remaining = decBytes:sub(i)
        if (remaining:sub(1, #PKCS1_SHA256_PREFIX) ~= PKCS1_SHA256_PREFIX) then
            state.done = true
            state.result = false
            return
        end
        state.expectedHash = remaining:sub(#PKCS1_SHA256_PREFIX + 1)
        state.sha256 = sha256Prepare(state.message)
        state.phase = "sha256"
    end
    if (state.phase == "sha256") then
        sha256Resume(state.sha256)
        if (not state.sha256.done) then return end
        state.done = true
        state.result = (state.expectedHash == state.sha256.result)
    end
end

CryptoService = {}

function CryptoService.BeginVerify(signedContent, signatureBase64, publicKeyHex)
    local sigBytes = Base64.decode(signatureBase64)
    if (not sigBytes or #sigBytes ~= 256) then return nil end
    return {
        phase = "init",
        nHex = publicKeyHex,
        sigBytes = sigBytes,
        message = signedContent,
        done = false,
        result = false,
    }
end

function CryptoService.ContinueVerify(state)
    if (state.done) then return true end
    pcall(rsaVerifyResumable, state)
    return state.done
end

function CryptoService.GetResult(state)
    return state.result
end

function CryptoService.Adler32Hex(data)
    local s1 = 1
    local s2 = 0
    local MOD = 65521
    for i = 1, #data do
        s1 = (s1 + data:byte(i)) % MOD
        s2 = (s2 + s1) % MOD
    end
    return string.format("%08x", s2 * 65536 + s1)
end

