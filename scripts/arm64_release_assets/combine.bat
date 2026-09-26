@echo off
echo ========================================================
echo  Merging Caelaris Linux ARM64 Laptop & PC ISO parts...
echo ========================================================
copy /b "caelaris-arm64-pc.iso.part-*" "caelaris-arm64-pc.iso"
echo.
echo Verifying SHA256 checksum...
certutil -hashfile "caelaris-arm64-pc.iso" SHA256
echo.
echo Done! You can now use caelaris-arm64-pc.iso.
pause
