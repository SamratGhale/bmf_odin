@echo off
if not exist ..\build mkdir ..\build
pushd ..\build
odin build ..\code -o:none -debug -out="./bmf.exe" 
popd
