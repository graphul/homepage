@echo off
rem 今日の日付を取得（YYYYMMDD形式）
set TODAY=%date:~0,4%%date:~5,2%%date:~8,2%

rem push回数管理ファイル
set COUNT_FILE=.pushcount

rem デフォルト値
set NUM=0
set FILE_DATE=

rem push回数ファイルが存在する場合
if exist %COUNT_FILE% (
    rem ファイルの1行目に日付、2行目に番号を保存している想定
    set /p FILE_DATE=<%COUNT_FILE%
    set /p NUM=<%COUNT_FILE%
    
    rem ファイルを読み込むときは2行目を NUM に代入する工夫
    for /f "skip=1 delims=" %%a in (%COUNT_FILE%) do set NUM=%%a
)

rem 日付が変わったらリセット
if not "%FILE_DATE%"=="%TODAY%" (
    set NUM=0
)

rem 次の push 番号
set /a NUM+=1

rem コミットメッセージの設定
if %NUM%==1 (
    set COMMIT_MSG=%TODAY%
) else (
    set COMMIT_MSG=%TODAY%_%NUM%
)

rem Git コマンド実行
git add .
git commit -m "%COMMIT_MSG%"
git push

rem push回数をファイルに保存（1行目: 日付, 2行目: 回数）
(
    echo %TODAY%
    echo %NUM%
) > %COUNT_FILE%

rem 結果確認のため一時停止
pause
