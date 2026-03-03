param(
    [string]$BuildDir = "D:\github\win_hotpants\build\Release",
    [string]$CfitsioBin = "D:\github\win_hotpants\cfitsio\bin",
    [string[]]$ExtraDllDirs = @()
)

$ErrorActionPreference = "Stop"

function Format-ExitCodeHex {
    param([int]$Code)
    $u32 = [BitConverter]::ToUInt32([BitConverter]::GetBytes($Code), 0)
    return ("0x{0:X8}" -f $u32)
}

function Invoke-SmokeCase {
    param(
        [string]$Name,
        [string]$ExePath,
        [string[]]$Args = @(),
        [string[]]$ExpectedPatterns = @("Usage", "Required options", "Error", "cannot")
    )

    Write-Host "==> $Name"
    if (!(Test-Path $ExePath)) {
        Write-Host "  [FAIL] 可执行文件不存在: $ExePath" -ForegroundColor Red
        return $false
    }

    $output = & $ExePath @Args 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $matched = $false
    foreach ($p in $ExpectedPatterns) {
        if ($output -match [regex]::Escape($p)) {
            $matched = $true
            break
        }
    }

    if ($matched) {
        Write-Host "  [PASS] exit=$exitCode ($(Format-ExitCodeHex $exitCode))"
        return $true
    }

    if ($exitCode -eq -1073741515) {
        Write-Host "  [FAIL] 程序未能启动，疑似缺少 DLL 依赖 (exit=$exitCode / $(Format-ExitCodeHex $exitCode))" -ForegroundColor Red
    } else {
        Write-Host "  [FAIL] 未匹配预期输出关键字, exit=$exitCode ($(Format-ExitCodeHex $exitCode))" -ForegroundColor Red
    }
    $trimmed = $output.Trim()
    if ($trimmed.Length -gt 0) {
        Write-Host "  输出预览:"
        Write-Host ($trimmed.Substring(0, [Math]::Min(400, $trimmed.Length)))
    } else {
        Write-Host "  输出为空"
    }
    return $false
}

function Resolve-VcRuntimeDir {
    $roots = @(
        "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC",
        "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC",
        "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Redist\MSVC",
        "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Redist\MSVC"
    )

    foreach ($root in $roots) {
        if (!(Test-Path $root)) { continue }
        $candidate = Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object {
                Join-Path $_.FullName "x64\Microsoft.VC*.CRT"
            } |
            ForEach-Object {
                Get-ChildItem $_ -Directory -ErrorAction SilentlyContinue
            } |
            Select-Object -First 1
        if ($candidate) {
            return $candidate.FullName
        }
    }
    return $null
}

function Copy-DllsToBuildDir {
    param(
        [string]$Destination,
        [string[]]$SourceDirs
    )

    $copied = 0
    foreach ($dir in $SourceDirs) {
        if (!(Test-Path $dir)) { continue }
        Get-ChildItem $dir -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item -Force $_.FullName (Join-Path $Destination $_.Name)
            $copied++
        }
    }
    return $copied
}

function Check-RequiredDlls {
    param(
        [string]$TargetDir
    )

    $required = @(
        "zlibd.dll",
        "libwinpthread-1.dll"
    )

    $missing = @()
    foreach ($dll in $required) {
        if (!(Test-Path (Join-Path $TargetDir $dll))) {
            $missing += $dll
        }
    }

    if ($missing.Count -gt 0) {
        Write-Host "[WARN] 检测到关键 DLL 缺失，请先拷贝后再测试：" -ForegroundColor Yellow
        $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
        Write-Host "[WARN] 你可以将这些 DLL 放到: $TargetDir" -ForegroundColor Yellow
    } else {
        Write-Host "[INFO] 关键 DLL 已就绪: zlibd.dll, libwinpthread-1.dll"
    }
}

$hotpants = Join-Path $BuildDir "hotpants.exe"
$extractkern = Join-Path $BuildDir "extractkern.exe"
$maskim = Join-Path $BuildDir "maskim.exe"

if (!(Test-Path $BuildDir)) {
    Write-Host "[FAIL] 构建目录不存在: $BuildDir" -ForegroundColor Red
    exit 1
}

# 1) 汇总 DLL 搜索路径：cfitsio + VC 运行库 + 用户追加目录
$dllSourceDirs = @()
if (Test-Path $CfitsioBin) {
    $dllSourceDirs += $CfitsioBin
}
$vcRuntimeDir = Resolve-VcRuntimeDir
if ($vcRuntimeDir) {
    $dllSourceDirs += $vcRuntimeDir
}
if ($ExtraDllDirs) {
    $dllSourceDirs += $ExtraDllDirs
}
$dllSourceDirs = $dllSourceDirs | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

if ($dllSourceDirs.Count -eq 0) {
    Write-Host "[WARN] 未找到可用 DLL 源目录，程序可能无法启动。" -ForegroundColor Yellow
} else {
    Write-Host "[INFO] DLL 源目录:"
    $dllSourceDirs | ForEach-Object { Write-Host "  - $_" }
    $copiedCount = Copy-DllsToBuildDir -Destination $BuildDir -SourceDirs $dllSourceDirs
    Write-Host "[INFO] 已拷贝 $copiedCount 个 DLL 到 $BuildDir"
}

# 2) 将 DLL 源目录加入 PATH，方便子进程加载依赖
if ($dllSourceDirs.Count -gt 0) {
    $env:PATH = (($dllSourceDirs -join ";") + ";" + $env:PATH)
}

# 3) 明确提示用户额外依赖
Check-RequiredDlls -TargetDir $BuildDir

$results = @()

# 1) 无参数启动，通常会输出用法或错误提示
$results += Invoke-SmokeCase -Name "hotpants 无参数" -ExePath $hotpants
$results += Invoke-SmokeCase -Name "extractkern 无参数" -ExePath $extractkern
$results += Invoke-SmokeCase -Name "maskim 无参数" -ExePath $maskim

# 2) hotpants 参数解析路径（不存在输入文件时应有 cfitsio 错误信息）
$results += Invoke-SmokeCase `
    -Name "hotpants 参数解析 + 缺失文件" `
    -ExePath $hotpants `
    -Args @("-inim", "no_image.fits", "-tmplim", "no_template.fits", "-outim", "no_out.fits") `
    -ExpectedPatterns @("Usage", "error", "Error", "cannot", "could not", "failed")

$passed = ($results | Where-Object { $_ -eq $true }).Count
$total = $results.Count

Write-Host ""
Write-Host "Smoke Test Result: $passed / $total passed"
if ($passed -ne $total) {
    exit 1
}
exit 0
