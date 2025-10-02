@echo off
rem 日付を取得してコミットメッセージに使う
set DATE=%date:~0,4%%date:~5,2%%date:~8,2%

rem Git コマンドを実行
git add .
git commit -m "%DATE%"
git push

rem 結果を確認するために一時停止
pause
