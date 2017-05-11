// XXX 共享的 C声明 和 Lua代码不多，可能拆成3部分（共享、压缩、解压）更好，
//  且对应于 minizip 的功能结构。
enum {
    Z_NO_COMPRESSION      = 0,
    Z_BEST_SPEED          = 1,
    Z_BEST_COMPRESSION    = 9,
    Z_DEFAULT_COMPRESSION = (-1),
};

enum {
    Z_STORE    = 0,  // zip.h: ZIP_CM_STORE
    Z_DEFLATED = 8,  // zip.h: ZIP_CM_DEFLATE // zlib.h
    Z_BZIP2ED  = 12, // zip.h: ZIP_CM_BZIP2   // zip.h
    // zip.h: 9 ZIP_CM_DEFLATE64 14 ZIP_CM_LZMA 19 ZIP_CM_LZ77
};

enum {
    APPEND_STATUS_CREATE      = (0),
    APPEND_STATUS_CREATEAFTER = (1),
    APPEND_STATUS_ADDINZIP    = (2),
};

enum {
    // zlib
    Z_OK                    = 0,    // ZIP_OK ZIP_EOF UNZ_OK UNZ_EOF
    Z_STREAM_END            = 1,
    Z_NEED_DICT             = 2,
    Z_ERRNO                 = (-1), // ZIP_ERRNO UNZ_ERRNO
    Z_STREAM_ERROR          = (-2),
    Z_DATA_ERROR            = (-3),
    Z_MEM_ERROR             = (-4),
    Z_BUF_ERROR             = (-5),
    Z_VERSION_ERROR         = (-6),

    // minizip
    //ZIP_ERRNO               = (Z_ERRNO),
    //UNZ_ERRNO               = (Z_ERRNO),
    Z_END_OF_LIST_OF_FILE   = (-100),   // UNZ_END_OF_LIST_OF_FILE
    Z_PARAMERROR            = (-102),   // ZIP_PARAMERROR UNZ_PARAMERROR
    Z_BADZIPFILE            = (-103),   // ZIP_BADZIPFILE UNZ_BADZIPFILE
    Z_INTERNALERROR         = (-104),   // ZIP_INTERNALERROR UNZ_INTERNALERROR
    Z_CRCERROR              = (-105),   // UNZ_CRCERROR
    Z_BADPASSWORD           = (-106),   // UNZ_BADPASSWORD
};

typedef void *voidp;
typedef voidp voidpf;

typedef voidp zipFile;
typedef voidp unzFile;

typedef long int time_t; // <time.h>

char *strerror(int errnum);
void free(void *ptr);

char *ctime(const time_t *clock); // 符合dos_date格式
