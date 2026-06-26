---
title: "【Python×Excel】窓付き封筒の宛名印刷を自動化するコード全文を公開―経理×python実装例"
description: "返金業務で利用していた窓付き封筒の宛名印刷をPythonで自動化した際のコード全文を公開します。pandasによるExcel読込、住所分割、要確認フラグ、エラーログ出力まで含めた実装例を紹介します。"
tags:
  - Python
  - Excel
  - pandas
  - openpyxl
  - 業務改善
  - 経理
  - 自動化
category: "業務改善"
date: 2026-06-23
---

## はじめに

前回の記事では、

> 実際にどのような考え方で住所分割ロジックを作ったのか

について紹介しました。

- [【Python×Excel】窓付き封筒の宛名印刷を自動化してみた―住所データを2行に分割する実装方法（概要）](https://graphul.jp/blog/posts/page64-pythonaddress/)

今回は、その続きとして、

> 実際に作成したPythonコード全文

を紹介したいと思います。

今回のプログラムは、

- Excelファイル読込
- 住所の正規化
- 住所1・住所2への分割
- 要確認フラグ
- エラーログ出力
- Excelファイル書き出し

までを一つのプログラムで実行できるようにしています。

---

## 実行環境

今回の検証環境は以下の通りです。

- Windows 11
- Python 3.10
- pandas
- openpyxl

ライブラリのインストールは以下のコマンドで行いました。

```bash
pip install pandas openpyxl
```

---

## フォルダ構成

今回のサンプルでは、以下のような構成を採用しています。

```text
refund_project

├─ main.py
├─ input
│   └─ 返金対応リスト.xlsx
├─ output
│   └─ 宛名印刷データ.xlsx
└─ log
    └─ error_log.txt
```

返金リストを input フォルダに配置し、

```bash
python main.py
```

を実行すると、

outputフォルダに宛名印刷用Excelが生成されます。

---

## コード全文

以下が実際に作成したコードです。

```python
import pandas as pd
import re
import unicodedata

# ==========================
# ファイル設定
# ==========================
input_file = r"input\返金対応リスト2025-6-17.xlsx"
output_file = r"output\宛名印刷データ.xlsx"
log_file = r"log\error_log.txt"

error_logs = []

# ==========================
# 建物キーワード
# ==========================
BUILDING_WORDS = [
    "マンション",
    "ハイツ",
    "ビル",
    "タワー",
    "寮",
    "コーポ",
    "レジデンス"
]


# ==========================
# 住所正規化
# ==========================
def normalize_address(address):

    address = str(address)

    # 全角スペース→半角スペース
    address = address.replace("　", " ")

    # 余分なスペース削除
    address = re.sub(r"\s+", " ", address)

    return address.strip()

# ==========================
# 文字数確認
# ==========================

def get_display_width(text):

    width = 0

    for char in str(text):

        # 全角文字
        if unicodedata.east_asian_width(char) in ['F', 'W', 'A']:
            width += 2

        # 半角文字
        else:
            width += 1

    return width


# ==========================
# 要確認判定
# ==========================
def need_check(address2):

    if address2 == "":
        return False

    if len(address2) <= 2:
        return True

    if address2.startswith("丁目"):
        return True

    if address2.startswith("条"):
        return True

    return False

# ==========================
# 住所分割
# ==========================
def split_address(address):

    address = normalize_address(address)

    # -----------------------------------
    # パターン0：番地の後に建物名が続く
    # -----------------------------------

    m = re.search(
        r'(\d+(?:-\d+)+号?)(.+)$',
        address
    )

    if m:

        after_text = m.group(2).strip()

        # 後ろが日本語や英字で始まる場合のみ建物とみなす
        if re.match(r'[ぁ-んァ-ヶ一-龠ｦ-ﾟA-Za-z]', after_text):

            address1 = address[:m.end(1)]
            address2 = after_text

            check = ""

            if need_check(address2):
                check = "要確認"

            # 住所1の表示幅チェック
            if get_display_width(address1) > 32:
                check = "要確認"

            return address1, address2, check

    # -----------------------------------
    # パターン1：スペース区切り
    # -----------------------------------
    if " " in address:

        parts = address.split(" ", 1)

        if len(parts[1]) >= 4:

            address1 = parts[0]
            address2 = parts[1]

            check = ""

            if need_check(address2):
                check = "要確認"

            # 住所1の表示幅チェック
            if get_display_width(address1) > 32:
                check = "要確認"

            return address1, address2, check

    # -----------------------------------
    # パターン2：建物キーワード検出
    # -----------------------------------
    for word in BUILDING_WORDS:

        pos = address.find(word)

        if pos != -1:

            prefix = address[:pos]

            m = re.search(
                r'[0-9０-９\-－番地号丁目条西東南北]+$',
                prefix
            )

            if m:

                cut_pos = m.end()

                address1 = address[:cut_pos]
                address2 = address[cut_pos:]

                check = ""

                if need_check(address2):
                    check = "要確認"

                if get_display_width(address1) > 32:
                    check = "要確認"

                return address1.strip(), address2.strip(), check

    # -----------------------------------
    # パターン3：建物なし
    # -----------------------------------

    address1 = address
    address2 = ""

    check = ""

    if get_display_width(address1) > 32:
        check = "要確認"

    return address1, address2, check


# ==========================
# Excel読込
# ==========================
df = pd.read_excel(input_file)

output_rows = []

# ==========================
# データ処理
# ==========================
for _, row in df.iterrows():

    try:

        address1, address2, check = split_address(row["住所"])

        output_rows.append({

            "顧客氏名": row["顧客氏名"],

            "郵便番号": str(row["郵便番号"]).zfill(7),

            "住所1": address1,

            "住所2": address2,

            "要確認": check

        })

    except Exception as e:

        error_logs.append(
            f"{row['返金ID']} : {str(e)}"
        )


# ==========================
# 出力Excel作成
# ==========================
output_df = pd.DataFrame(output_rows)

output_df.to_excel(
    output_file,
    index=False
)


# ==========================
# エラーログ出力
# ==========================
with open(log_file, "w", encoding="utf-8") as f:

    if len(error_logs) == 0:

        f.write("エラーなし")

    else:

        for log in error_logs:

            f.write(log + "\n")


print("処理完了")
```

---

## このプログラムで行っている処理

### ① Excelファイルの読込

pandasを利用して返金リストを読み込みます。

```python
df = pd.read_excel(input_file)
```

---

### ② 住所の正規化

全角スペースや不要な空白を整理します。

```python
address = address.replace("　", " ")
```

---

### ③ 建物名の判定

以下のようなキーワードを利用して建物名を検出します。

```python
BUILDING_WORDS = [
    "マンション",
    "ハイツ",
    "ビル",
    "タワー",
    "寮"
]
```

---

### ④ 番地＋建物名を優先的に分割

例えば、

```text
東京都千代田区千代田5-2-3スカイビル402号室
```

を、

```text
東京都千代田区千代田5-2-3
スカイビル402号室
```

のように分割します。

---

### ⑤ 要確認フラグ

以下のようなケースでは、

```text
要確認
```

を付与します。

- 建物名が短すぎる
- 住所1が長すぎる
- 判定が難しい住所

---

### ⑥ エラーログ出力

処理できなかったデータは、

```text
error_log.txt
```

へ出力します。

---

## 完璧ではない

今回のプログラムは、

決して100%正しく動作するわけではありません。

例えば、

```text
佐賀県佐賀市川副町大字犬井道9476-187
```

のような特殊な住所は、

機械だけで正しく判定することが難しい場合があります。

そのため、

> 完全自動化を目指すのではなく、要確認フラグを付けて人間が確認する

という運用を前提にしています。

---

## 実際に作って感じたこと

最初は、

> 「住所を2行に分けるだけ」

と思っていました。

しかし実際には、

- 表記ゆれ
- 建物名の種類
- 特殊な住所
- 長い住所

など、想像以上に例外が多く存在しました。

そして最終的に感じたのは、

> 業務改善で重要なのは、100%自動化することではない

ということでした。

むしろ、

> 「どこを人間に残すか」

を設計することの方が重要だったように思います。

---

## おわりに

今回紹介したコードは、

あくまで一つの実装例です。

住所データの形式や業務内容によって、

最適なロジックは変わります。

しかし、

- pandas
- openpyxl
- 要確認フラグ
- エラーログ

という考え方は、住所処理以外の業務改善にも応用できると思います。

今回の記事が、

Pythonによる業務改善を検討している方の参考になれば幸いです。