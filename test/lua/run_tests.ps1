# run_tests.ps1 — Execute all Lua unit tests with the plain Lua 5.1 interpreter.
#
# Usage:
#   .\test\lua\run_tests.ps1                  # run all tests
#   .\test\lua\run_tests.ps1 -Filter cache    # run files whose name contains "cache"
#
# Requirements: Lua 5.1.x must be on PATH or at $LuaExe below.
# The script exits with code 0 if all suites pass, 1 otherwise.

param(
    [string]$Filter = ""
)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
$LuaExe = if (Get-Command lua -ErrorAction SilentlyContinue) {
    "lua"
} else {
    "c:\program files (x86)\lua\5.1\lua.exe"
}

$TestDir = Join-Path $PSScriptRoot ""   # directory containing this script

# ---------------------------------------------------------------------------
# Discover test files
# ---------------------------------------------------------------------------
$allTests = Get-ChildItem -Path $TestDir -Filter "test_*.lua" | Sort-Object Name

if ($Filter) {
    $allTests = $allTests | Where-Object { $_.Name -like "*$Filter*" }
}

if ($allTests.Count -eq 0) {
    Write-Host "No test files found (filter='$Filter')." -ForegroundColor Yellow
    exit 0
}

# ---------------------------------------------------------------------------
# Run each test file and collect results
# ---------------------------------------------------------------------------
$passed = 0
$failed = 0
$errors = @()

foreach ($testFile in $allTests) {
    Write-Host ""
    Write-Host "--- $($testFile.Name) ---" -ForegroundColor Cyan

    $output = & $LuaExe $testFile.FullName 2>&1
    $exitCode = $LASTEXITCODE

    Write-Host $output

    if ($exitCode -eq 0) {
        $passed++
    } else {
        $failed++
        $errors += $testFile.Name
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "======================================" -ForegroundColor White
if ($failed -eq 0) {
    Write-Host "ALL $passed SUITE(S) PASSED" -ForegroundColor Green
} else {
    Write-Host "$passed suite(s) passed, $failed FAILED:" -ForegroundColor Red
    foreach ($e in $errors) {
        Write-Host "  - $e" -ForegroundColor Red
    }
}
Write-Host "======================================" -ForegroundColor White

exit $(if ($failed -gt 0) { 1 } else { 0 })
