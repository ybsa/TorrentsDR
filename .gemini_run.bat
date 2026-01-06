@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
if %errorlevel% neq 0 (
    echo "Failed to call vcvars64.bat. Is Visual Studio 2022 Community installed in default location?"
    exit /b %errorlevel%
)
set "ANDROID_HOME=C:\Users\WINDXE~1\AppData\Local\Android\Sdk"
set "ANDROID_NDK_HOME=C:\Users\WINDXE~1\AppData\Local\Android\Sdk\ndk\28.2.13676358"
echo Environment set. Running flutter run...
flutter run -d emulator-5554
