
local cdecl_mz_t = [[
    typedef struct $ {
        //zlib_filefunc_def filefunc32;
        zipFile     zf;
        ourmemory_t mem;
        bool        zip_opend;
        bool        file_opend;
        $           $;
    } $;
]]


local ffi = require 'ffi'

ffi.cdef(cdecl_mz_t, 'zip_s', ffi.typeof('int8_t'), 'comp_level', 'zip_t')
-- XXX 'buf[?]': 无需另外释放了；这里是FFI扩展的VLS语法
-- XXX char buf[?]; -> char[?] buf
ffi.cdef(cdecl_mz_t, 'unzip_s', ffi.typeof('char[?]'), 'buf', 'unzip_t')

local MZ, mod, DIR_SEP = ...
local set_file_time = mod.set_file_time
local get_file_time = mod.get_file_time
local debug_info    = mod.debug_info

local C  = ffi.C

local Z_OK = MZ.Z_OK

local retCodes = {
    --[MZ.Z_OK]                  = 'ok',
    --[MZ.Z_EOF]                 = 'end of file',
    [MZ.Z_OK]                    = 'ok | eof',
    --[MZ.Z_ERRNO]               = 'zlib errno',
    --[MZ.Z_ERRNO]               = C.strerror(errno),
    --[MZ.Z_END_OF_LIST_OF_FILE] = 'end of list (file)',
    [MZ.Z_END_OF_LIST_OF_FILE]   = 'EOL',
    [MZ.Z_PARAMERROR]            = 'parametor error',
    [MZ.Z_BADZIPFILE]            = 'bad zipfile',
    [MZ.Z_INTERNALERROR]         = 'internal error',
    [MZ.Z_CRCERROR]              = 'crc error',
    [MZ.Z_STREAM_END]            = 'zlib end of stream',
    [MZ.Z_NEED_DICT]             = 'zlib need dict',
    [MZ.Z_STREAM_ERROR]          = 'zlib stream error',
    [MZ.Z_DATA_ERROR]            = 'zlib data error',
    [MZ.Z_MEM_ERROR]             = 'zlib mem error',
    [MZ.Z_BUF_ERROR]             = 'zlib buf error',
    [MZ.Z_VERSION_ERROR]         = 'zlib version error',
}

--[[
XXX base on miniunz.c & minizip.c

XXX File:    APPNOTE.TXT - .ZIP File Format Specification
        https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT
XXX ZipFile Layout
        http://result42.com/projects/ZipFileLayout
--]]

--local TIME_STR_SIZE       = 64
-- XXX 这些限制参考 zip 规范（2字节）
local GLOBAL_COMMENT_SIZE = 64 * 1024
local FILE_COMMENT_SIZE   = 64 * 1024
local FILE_NAME_SIZE      = 64 * 1024

local DUMMY_FILE_PATH = '__notused__'

local COMPRESS_LEVEL_LIST = {
    [MZ.Z_DEFAULT_COMPRESSION] = 'default',
    [MZ.Z_NO_COMPRESSION]      = 'store',
    [MZ.Z_BEST_SPEED]          = 'faster',
    [MZ.Z_BEST_COMPRESSION]    = 'better',
}


local type          = type
local pairs         = pairs
local error         = error
local tonumber      = tonumber
local setmetatable  = setmetatable
--local throw       = error
local print         = print
local format        = string.format
local concat        = table.concat
local rshift        = bit.rshift
local band          = bit.band


setfenv(1, {})


local function normalize_comp_level(level)
    if level ~= MZ.Z_DEFAULT_COMPRESSION and level ~= MZ.Z_NO_COMPRESSION then
        if level < MZ.Z_BEST_SPEED then
            return MZ.Z_BEST_SPEED
        elseif level > MZ.Z_BEST_COMPRESSION then
            return MZ.Z_BEST_COMPRESSION
        end
    end
    return level
end


