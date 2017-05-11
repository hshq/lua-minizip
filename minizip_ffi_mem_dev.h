// XXX 调整了字段名（去掉前缀tm_），与os.date('*t')一致
//      day: mday, month: mon.
struct tm
{
    int sec;        /* Seconds. [0-60] (1 leap second) */
    int min;        /* Minutes. [0-59] */
    int hour;       /* Hours.   [0-23] */
    int day;        /* Day.     [1-31] */
    int month;      /* Month.   [0-11] */
    int year;       /* Year - 1900.  */
    int wday;       /* Day of week. [0-6] */
    int yday;       /* Days in year.[0-365] */
    int isdst;      /* DST.     [-1/0/1]*/

    long int gmtoff;        /* Seconds east of UTC.  */
    __const char *zone;     /* Timezone abbreviation.  */
};

typedef voidpf   (*open_file_func)     (voidpf opaque, const char *filename, int mode);
typedef voidpf   (*opendisk_file_func) (voidpf opaque, voidpf stream, uint32_t number_disk, int mode);
typedef uint32_t (*read_file_func)     (voidpf opaque, voidpf stream, void* buf, uint32_t size);
typedef uint32_t (*write_file_func)    (voidpf opaque, voidpf stream, const void *buf, uint32_t size);
typedef int      (*close_file_func)    (voidpf opaque, voidpf stream);
typedef int      (*error_file_func)    (voidpf opaque, voidpf stream);

typedef long     (*tell_file_func)     (voidpf opaque, voidpf stream);
typedef long     (*seek_file_func)     (voidpf opaque, voidpf stream, uint32_t offset, int origin);

/* here is the "old" 32 bits structure structure */
typedef struct zlib_filefunc_def_s
{
    open_file_func      zopen_file;
    opendisk_file_func  zopendisk_file;
    read_file_func      zread_file;
    write_file_func     zwrite_file;
    tell_file_func      ztell_file;
    seek_file_func      zseek_file;
    close_file_func     zclose_file;
    error_file_func     zerror_file;
    voidpf              opaque;
} zlib_filefunc_def;

typedef struct ourmemory_s {
    char *base;          /* Base of the region of memory we're using */
    uint32_t size;       /* Size of the region of memory we're using */
    uint32_t limit;      /* Furthest we've written */
    uint32_t cur_offset; /* Current offset in the area */
    int grow;            /* Growable memory buffer */
} ourmemory_t;

typedef struct
{
    uint32_t    dos_date;
    uint16_t    internal_fa;        /* internal file attributes        2 bytes */
    uint32_t    external_fa;        /* external file attributes        4 bytes */
} zip_fileinfo;

typedef struct unz_file_info_s
{
    uint16_t version;               /* version made by                 2 bytes */
    uint16_t version_needed;        /* version needed to extract       2 bytes */
    uint16_t flag;                  /* general purpose bit flag        2 bytes */
    uint16_t compression_method;    /* compression method              2 bytes */
    uint32_t dos_date;              /* last mod file date in Dos fmt   4 bytes */
    uint32_t crc;                   /* crc-32                          4 bytes */
    uint32_t compressed_size;       /* compressed size                 4 bytes */
    uint32_t uncompressed_size;     /* uncompressed size               4 bytes */
    uint16_t size_filename;         /* filename length                 2 bytes */
    uint16_t size_file_extra;       /* extra field length              2 bytes */
    uint16_t size_file_comment;     /* file comment length             2 bytes */

    uint16_t disk_num_start;        /* disk number start               2 bytes */
    uint16_t internal_fa;           /* internal file attributes        2 bytes */
    uint32_t external_fa;           /* external file attributes        4 bytes */

    uint64_t disk_offset;
} unz_file_info;

/* unz_global_info structure contain global data about the ZIPfile
   These data comes from the end of central dir */
typedef struct unz_global_info_s
{
    uint32_t number_entry;          /* total number of entries in the central dir on this disk */
    uint32_t number_disk_with_CD;   /* number the the disk with central dir, used for spanning ZIP*/
    uint16_t size_comment;          /* size of the global comment of the zipfile */
} unz_global_info;

typedef struct unz_file_pos_s
{
    uint32_t pos_in_zip_directory;  /* offset in zip file directory */
    uint32_t num_of_file;           /* # of file */
} unz_file_pos;

typedef int (*unzFileNameComparer)(unzFile file, const char *filename1, const char *filename2);

void fill_memory_filefunc(zlib_filefunc_def* pzlib_filefunc_def, ourmemory_t *ourmem);

extern zipFile  zipOpen2(const char *path, int append, const char **globalcomment,
    zlib_filefunc_def *pzlib_filefunc_def);
extern int      zipClose(zipFile file, const char *global_comment);
extern int      zipOpenNewFileInZip(zipFile file, const char *filename, const zip_fileinfo *zipfi,
    const void *extrafield_local, uint16_t size_extrafield_local, const void *extrafield_global,
    uint16_t size_extrafield_global, const char *comment, uint16_t method, int level);
extern int      zipCloseFileInZip(zipFile file);
extern int      zipWriteInFileInZip(zipFile file, const void *buf, uint32_t len);

extern unzFile  unzOpen2(const char *path, zlib_filefunc_def *pzlib_filefunc_def);
extern int      unzClose(unzFile file);
extern int      unzOpenCurrentFile(unzFile file);
extern int      unzCloseCurrentFile(unzFile file);
extern int      unzGoToFirstFile(unzFile file);
extern int      unzGoToNextFile(unzFile file);
extern int      unzLocateFile(unzFile file, const char *filename, unzFileNameComparer filename_compare_func);
extern int      unzGetCurrentFileInfo(unzFile file, unz_file_info *pfile_info, char *filename,
    uint16_t filename_size, void *extrafield, uint16_t extrafield_size, char *comment, uint16_t comment_size);
extern int      unzGetGlobalInfo(unzFile file, unz_global_info *pglobal_info);
extern int      unzGetGlobalComment(unzFile file, char *comment, uint16_t comment_size);
extern int32_t  unzGetOffset(unzFile file);
extern int      unzGetFilePos(unzFile file, unz_file_pos *file_pos);
extern int      unzReadCurrentFile(unzFile file, voidp buf, uint32_t len);
extern int32_t  unzTell(unzFile file);

struct tm *localtime_r(const time_t *clock, struct tm *result);
time_t mktime(struct tm *timeptr);

/* Convert struct tm to dos date/time format */
uint32_t tm_to_dosdate(const struct tm *ptm);

/* Convert dos date/time format to struct tm */
int dosdate_to_tm(uint64_t dos_date, struct tm *ptm);
