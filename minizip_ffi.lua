local version, postfix = '1.1', '1_1'
-- local version, postfix = 'dev', 'dev'


local share_name = 'minizip_ffi_mem_share'
local so_name    = 'libminizip_' .. postfix

local ffi = require 'ffi'

local DIR_SEP = ffi.os == 'Windows' and '\\' or '/'

local mod_path = package.searchpath(share_name, package.path)
local pat      = '^(.*' .. DIR_SEP .. ')[^' .. DIR_SEP .. ']+'
local mod_dir  = mod_path:match(pat) or ''

local function read_all(filename)
    local fh  = assert(io.open(mod_dir .. filename, 'r'))
    local str = assert(fh:read('*a'))
    assert(fh:close())
    return str
end

ffi.cdef(read_all('minizip_ffi_mem_share.h'))
ffi.cdef(read_all('minizip_ffi_mem_' .. postfix .. '.h'))

local ext_name = (ffi.os == 'OSX' and 'dylib' or 'so')
local so_path  = ('./%s.%s'):format(so_name, ext_name)
so_path        = package.searchpath(so_name, package.cpath) or so_path
local MZ       = ffi.load(so_path)

local function load_mod(mod_name, ...)
    local mod_path = package.searchpath(mod_name, package.path)
    --local mod      = loadfile(mod_path)(...)
    local ok, mod, msg = pcall(loadfile, mod_path)
    assert(ok, mod)
    assert(mod, msg)
    return mod(...)
end

local mod = load_mod('minizip_ffi_mem_' .. postfix, MZ)
mod = load_mod(share_name, MZ, mod, DIR_SEP)

mod.version = version
return mod
