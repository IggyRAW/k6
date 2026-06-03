# k6 負荷テスト結果の見方

ターミナル（k6 のサマリー）と Grafana ダッシュボードの各項目を、初見向けに説明します。

## 全体の流れ

1. **k6** が「仮想ユーザー（VU）」として API にリクエストを送る
2. 結果を **InfluxDB** に保存する
3. **Grafana** がそのデータをグラフで表示する

| 出力先 | 役割 |
|--------|------|
| ターミナル | その 1 回のテストの最終レポート（合否・数値の要約） |
| Grafana | 時間軸での推移・履歴の比較 |

---

## ターミナル出力

### 実行コマンド行

```
Running: docker compose ... k6 run .../smoke.js
```

| 要素 | 意味 |
|------|------|
| **シナリオ名**（例: `smoke`） | 短時間・軽い負荷で「動くか」を確認するテスト |
| **VUs / duration** | 同時ユーザー数と実行時間（スクリプトの `options` で定義） |
| **BASE_URL** | 叩く先の API URL（`projects/<project>/.env` など） |
| **InfluxDBv1** | メトリクスの保存先（Grafana の元データ） |

### execution / scenarios

```
execution: local
script: .../smoke.js
output: InfluxDBv1 (http://influxdb:8086)
```

| 項目 | 意味 |
|------|------|
| **execution: local** | このマシン（Docker 内）で実行した |
| **script** | 使用したテストスクリプトのパス |
| **output** | メトリクスの送信先 |

```
scenarios: 1 scenario, 3 max VUs, 1m0s max duration
* default: 3 looping VUs for 30s (gracefulStop: 30s)
```

| 項目 | 意味 |
|------|------|
| **3 looping VUs for 30s** | 3 人の仮想ユーザーが 30 秒間、シナリオを繰り返す |
| **gracefulStop: 30s** | 終了時に進行中のリクエストを切らず、最大 30 秒待つ |

---

## THRESHOLDS（合格ライン）

テストの **合否** はここが最重要です。

```
http_req_duration  ✓ 'p(95)<1000' p(95)=94.6ms
http_req_failed    ✓ 'rate<0.01' rate=0.00%
```

| しきい値の例 | 意味 | 判定 |
|--------------|------|------|
| `p(95)<1000` | 95% のリクエストが 1000ms（1 秒）未満 | ✓ = 合格、✗ = 失敗 |
| `rate<0.01` | HTTP 失敗率が 1% 未満 | ✓ = 合格、✗ = 失敗 |

**p(95)**（95 パーセンタイル）: 応答時間を速い順に並べ、下から 95% の位置の値。「平均より遅い側の体感」に近く、SLO では p95 をよく使います。

すべて ✓ なら、そのテスト実行は **閾値上は成功** です。

---

## TOTAL RESULTS

### checks（チェック）

スクリプト内の `check()` による断言の結果です。

```
checks_total.......: 84
checks_succeeded...: 100.00% 84 out of 84
✓ status is 200
```

| 項目 | 意味 |
|------|------|
| **checks_total** | チェックを評価した回数 |
| **checks_succeeded** | 成功した割合と件数 |
| **✓ / ✗ + 名前** | 各チェックの成否（例: `status is 200`） |

`http_req_failed` とは別です。check は「ステータス 200 か」など **ビジネス上の成功条件** を見ます。

### HTTP メトリクス

```
http_req_duration: avg=... min=... med=... max=... p(90)=... p(95)=...
http_req_failed: 0.00% 0 out of 84
http_reqs: 84 2.748151/s
```

| 指標 | 読み方 |
|------|--------|
| **http_reqs** | 送った HTTP リクエストの総数 |
| **…/s**（http_reqs 横） | スループット（秒あたりリクエスト数） |
| **http_req_failed** | 失敗したリクエストの割合（0% が理想） |
| **avg** | 平均応答時間（外れ値の影響を受けやすい） |
| **min / max** | 最速・最遅の 1 件 |
| **med** | 中央値（半分がこれより速い） |
| **p(90) / p(95)** | 90% / 95% がこの時間以内に完了 |

**見る優先順位（推奨）**

1. **http_req_failed** → 0% か
2. **p(95)** → threshold / SLO と比較
3. **max** → スパイク・タイムアウトの有無
4. **avg** → 参考（典型値は **med** の方が有用なことが多い）

`{ expected_response:true }` は「成功とみなした応答」だけの内訳です。

### EXECUTION

