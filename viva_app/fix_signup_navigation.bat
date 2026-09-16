@echo off
REM ============================================================================
REM FIX SIGNUP NAVIGATION — Clean rebuild to fix routing issues
REM ============================================================================

echo.
echo ========================================
echo FIXING SIGNUP NAVIGATION ISSUE
echo ========================================
echo.

REM Check if we're in the viva_app directory
if not exist "pubspec.yaml" (
    echo ERROR: Please run this script from the viva_app directory
    echo Usage: cd viva_app && fix_signup_navigation.bat
    pause
    exit /b 1
)

echo Step 1: Cleaning build cache...
call flutter clean
if errorlevel 1 (
    echo ERROR: flutter clean failed
    pause
    exit /b 1
)

echo.
echo Step 2: Getting dependencies...
call flutter pub get
if errorlevel 1 (
    echo ERROR: flutter pub get failed
    pause
    exit /b 1
)

echo.
echo Step 3: Build cache cleaned successfully!
echo.
echo ========================================
echo NEXT STEPS
echo ========================================
echo.
echo 1. Run the app: flutter run
echo 2. Test "Create account" button on login screen
echo 3. If issue persists, check Flutter DevTools for errors
echo.
echo Possible causes if still not working:
echo - Emulator/device needs restart
echo - IDE needs restart
echo - Platform-specific issue (try different device)
echo.

set /p run_now="Run the app now? (y/n): "
if /i "%run_now%"=="y" (
    echo.
    echo Starting Flutter app...
    echo.
    call flutter run
)

echo.
echo ========================================
echo CLEANUP COMPLETE
echo ========================================
echo.
pause
