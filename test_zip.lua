
local type     = type
local print    = print
local pairs    = pairs
local tostring = tostring
local assert   = assert
local format   = string.format
local rep      = string.rep
local io_open  = io.open
local io_write = io.write
local os_date  = os.date
local os_time  = os.time

local mz = require 'minizip_ffi'
-- local zip        = mz.zip
local zip        = mz.zipTable
local comp_level = mz.comp_level

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
print(zip)
print()

dump_val(comp_level)
print()

local zf = assert(zip(comp_level.better + 10))
print(#zf, zf:len(), zf)
print()

local t = os_time()
local d = os_date('*t', t - 3600)
local t = t - 3600 *2
local fn = 'test_zip.lua'
local f = io_open(fn, 'r')
local s = f:read('*a')
f:close()

print('archive(empty.file)')
assert(zf:archive('empty.file', {comment = 'null file'}))
print(#zf, zf:len(), zf)
print()

print('archive(empty.dir/)')
assert(zf:archive('empty.dir/', {comment = 'null dir', date = d}))
print(#zf, zf:len(), zf)
print()

print('archive(' .. fn .. ')')
assert(zf:archive(fn, {comp_level = comp_level.faster, comment = 'lua file', date = t}, s))
print(#zf, zf:len(), zf)
print()

print('close:')
local stream = assert(zf:close('注释 by HSQ'))
print(#zf, zf:len(), zf)
print('#stream', #stream)
print()

--assert(zf:close('注释2 by HSQ'))

local fn = 'zip.zip'
print('save to ' .. fn)
local f = io_open(fn, 'w')
f:write(stream)
f:close()
print()

print('version:', mz.version)
print()
