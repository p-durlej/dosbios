ECHO OFF
CLS

FORMAT C: /S
REM PAUSE
REM CLS

COPY AUTOEXEC.FXD C:\AUTOEXEC.BAT > NUL
MD C:\DOS
REM COPY *.COM C:\DOS > NUL
REM COPY *.EXE C:\DOS > NUL

COPY chkdsk.com		C:\DOS > NUL
COPY command.com	C:\DOS > NUL
COPY cref.exe		C:\DOS > NUL
COPY debug.com		C:\DOS > NUL
COPY diskcopy.com	C:\DOS > NUL
COPY edlin.com		C:\DOS > NUL
COPY exe2bin.exe	C:\DOS > NUL
COPY fc.exe		C:\DOS > NUL
COPY find.exe		C:\DOS > NUL
COPY format.com		C:\DOS > NUL
COPY fdisk.com		C:\DOS > NUL
COPY link.exe		C:\DOS > NUL
COPY masm.exe		C:\DOS > NUL
COPY mem.com		C:\DOS > NUL
COPY more.com		C:\DOS > NUL
COPY print.com		C:\DOS > NUL
COPY reboot.com		C:\DOS > NUL
COPY recover.com	C:\DOS > NUL
COPY sort.exe		C:\DOS > NUL

ECHO Installation complete
