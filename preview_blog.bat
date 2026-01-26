@chcp 65001
@echo off

cd blog_src

rem Jekyllサーバーを新しいウィンドウでバックグラウンド起動
start "" cmd /c "bundle exec jekyll serve"

rem 少し待ってからブラウザを開く
timeout /t 25

rem ブラウザで開く
start "" http://127.0.0.1:4000/blog/