local comp_level = {}
for level, name in pairs(COMPRESS_LEVEL_LIST) do
    comp_level[name] = level
end

local function throw(err)
    --print(debug.traceback())
    return error(err, 2)
end

local function check_mz(typ, id_field)
    return function(z)
        if not ffi.istype(typ, z) then
            local t = type(z)
            if t ~= 'table' or not ffi.istype('ourmemory_t', z.mem) or not z[id_field] then
                throw(('arg#1: expect %s, got %s'):format(typ, t))
            end
        end
    end
end

local check_zip   = check_mz('zip_t', 'comp_level')
local check_unzip = check_mz('unzip_t', 'buf')

local function check_type(num, var, typ)
    local typ2 = type(var)
    if not typ:match(typ2) then
        throw(('arg#%d: expect %s, got %s'):format(num, typ, typ2))
    end
end

local function throw_zerr(err)
    if err == MZ.Z_ERRNO then
        return throw(C.strerror(ffi.errno()))
    end
    throw(retCodes[err] or 'unknown error')
end

local function check_eol(err, return_eol)
    if err == MZ.Z_END_OF_LIST_OF_FILE then
        if return_eol then
            return nil, 'EOL'
        else
            throw('EOL')
        end
    end
    if err ~= Z_OK then
        throw_zerr(err)
    end
    return true
end


local meta_zip
local meta_unzip

-- @param  int      level?  -1, 0, 1 - 9
-- @return userdata zip
local function zip(level)
    check_type(1, level, 'number|nil')
    level = normalize_comp_level(level or MZ.Z_DEFAULT_COMPRESSION)

    local z          = ffi.new('zip_t')
    local filefunc32 = ffi.new('zlib_filefunc_def') -- XXX zipOpen2 后即可丢弃

    --[[
    z.zf         = nil
    -- { base, size, limit, cur_offset, grow }
    z.mem        = { nil, 0, 0, 0, 0 }
    --]]
    z.zip_opend  = false
    z.file_opend = false
    z.comp_level = level
    z.mem.grow   = 1

    MZ.fill_memory_filefunc(filefunc32, z.mem)
    z.zf = MZ.zipOpen2(DUMMY_FILE_PATH, MZ.APPEND_STATUS_CREATE, nil, filefunc32)
    if z.zf == nil then
        throw('cannot open')
    end
    z.zip_opend = true

    return z
end

-- @param  int      level?  -1, 0, 1 - 9
-- @return table zip
local function zipTable(level)
    check_type(1, level, 'number|nil')
    level = normalize_comp_level(level or MZ.Z_DEFAULT_COMPRESSION)

    local filefunc32 = ffi.new('zlib_filefunc_def') -- XXX zipOpen2 后即可丢弃

    local z = {
        zf         = nil, -- ffi.new('zipFile'),
        -- { base, size, limit, cur_offset, grow }
        mem        = ffi.new('ourmemory_t'),
        zip_opend  = false,
        file_opend = false,
        comp_level = level,
    }
    z.mem.grow = 1

    MZ.fill_memory_filefunc(filefunc32, z.mem)
    z.zf = MZ.zipOpen2(DUMMY_FILE_PATH, MZ.APPEND_STATUS_CREATE, nil, filefunc32)
    if z.zf == nil then
        throw('cannot open')
    end
    z.zip_opend = true

    -- XXX 对于 table 实现，gc 时不会调用 m_gc 。
    ffi.gc(z.mem, function(_) meta_zip.__gc(z) end)

    return setmetatable(z, meta_zip)
end


