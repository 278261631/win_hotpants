@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "REPO_ROOT=D:\github\win_hotpants"
set "BUILD_DIR=%REPO_ROOT%\build\Release"
set "CFITSIO_BIN=%REPO_ROOT%\cfitsio\bin"
set "INPUT_A=%REPO_ROOT%\test_demo_a.fits"
set "INPUT_B=%REPO_ROOT%\test_demo_b.fits"
set "OUTPUT_DIFF=%REPO_ROOT%\test_demo_diff.fits"
set "HOTPANTS_EXE=%BUILD_DIR%\hotpants.exe"
set "HOTPANTS_ARGS=-tu 1e9 -tuk 1e9 -iu 1e9 -iuk 1e9 -tl -1e9 -il -1e9 -ft 6 -nrx 1 -nry 1 -nsx 8 -nsy 8 -nss 3 -rss 15 -v 1"

if not exist "%BUILD_DIR%" (
  echo [FAIL] 构建目录不存在: %BUILD_DIR%
  exit /b 1
)
if not exist "%HOTPANTS_EXE%" (
  echo [FAIL] hotpants 可执行文件不存在: %HOTPANTS_EXE%
  exit /b 1
)
if not exist "%INPUT_A%" (
  echo [FAIL] 输入文件不存在: %INPUT_A%
  exit /b 1
)
if not exist "%INPUT_B%" (
  echo [FAIL] 输入文件不存在: %INPUT_B%
  exit /b 1
)

if exist "%CFITSIO_BIN%\*.dll" copy /Y "%CFITSIO_BIN%\*.dll" "%BUILD_DIR%\" >nul
set "VC_REDIST_2019=C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Redist\MSVC\14.29.30133\x64\Microsoft.VC142.CRT"
if exist "%VC_REDIST_2019%\*.dll" copy /Y "%VC_REDIST_2019%\*.dll" "%BUILD_DIR%\" >nul

if not exist "%BUILD_DIR%\zlibd.dll" echo [WARN] 缺少 zlibd.dll ，请拷贝到: %BUILD_DIR%
if not exist "%BUILD_DIR%\libwinpthread-1.dll" echo [WARN] 缺少 libwinpthread-1.dll ，请拷贝到: %BUILD_DIR%

set "PATH=%BUILD_DIR%;%CFITSIO_BIN%;%PATH%"
if exist "%OUTPUT_DIFF%" del /F /Q "%OUTPUT_DIFF%" >nul 2>nul

echo ==> 运行 hotpants 演示样例测试
echo     inim   = %INPUT_A%
echo     tmplim = %INPUT_B%
echo     outim  = %OUTPUT_DIFF%
echo     args   = %HOTPANTS_ARGS%

"%HOTPANTS_EXE%" -inim "%INPUT_A%" -tmplim "%INPUT_B%" -outim "%OUTPUT_DIFF%" %HOTPANTS_ARGS%
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo [FAIL] hotpants 返回非零退出码: %RC%
  exit /b %RC%
)
if not exist "%OUTPUT_DIFF%" (
  echo [FAIL] hotpants 返回成功，但未生成输出: %OUTPUT_DIFF%
  exit /b 2
)

for %%I in ("%OUTPUT_DIFF%") do echo [PASS] 输出文件已生成: %%~fI ^(%%~zI bytes^)

python -c "from astropy.io import fits; import numpy as np; d=fits.getdata(r'%OUTPUT_DIFF%'); y,x=np.unravel_index(np.nanargmax(np.abs(d)), d.shape); print('[INFO] diff min/max/mean/std =', float(np.nanmin(d)), float(np.nanmax(d)), float(np.nanmean(d)), float(np.nanstd(d))); print('[INFO] maxabs@ (x,y)=', int(x), int(y), 'value=', float(d[y,x])); p1,p99=np.percentile(d,[1,99]); print('[INFO] display p1/p99 =', float(p1), float(p99));"
if errorlevel 1 (
  echo [WARN] 统计信息打印失败（可能未安装 astropy），但差分文件已生成。
)

exit /b 0
