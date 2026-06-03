# k6 高負荷テスト Docker 環境

プロジェクト単位で k6 の負荷テストを実行し、InfluxDB + Grafana でメトリクスを可視化するテンプレートです。

## 構成

| サービス | 役割 | ポート（デフォルト） |
|---------|------|---------------------|
| InfluxDB 1.8 | k6 メトリクス保存 | 8086 |
| Grafana 11 | ダッシュボード | 3000 |
| k6 | テスト実行（都度起動） | - |

## 前提条件

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) または Docker Engine + Docker Compose v2

## クイックスタート

### 1. インフラの起動

```powershell
docker compose up -d influxdb grafana
```

Grafana: http://localhost:3000（匿名 Admin、**ローカル開発専用**）

### 2. サンプルテストの実行

```powershell
.\scripts\run.ps1 -Project example-api -Scenario smoke
```

WSL / Linux:

```bash
chmod +x scripts/run.sh
./scripts/run.sh example-api smoke
```

### 3. Grafana で結果確認

1. http://localhost:3000 を開く
2. フォルダ **k6** → **k6 Load Testing Results** ダッシュボードを開く
3. 右上の時間範囲を「Last 5 minutes」などに変更

ターミナル出力・ダッシュボード各パネルの見方は [docs/k6-results-guide.md](docs/k6-results-guide.md) を参照してください。

## 新規プロジェクトの追加

1. `projects/_template` を `projects/<your-project>` にコピー
2. `.env.example` を `.env` にリネームし `BASE_URL` を設定
3. 疎通確認:

   ```powershell
   .\scripts\run.ps1 -Project <your-project> -Scenario smoke
   ```

4. 負荷テスト:

   ```powershell
   .\scripts\run.ps1 -Project <your-project> -Scenario load
   ```

## シナリオ一覧

| シナリオ | 用途 | 目安 |
|---------|------|------|
| `smoke` | 疎通・閾値の初期確認 | 3 VU, 30秒 |
| `load` | 段階的負荷（ramp-up） | `options.stages` で制御 |

`load.js` の stages / thresholds はプロジェクトごとに調整してください。

## k6 オプションの上書き

ラッパーに k6 の追加引数を渡せます。

```powershell
.\scripts\run.ps1 -Project example-api -Scenario smoke -- --vus 5 --duration 10s
```

```bash
./scripts/run.sh example-api smoke --vus 5 --duration 10s
```

## ディレクトリ構成

```
k6/
├── docker-compose.yml
├── projects/
│   ├── _template/          # 新規プロジェクト用テンプレート
│   └── example-api/        # 動作確認用（https://test.k6.io）
├── grafana/provisioning/   # データソース・ダッシュボード自動設定
├── dashboards/             # k6 公式ダッシュボード (Grafana #2587)
├── docs/
│   └── k6-results-guide.md # ターミナル・Grafana の見方
└── scripts/
    ├── run.ps1
    └── run.sh
```

## 負荷規模の目安

単一 k6 コンテナでは、ホストの CPU/メモリに依存しますが **数千 VU / 数万 RPS 程度** が現実的な目安です。それ以上が必要な場合は k6 の分散実行（k6 Operator 等）を検討してください。

## 停止・クリーンアップ

```powershell
docker compose down
```

ボリュームも削除する場合:

```powershell
docker compose down -v
```

## セキュリティ注意

- Grafana の匿名 Admin 認証はローカル開発向けです。本番・共有環境では無効化し、適切な認証を設定してください。
- `projects/<project>/.env` には API キー等を含めないでください（`.gitignore` 済み）。
