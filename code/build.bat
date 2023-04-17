@echo off
if not exist ..\build mkdir ..\build
pushd ..\build
odin build ..\code -o:size -subsystem:windows -debug -out="./bmf.exe"
popd