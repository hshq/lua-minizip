local type     = type
local tonumber = tonumber
local print    = print
local os_time  = os.time
local os_date  = os.date
local format   = string.format
local band     = bit.band
local rshift   = bit.rshift

local ffi = require 'ffi'

local MZ = ...
local C  = ffi.C

-- @param cdata.zip_fileinfo zi
--      XXX 该结构与旧版不同，因此实现较C模块版简单
-- @param number|table       ts_or_date 时间戳或日期table
local function set_file_time(zi, ts_or_date)
    local ts, tm

    ts = tonumber(ts_or_date) or os_time(ts_or_date) or os_time()
    ts = ffi.new('const time_t[1]', ts)
    tm = ffi.new('struct tm[1]')
    C.localtime_r(ts, tm)

    zi.dos_date = MZ.tm_to_dosdate(tm)
end

-- @param cdata.unz_file_info file_info
-- @return string mtime
-- @return string dos_date
local function get_file_time(file_info)
    local mtime, dos_date

    local tm = ffi.new('struct tm')
    if MZ.dosdate_to_tm(file_info.dos_date, tm) < 0 then
        throw('Invalid dos_date')
    end

    --[[
    tm.year  = tm.year - 1900
    dos_date = tonumber(C.mktime(tm))
    tm.year  = tm.year + 1900
    -- XXX 时区缩写： ffi.string(tm.zone)
    -- XXX 时区偏移（秒）： tm.gmtoff
    --]]

    -- mtime    = os_date('%Y-%m-%d %H:%M:%S', dos_date)
    -- dos_date = ffi.string(C.ctime(ffi.new('uint64_t[1]', dos_date)))
    -- dos_date = os_date('%a %b %d %H:%M:%S %Y\n', dos_date)

    mtime = format('%u-%02u-%02u %02u:%02u:%02u',
        tm.year,
        tm.month + 1,
        tm.day,
        tm.hour,
        tm.min,
        tm.sec)

    return mtime, dos_date
end

local function debug_info(z)
    print(format('tell: %d\n', tonumber(MZ.unzTell(z.zf))))
end

return {
    set_file_time = set_file_time,
    get_file_time = get_file_time,
    debug_info    = debug_info,
}
