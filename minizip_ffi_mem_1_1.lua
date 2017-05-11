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
-- @param number|table       ts_or_date 时间戳或日期table
local function set_file_time(zi, ts_or_date)
    local date = ts_or_date
    if type(ts_or_date) ~= 'table' then
        date = os_date('*t', tonumber(ts_or_date))
    end

    date = date or os_date('*t')

    -- date.month = date.month - 1
    -- ffi.copy(zi.tmz_date, ffi.new('tm_zip', date), ffi.sizeof('tm_zip'))
    -- zi.tmz_date = ffi.new('tm_zip', date) -- XXX tmz_date 不是指针，因此这里==copy
    zi.tmz_date.year  = date.year
    zi.tmz_date.month = date.month - 1
    zi.tmz_date.day   = date.day
    zi.tmz_date.hour  = date.hour
    zi.tmz_date.min   = date.min
    zi.tmz_date.sec   = date.sec
    zi.dosDate        = 0
end

-- from minizip/minishared.c::dosdate_to_tm
-- Convert dos date/time format to timestamp
-- @param number dos_date
-- @return int
local function dosdate_to_time(dos_date)
    dos_date = tonumber(dos_date) -- LuaJIT v2.0: cdata.整数 不能直接运算
    local date = rshift(dos_date, 16)

    local d = {
        year  = band(date, 0x0FE00) / 0x0200 + 1980,
        month = band(date, 0x1E0) / 0x20,
        day   = band(date, 0x1f),
        hour  = band(dos_date, 0xF800) / 0x800,
        min   = band(dos_date, 0x7E0) / 0x20,
        sec   = band(dos_date, 0x1f) * 2,
    }
    return os_time(d), d
end

-- @param cdata.unz_file_info file_info
-- @return string mtime
-- @return string dos_date
local function get_file_time(file_info)
    local mtime, dos_date

    -- dos_date = dosdate_to_time(file_info.dosDate)

    -- mtime    = os_date('%Y-%m-%d %H:%M:%S', dos_date)
    -- dos_date = ffi.string(C.ctime(ffi.new('uLong[1]', dos_date)))
    -- dos_date = os_date('%a %b %d %H:%M:%S %Y\n', dos_date)

    local tm = file_info.tmu_date
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
    print(format('tell: %d, eof: %d\n',
                tonumber(MZ.unztell(z.zf)), tonumber(MZ.unzeof(z.zf))))
end

return {
    set_file_time = set_file_time,
    get_file_time = get_file_time,
    debug_info    = debug_info,
}
