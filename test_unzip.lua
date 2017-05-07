
local type     = type
local print    = print
local pairs    = pairs
local tostring = tostring
local assert   = assert
local format   = string.format
local rep      = string.rep
local io_write = io.write
local io_read  = io.read
local io_input = io.input

local mz = require 'minizip_ffi'
-- local unzip = mz.unzip
local unzip = mz.unzipTable

local function dump_val(val)
    if type(val) ~= 'table' then
        print(val)
        return
    end
    local max_len = 0
    for k in pairs(val) do
        len = #tostring(k)
        max_len = len > max_len and len or max_len
    end
    for k, v in pairs(val) do
        len = #tostring(k)
        if type(v) == 'string' then
            print(rep(' ', max_len - len) .. k, format('%q', v))
        else
            print(rep(' ', max_len - len) .. k, v)
        end
    end
end

print()
--print(unzip)
--print()

--io_input('./data/_io5-1.zip')
io_input('./zip.zip')
local zs = io_read('*a')
--print(#zs)
--print()

local uf = assert(unzip(zs))
print(uf)
print('#uf:', #uf)
print()

local ufi = {uf:info()}
dump_val(ufi)
print()

print('first:', uf:first())
print(uf)
print()
--local ufs = assert(uf:stat())
--dump_val(ufs)
--print()

print('first:', uf:first())
while true do
    local ufs = assert(uf:stat())
    dump_val(ufs)
    print()
    local ok, err = uf:next()
    if not ok and err == 'EOL' then
        break
    end
    print('next:', ok)
end
print()

--print('locate:', uf:locate('minizip-master/zip.c'))
print('locate:', uf:locate('test_zip.lua'))
print(uf)
print()
local ufs = assert(uf:stat())
dump_val(ufs)
print()

--local content = assert(uf:extract())
local content = assert(uf:extract(nil, 1024))
print(uf)
print()
print('<<< extract: #' .. #content)
io_write(content)
print('>>>')
print()

--print('locate:', uf:locate('minizip-master/data/ioapi_mem.h2'))

--print('first:', uf:first())
--print('next:', uf:next())

print('close:', uf:close(), uf)
print()

