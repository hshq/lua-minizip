local version, postfix = '1.1', '1_1'
-- local version, postfix = 'dev', 'dev'

local mod_name = 'minizip_mem_ffi_' .. postfix
local so_name  = 'libminizip_' .. postfix

local ffi = require 'ffi'

local ext_name = (ffi.os == 'OSX' and 'dylib' or 'so')
local so_path  = ('./%s.%s'):format(so_name, ext_name)
so_path        = package.searchpath(so_name, package.cpath) or so_path
local MZ       = ffi.load(so_path)

local mod_path = package.searchpath(mod_name, package.path)
--local mod      = loadfile(mod_path)(MZ)
local ok, mod, msg = pcall(loadfile, mod_path)
assert(ok, mod)
assert(mod, msg)
mod = mod(MZ)

mod.version = version
return mod