-- @param  string   zip_string
-- @return userdata unzip
local function unzip(buf)
    check_type(1, buf, 'string')

    local buf_len = #buf

    local z          = ffi.new('unzip_t', buf_len)
    local filefunc32 = ffi.new('zlib_filefunc_def') -- XXX zipOpen2 后即可丢弃

    --[[
    z.zf         = nil
    -- { base, size, limit, cur_offset, grow }
    z.mem        = { nil, 0, 0, 0, 0 }
    --]]
    z.zip_opend  = false
    z.file_opend = false
    z.mem.base   = z.buf
    z.mem.size   = buf_len
    ffi.copy(z.buf, buf, buf_len)

    MZ.fill_memory_filefunc(filefunc32, z.mem)
    z.zf = MZ.unzOpen2(DUMMY_FILE_PATH, filefunc32)
    if z.zf == nil then
        throw('cannot open')
    end
    z.zip_opend = true

    return z
end

-- @param  string   zip_string
-- @return table unzip
local function unzipTable(buf)
    check_type(1, buf, 'string')

    local buf_len = #buf

    local filefunc32 = ffi.new('zlib_filefunc_def') -- XXX zipOpen2 后即可丢弃

    local z = {
        zf         = nil, -- ffi.new('zipFile'),
        -- { base, size, limit, cur_offset, grow }
        mem        = ffi.new('ourmemory_t'),
        zip_opend  = false,
        file_opend = false,
        -- XXX cdata A 指针引用 cdata B 不会避免 B 被 GC
        buf        = ffi.new('char[?]', buf_len, buf),
    }
    z.mem.base = z.buf
    z.mem.size = buf_len

    MZ.fill_memory_filefunc(filefunc32, z.mem)
    z.zf = MZ.unzOpen2(DUMMY_FILE_PATH, filefunc32)
    if z.zf == nil then
        throw('cannot open')
    end
    z.zip_opend = true

    -- XXX 对于 table 实现，gc 时不会调用 m_gc 。
    ffi.gc(z.mem, function(_) meta_unzip.__gc(z) end)

    return setmetatable(z, meta_unzip)
end


-- @param  userdata zip
-- @param  string   comment
-- @return string   stream
local function m_close_zip(z, comment)
    check_zip(z)
    if not z.zip_opend then
        throw('zip closed')
    end

    check_type(2, comment, 'string|nil')

    local errf = Z_OK

    if z.file_opend then
        z.file_opend = false
        errf         = MZ.zipCloseFileInZip(z.zf)
    end

    z.zip_opend = false
    local err   = MZ.zipClose(z.zf, comment)

    --local stream = ffi.string(z.mem.base):sub(1, z.mem.limit)
    local stream = ffi.string(z.mem.base, z.mem.limit)

    C.free(z.mem.base) -- XXX 需要调用者释放zip数据的存储

    if err ~= Z_OK then
        throw_zerr(err)
    end

    if errf ~= Z_OK then
        throw_zerr(errf)
    end

    return stream
end

-- @param  userdata unzip
-- @return true
local function m_close_unzip(z)
    check_unzip(z)
    if not z.zip_opend then
        throw('zip closed')
    end

    local errf = Z_OK

    if z.file_opend then
        z.file_opend = false
        -- XXX unzOpenCurrentFile 后必须 close ，然后再 unzClose
        errf         = MZ.unzCloseCurrentFile(z.zf)
    end

    z.zip_opend = false
    local err   = MZ.unzClose(z.zf)

    if err ~= Z_OK then
        throw_zerr(err)
    end

    if errf ~= Z_OK then
        throw_zerr(errf)
    end

    return true
end

-- @param  userdata zip
local function m_gc_zip(z)
    check_zip(z)
    if not z.zip_opend then
        return
    end

    if z.file_opend then
        z.file_opend = false
        MZ.zipCloseFileInZip(z.zf)
    end

    z.zip_opend = false
    MZ.zipClose(z.zf, nil)

    C.free(z.mem.base) -- XXX 需要调用者释放zip数据的存储
end

-- @param  userdata zip
local function m_gc_unzip(z)
    check_unzip(z)
    if not z.zip_opend then
        return
    end

    if z.file_opend then
        z.file_opend = false
        MZ.unzCloseCurrentFile(z.zf)
    end

    z.zip_opend = false
    MZ.unzClose(z.zf)