| 項目 | 意味 |
|------|--------|
| **iteration** | 1 VU が `export default function()` を 1 回実行した単位 |
| **iterations** | イテレーションの総回数（リクエスト回数とほぼ一致することが多い） |
| **iteration_duration** | 1 イテレーション全体の時間（HTTP + `sleep` など含む） |
| **vus** | 現在の仮想ユーザー数 |
| **vus_max** | 設定上の最大 VU |

例: `http.get` → `check` → `sleep(1)` なら、**iteration_duration ≈ 応答時間 + 1 秒** になります。

### NETWORK

| 項目 | 意味 |
|------|------|
| **data_received** | 受信したデータ量 |
| **data_sent** | 送信したデータ量 |

レスポンスが大きい API では `data_received` が増えます。主な性能指標ではありませんが、転送量の参考になります。

### 終了行

```
running (0m30.6s), 0/3 VUs, 84 complete ...
default ✓ [======================================] 3 VUs  30s
```

| 要素 | 意味 |
|------|------|
| **84 complete** | 完了したイテレーション数 |
| **0 interrupted** | 中断なし |
| **プログレスバー ✓** | シナリオが正常終了 |

---

## Grafana ダッシュボード

パス: **Home > Dashboards > k6 > k6 Load Testing Results**

右上の **時間範囲**（例: Last 1 hour）と **Refresh**（例: 5s）で表示期間と更新間隔を変えられます。

### 上段（概要）

| パネル | 何を見るか |
|--------|------------|
| **Virtual Users (VUs)** | 同時にかけている負荷の強さ |
| **Requests per Second** | スループット（秒あたりリクエスト数） |
| **Errors Per Second** | エラー発生（No data はエラーがほぼ無い状態） |
| **Checks Per Second** | check の実行・成否の推移 |

### http_req_duration（レイテンシ）

| 表示 | 意味 |
|------|------|
| 大きな数字（mean, max, med, min, p90, p95） | 選択時間範囲内の統計（ターミナルサマリーと同種） |
| 時系列グラフ | 応答時間がいつ悪化したか |
| ヒートマップ（ある場合） | 時間帯ごとの遅延の分布 |

**推奨**: 要約は **p95**、推移はグラフで確認。

### http_req_blocked

リクエストが **送信される前** に待った時間（接続プール待ち、DNS、TLS など）。

通常は小さい値です。急増時は接続数不足などクライアント側の詰まりを疑います。

---

## ターミナルと Grafana の対応

| ターミナル | Grafana |
|------------|---------|
| `vus` | Virtual Users |
| `http_reqs` の `/s` | Requests per Second |
| `http_req_failed` | Errors Per Second |
| `checks_*` | Checks Per Second |
| `http_req_duration`（avg, p95 等） | http_req_duration パネル |
| （個別メトリクス） | http_req_blocked パネル |

ターミナルの req/s と Grafana の表示が数値だけずれることがあります（集計ウィンドウ・バケットの違い）。意味はどちらも「単位時間あたりの処理量」です。

---

## 結果の読み方チェックリスト

| 観点 | 良い状態の目安 |
|------|----------------|
| 合否 | THRESHOLDS がすべて ✓ |
| 安定性 | `http_req_failed` が 0% に近い、checks 100% |
| 速度 | p95 が SLO / threshold 以内 |
| 要注意 | **max** が avg・p95 より極端に大きい → スパイク調査の余地 |

---

## 用語集

| 用語 | 意味 |
|------|------|
| **VU（Virtual User）** | 仮想ユーザー。同時アクセス者のイメージ |
| **スモークテスト** | 短く軽く「壊れていないか」を確認するテスト |
| **ロードテスト** | 段階的に負荷を上げて限界・劣化を見るテスト |
| **threshold** | 合格ライン。超えるとテスト失敗（CI 連携にも使える） |
| **check** | スクリプト内の成功条件（例: HTTP 200） |
| **iteration** | 1 VU がシナリオ関数を 1 周した回数 |
| **p95** | 95% のリクエストがこの時間以内に完了 |
| **スループット** | 単位時間あたりの処理件数（req/s） |
| **SLO** | サービス品質目標（例: p95 < 500ms） |

---

## 関連ファイル

- シナリオ定義: `projects/<project>/scripts/smoke.js`, `load.js`
- 閾値・VU・時間: 各スクリプトの `export const options`
- 実行: `.\scripts\run.ps1 -Project <project> -Scenario smoke`
