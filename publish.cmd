@echo off
echo -
echo ------------------------------
echo publishing scripts package
echo ------------------------------

call yarn publish
popd
pause