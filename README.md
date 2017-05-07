# lua-minizip
minizip 的 LuaJIT FFI 绑定，只实现了 mem 模块。Linux | MACOSX, minizip v1.1 + LuaJIT v2。

### 构建
1. 下载 [minizip v1.1](https://github.com/nmoinvaz/minizip/releases/tag/1.1) 源码包，解压。
2. 用 [minizip-1.1_CMakeLists.txt](minizip-1.1_CMakeLists.txt) 覆盖其中的 CMakeLists.txt 。会构建测试用的可执行文件、共享库、链接 bzip2 库、链接 compression 库（MACOSX）。
3. 进入源码目录，构建 minizip 共享库：`cmake .; make`。
4. 将 libminizip.dylib 拷贝到 Lua 库路径中，改为名 libminizip.1.1.dylib （dylib: MACOSX, so: Linux）。
5. 测试 zip ，生成 zip.zip 文件：`luajit test_zip.lua`。
6. 测试 unzip ，显示 zip.zip 的信息、内容：`luajit test_unzip.lua`。


