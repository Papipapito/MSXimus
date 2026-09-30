@echo off
rem construir_exe.bat - MSXsdmaker.exe (un solo fichero, pide administrador al abrirse) con PyInstaller.
rem Lleva dentro packs\sd (base, nextor-2.1.4, nextor-3.0.0-beta1, extras). Resultado: dist\MSXsdmaker.exe
cd /d "%~dp0"
python -m PyInstaller --noconfirm --clean --onefile --windowed --uac-admin --name MSXsdmaker ^
  --add-data "%~dp0..\..\packs\sd\base;sd\base" --add-data "%~dp0..\..\packs\sd\nextor-2.1.4;sd\nextor-2.1.4" ^
  --add-data "%~dp0..\..\packs\sd\nextor-3.0.0-beta1;sd\nextor-3.0.0-beta1" --add-data "%~dp0..\..\packs\sd\extras;sd\extras" ^
  --workpath build --specpath build MSXsdmaker.py
