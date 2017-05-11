typedef unsigned int   uInt;  /* 16 bits or more */
typedef unsigned long  uLong; /* 32 bits or more */
typedef long z_off_t;

// XXX 调整了字段名（去掉前缀tm_），与os.date('*t')一致，便于直接初始化
/* tm_zip contain date/time info */
typedef struct tm_zip_s
{
    uInt sec;                /* seconds after the minute - [0,59] */
    uInt min;                /* minutes after the hour - [0,59] */
    uInt hour;               /* hours since midnight - [0,23] */
    uInt day;                /* day of the month - [1,31] */
    uInt month;              /* months since January - [0,11] */
    uInt year;               /* years - [1980..2044] */
} tm_zip;

typedef struct tm_zip_s tm_unz;

typedef voidpf   (*open_file_func)      (voidpf opaque, const char* filename, int mode);
typedef voidpf   (*opendisk_file_func)  (voidpf opaque, voidpf stream, unsigned long number_disk, int mode);
typedef uLong    (*read_file_func)      (voidpf opaque, voidpf stream, void* buf, uLong size);
typedef uLong    (*write_file_func)     (voidpf opaque, voidpf stream, const void* buf, uLong size);
typedef int      (*close_file_func)     (voidpf opaque, voidpf stream);
typedef int      (*testerror_file_func) (voidpf opaque, voidpf stream);

typedef long     (*tell_file_func)      (voidpf opaque, voidpf stream);
typedef long     (*seek_file_func)      (voidpf opaque, voidpf stream, uLong offset, int origin);

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
    testerror_file_func zerror_file;
    voidpf              opaque;
} zlib_filefunc_def;

typedef struct ourmemory_s {
    char *base;       /* Base of the region of memory we're using */
    uLong size;       /* Size of the region of memory we're using */
    uLong limit;      /* Furthest we've written */
    uLong cur_offset; /* Current offset in the area */
    int grow;         /* Growable memory buffer */
} ourmemory_t;

typedef struct
{
    tm_zip      tmz_date;       /* date in understandable format           */
    uLong       dosDate;        /* if dos_date == 0, tmu_date is used      */
    uLong       internal_fa;    /* internal file attributes        2 bytes */
    uLong       external_fa;    /* external file attributes        4 bytes */
} zip_fileinfo;

typedef struct unz_file_info_s
{
    uLong version;              /* version made by                 2 bytes */
    uLong version_needed;       /* version needed to extract       2 bytes */
    uLong flag;                 /* general purpose bit flag        2 bytes */
    uLong compression_method;   /* compression method              2 bytes */
    uLong dosDate;              /* last mod file date in Dos fmt   4 bytes */
    uLong crc;                  /* crc-32                          4 bytes */
    uLong compressed_size;      /* compressed size                 4 bytes */
    uLong uncompressed_size;    /* uncompressed size               4 bytes */
    uLong size_filename;        /* filename length                 2 bytes */
    uLong size_file_extra;      /* extra field length              2 bytes */
    uLong size_file_comment;    /* file comment length             2 bytes */

    uLong disk_num_start;       /* disk number start               2 bytes */
    uLong internal_fa;          /* internal file attributes        2 bytes */
    uLong external_fa;          /* external file attributes        4 bytes */

    tm_unz tmu_date;
    uLong disk_offset;
} unz_file_info;

/* unz_global_info structure contain global data about the ZIPfile
   These data comes from the end of central dir */
typedef struct unz_global_info_s
{
    uLong number_entry;         /* total number of entries in the central dir on this disk */
    uLong number_disk_with_CD;  /* number the the disk with central dir, used for spanning ZIP*/
    uLong size_comment;         /* size of the global comment of the zipfile */
} unz_global_info;

typedef struct unz_file_pos_s
{
    uLong pos_in_zip_directory;     /* offset in zip file directory */
    uLong num_of_file;              /* # of file */
} unz_file_pos;

typedef int (*unzFileNameComparer)(unzFile file, const char *filename1, const char *filename2);

void fill_memory_filefunc(zlib_filefunc_def* pzlib_filefunc_def, ourmemory_t *ourmem);

extern zipFile  zipOpen2(const char *pathname, int append, const char ** globalcomment,
    zlib_filefunc_def* pzlib_filefunc_def);
extern int      zipClose(zipFile file, const char* global_comment);
extern int      zipOpenNewFileInZip(zipFile file, const char* filename, const zip_fileinfo* zipfi,
    const void* extrafield_local, uInt size_extrafield_local, const void* extrafield_global,
    uInt size_extrafield_global, const char* comment, int method, int level);
extern int      zipCloseFileInZip(zipFile file);
extern int      zipWriteInFileInZip(zipFile file, const void* buf, unsigned len);

extern unzFile  unzOpen2(const char *path, zlib_filefunc_def* pzlib_filefunc_def);
extern int      unzClose(unzFile file);
extern int      unzOpenCurrentFile(unzFile file);
extern int      unzCloseCurrentFile(unzFile file);
extern int      unzGoToFirstFile(unzFile file);
extern int      unzGoToNextFile(unzFile file);
extern int      unzLocateFile(unzFile file, const char *filename, unzFileNameComparer filename_compare_func);
extern int      unzGetCurrentFileInfo(unzFile file, unz_file_info *pfile_info, char *filename,
    uLong filename_size, void *extrafield, uLong extrafield_size, char *comment, uLong comment_size);
extern int      unzGetGlobalInfo(unzFile file, unz_global_info *pglobal_info);
extern int      unzGetGlobalComment(unzFile file, char *comment, uLong comment_size);
extern uLong    unzGetOffset(unzFile file);
extern int      unzGetFilePos(unzFile file, unz_file_pos* file_pos);
extern int      unzReadCurrentFile(unzFile file, voidp buf, unsigned len);
extern z_off_t  unztell(unzFile file);
extern int      unzeof(unzFile file);