end

-- 返回 文件数、注释、diskCD数
-- @param userdata unzip
-- @return int     file_num
-- @return string  comment
-- @return int     number_disk_with_CD
local function m_info_unzip(z)
    check_unzip(z)

    local err = Z_OK
    local global_info = ffi.new('unz_global_info')

    local comment = ffi.new('char[?]', GLOBAL_COMMENT_SIZE)

    err = MZ.unzGetGlobalInfo(z.zf, global_info)
    if err ~= Z_OK then
        throw_zerr(err)
    end

    err = MZ.unzGetGlobalComment(z.zf, comment, global_info.size_comment)
    if err < 0 then
        throw_zerr(err)
    end
    --comment[global_info.size_comment] = 0x0 -- XXX 不需要?
    --comment = ffi.string(comment)
    comment = ffi.string(comment, global_info.size_comment)

    return  tonumber(global_info.number_entry),
            comment,
            tonumber(global_info.number_disk_with_CD)
end

-- @param userdata zip
-- @return int     stream_len
local function m_len_zip(z)
    check_zip(z)
    return tonumber(z.mem.limit) -- XXX print() 带后缀 ULL 或 LL 表明是 cdata
end

-- @param userdata unzip
-- @return int     file_num
local function m_len_unzip(z)
    check_unzip(z)
    return (m_info_unzip(z))
end

-- @param userdata zip
-- @return string
local function m_tostring_zip(z)
    check_zip(z)

    local tpl = '{userdata: zip, comp_level: %d, comp_level_name: %s' ..
        ', zip_opend: %s, file_opend: %s}'

    return tpl:format(z.comp_level,
            COMPRESS_LEVEL_LIST[z.comp_level] or 'normal',
            z.zip_opend,
            z.file_opend)
end

-- @param userdata unzip
-- @return string
local function m_tostring_unzip(z)
    check_unzip(z)

    return ('{userdata: unzip, zip_opend: %s, file_opend: %s}'):format(
            z.zip_opend,
            z.file_opend)
end

