@echo off
REM ============================================================================
REM VIVA BIODATA TESTS — Quick test runner for Windows
REM ============================================================================

echo.
echo ========================================
echo VIVA BIODATA 2.0 — TEST SUITE
echo ========================================
echo.

REM Check if we're in the backend directory
if not exist "app\services\biodata_service.py" (
    echo ERROR: Please run this script from the backend directory
    echo Usage: cd backend && run_biodata_tests.bat
    pause
    exit /b 1
)

REM Check if pytest is installed
python -m pytest --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: pytest is not installed
    echo Installing pytest...
    pip install pytest pytest-asyncio pytest-cov
)

echo Running biodata normalization tests...
echo.

REM Run biodata-specific tests
python -m pytest tests/unit/test_biodata_normalization.py -v --tb=short

if errorlevel 1 (
    echo.
    echo ========================================
    echo TESTS FAILED
    echo ========================================
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo ALL TESTS PASSED ✓
echo ========================================
echo.

REM Optionally run all tests
set /p run_all="Run ALL tests (including security)? (y/n): "
if /i "%run_all%"=="y" (
    echo.
    echo Running complete test suite...
    echo.
    python -m pytest tests/ -v --tb=short
)

echo.
echo ========================================
echo TEST EXECUTION COMPLETE
echo ========================================
echo.
pause
