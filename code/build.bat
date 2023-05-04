if not exist ..\build mkdir ..\build
pushd ..\build
odin build ..\code -debug -show-timings -out="./bmf.exe" 
popd
