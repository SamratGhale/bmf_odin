@echo off
if not exist ..\build mkdir ..\build
pushd ..\build
odin build ..\code -subsystem:windows -debug -out="./bmf.exe"
popd