-- @param  userdata zip
-- @param  string   filepath    目录分隔符收尾的作为目录，其他为文件
-- @param  table?   opts
--      {comp_level?, comment?, date? = os.time()|os.date('*t')}
-- @param  string?  content
-- @return true
local function m_file_archive_zip(z, filepath, opts, content)
    check_zip(z)
    check_type(2, filepath, 'string')
    if content ~= nil then
        check_type(3, opts, 'table|nil')
        check_type(4, content, 'string|nil')
    elseif type(opts) == 'string' then
        content, opts = opts, nil
    else
        check_type(3, opts, 'table|nil')
    end

    local err  = Z_OK
    local errf = Z_OK

    filepath = filepath:match('[^' .. DIR_SEP .. '].*')
    if filepath == '' then
        throw('invalid filepath')
    end

    local comp_level = z.comp_level
    local comment
    local date

    if opts then
        comp_level = tonumber(opts.comp_level) or comp_level
        comp_level = normalize_comp_level(comp_level)

        comment = opts.comment
        date    = opts.date
    end

    local zi = ffi.new('zip_fileinfo')
    set_file_time(zi, date)
    -- zi.internal_fa = 0
    -- zi.external_fa = 0

    err = MZ.zipOpenNewFileInZip(z.zf, filepath, zi,
            nil, 0, nil, 0, comment,
            (comp_level ~= MZ.Z_NO_COMPRESSION) and MZ.Z_DEFLATED or 0,
            comp_level)
    if err ~= Z_OK then
        throw_zerr(err)
    end
    z.file_opend = true

    local is_file = filepath:sub(-1) ~= DIR_SEP
    if is_file and content and content ~= '' then
        errf = MZ.zipWriteInFileInZip(z.zf, content, #content)
    end

    err = MZ.zipCloseFileInZip(z.zf)
    z.file_opend = false

    if errf < 0 then
        throw_zerr(errf)
    end
    if err ~= Z_OK then
        throw_zerr(err)
    end

    return true
end

-- @param  userdata unzip
-- @return true
local function m_file_first_unzip(z)
    check_unzip(z)

    local err = MZ.unzGoToFirstFile(z.zf)
    if err ~= Z_OK then
        throw_zerr(err)
    end

    return true
end

-- @param  userdata unzip
-- @return true | nil, 'EOL'
local function m_file_next_unzip(z)
    check_unzip(z)

    local err = MZ.unzGoToNextFile(z.zf)
    local cont, msg = check_eol(err, true)
    if not cont then
        return cont, msg
    end

    return true
end

-- @param  userdata unzip
-- @param  string   filepath
-- @return true | nil, 'EOL'
local function m_file_locate_unzip(z, filepath)
    check_unzip(z)
    check_type(2, filepath, 'string')

    -- XXX 第三参数是文件名比较函数，可用于不区分大小写定位等
    -- typedef int (*unzFileNameComparer)(unzFile file,
            -- const char *filename1, const char *filename2);
    local err = MZ.unzLocateFile(z.zf, filepath, nil)
    local cont, msg = check_eol(err, true)
    if not cont then
        return cont, msg
    end

    return true
end

-- @param  userdata unzip
-- @param  string?  filepath
-- @return table
local function m_file_stat_unzip(z, filepath)
    check_unzip(z)
    check_type(2, filepath, 'string|nil')

    local file_info = ffi.new('unz_file_info'--[[, {
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, {0, 0, 0, 0, 0, 0}, 0,
    }]])
    local file_pos  = ffi.new('unz_file_pos', {0, 0})

    --local time_buf       = ffi.new('char[?]', TIME_STR_SIZE)
    -- file_info.size_filename
    local filename_inzip = ffi.new('char[?]', FILE_NAME_SIZE)
    -- file_info.size_file_comment
    local comment        = ffi.new('char[?]', FILE_COMMENT_SIZE)

    local string_method
    local err = Z_OK

    if filepath then
        err = MZ.unzLocateFile(z.zf, filepath, nil)
        check_eol(err, false)
    end

    err = MZ.unzGetCurrentFileInfo(z.zf, file_info,
            filename_inzip, FILE_NAME_SIZE,
            nil, 0, comment, FILE_COMMENT_SIZE) -- nil, 0, nil, 0
    if err ~= Z_OK then
        throw_zerr(err)
    end

    err = MZ.unzGetFilePos(z.zf, file_pos)
    if err ~= Z_OK then
        throw_zerr(err)
    end

    if file_info.compression_method == MZ.Z_STORE then
        string_method = 'Stored'
    elseif file_info.compression_method == MZ.Z_DEFLATED then
        local flag = rshift(band(tonumber(file_info.flag), 0x6), 1)
        if flag == 0 then
            string_method = 'Defl:N'
        elseif flag == 1 then
            string_method = 'Defl:X'
        elseif flag == 2 or flag == 3 then
            -- 2:fast , 3 : extra fast
            string_method = 'Defl:F'
        end
    elseif file_info.compression_method == MZ.Z_BZIP2ED then
        string_method = 'BZip2 '
    else
        string_method = 'Unkn. '
    end

    local mtime, dos_date = get_file_time(file_info)

    return {
        -- XXX 字段名兼容lua-zip
        name             = ffi.string(filename_inzip),
        index            = tonumber(file_pos.num_of_file + 1),
        crc              = format('%x', tonumber(file_info.crc)),
        -- crc           = format('%lx', tonumber(file_info.crc)),
        -- crc_num       = tonumber(file_info.crc),
        size             = tonumber(file_info.uncompressed_size),
        comp_size        = tonumber(file_info.compressed_size),
        comp_method      = tonumber(file_info.compression_method),
        comp_method_name = string_method,
        mtime            = mtime,
        -- dos_date         = dos_date,
        crypt            = file_info.flag % 2 == 1,
        version_needed   = tonumber(file_info.version_needed),
        comment          = ffi.string(comment),
        -- offset        = tonumber(MZ.unzGetOffset(z.zf)),
        offset           = tonumber(file_pos.pos_in_zip_directory),
        --[[
        version          = tonumber(file_info.version),
        flag             = tonumber(file_info.flag),
        size_file_extra  = tonumber(file_info.size_file_extra),
        internal_fa      = tonumber(file_info.internal_fa),
        external_fa      = tonumber(file_info.external_fa),
        disk_num_start   = tonumber(file_info.disk_num_start),
        disk_offset      = tonumber(file_info.disk_offset),
        --]]
    }
end

-- @param  userdata unzip
-- @param  string?  filepath
-- @return string
local function m_file_extract_unzip(z, filepath, buf_size)
    check_unzip(z)
    check_type(2, filepath, 'string|nil')
    check_type(3, buf_size, 'number|nil')

    local err  = Z_OK
    local errf = Z_OK

    if filepath then
        err = MZ.unzLocateFile(z.zf, filepath, nil)
        check_eol(err, false)
    end

    err = MZ.unzOpenCurrentFile(z.zf)
    if err ~= Z_OK then
        throw_zerr(err)
    end
    z.file_opend = true

    --[[ XXX 一次读取
    local file_info = ffi.new('unz_file_info')
    MZ.unzGetCurrentFileInfo(z.zf, file_info, nil, 0, nil, 0, nil, 0)
    local buf_size = tonumber(file_info.uncompressed_size)
    --]]
    buf_size   = (buf_size and buf_size > 0) and buf_size or 4096 -- BUFSIZ 4k
    local buf  = ffi.new('char[?]', buf_size)
    --local buf  = ffi.new('voidp[?]', buf_size)
    local bufs = {}

    repeat
        -- XXX unzOpenCurrentFile 后调用有效，出错则返回值<0
        -- debug_info(z)
        err = MZ.unzReadCurrentFile(z.zf, buf, buf_size)
        if err <= 0 then -- 0: eof
            break
        end
        bufs[#bufs + 1] = ffi.string(buf, err)
    until err ~= buf_size -- err <= 0

    -- XXX unzOpenCurrentFile 后必须 close
    errf = MZ.unzCloseCurrentFile(z.zf)
    z.file_opend = false

    if err < 0 then
        throw_zerr(err)
    end
    if errf ~= Z_OK then
        throw_zerr(errf)
    end

    return concat(bufs)
end

meta_zip = {
    __len      = m_len_zip,
    __tostring = m_tostring_zip,
    __gc       = m_gc_zip,

    __index = {
        len     = m_len_zip, -- XXX 对于 table 实现，# 操作符不会调用 m_len 。
        close   = m_close_zip,
        archive = m_file_archive_zip,
    },
}

meta_unzip = {
    __len      = m_len_unzip,
    __tostring = m_tostring_unzip,
    __gc       = m_gc_unzip,

    __index = {
        len     = m_len_unzip, -- XXX 对于 table 实现，# 操作符不会调用 m_len 。
        close   = m_close_unzip,
        info    = m_info_unzip,

        first   = m_file_first_unzip,
        next    = m_file_next_unzip,
        locate  = m_file_locate_unzip,
        stat    = m_file_stat_unzip,
        extract = m_file_extract_unzip,
    },
}

ffi.metatype('zip_t', meta_zip)
ffi.metatype('unzip_t', meta_unzip)


return {
    comp_level = comp_level,
    zip        = zip,
    zipTable   = zipTable,
    unzip      = unzip,
    unzipTable = unzipTable,
}
