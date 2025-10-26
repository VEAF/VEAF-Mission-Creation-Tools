@echo off
echo -
echo ------------------------------
echo publishing scripts package
echo ------------------------------

echo create tag
git tag releases/v6.0.0
git push origin :refs/tags/releases/v6.0.0

echo move v6-latest tag
git tag -d releases/v6-latest
git tag releases/v6-latest
git push origin :refs/tags/releases/v6-latest
git push origin releases/v6-latest 


pause