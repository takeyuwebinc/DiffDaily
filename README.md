# DiffDaily

GitHubリポジトリの変更を定点観測し、LLMを用いて技術者向けの要約記事を自動生成・投稿するブログプラットフォーム。

**コンセプト**: "Deep & Concise" - コミットログの海から、重要な技術的変更だけを毎日お届けする。

## 機能

- GitHubリポジトリのPull Requestを監視
- Claude Sonnet 4.5による技術記事の自動生成
- Markdown形式の記事をデータベースに保存
- TailwindCSSを使ったモダンなUI
- Solid Queueによるジョブ管理

## 技術スタック

- **Framework**: Ruby on Rails 8.1.1
- **Database**: SQLite3
- **Job Queue**: Solid Queue
- **CSS**: TailwindCSS
- **LLM API**:
  - Anthropic Claude Sonnet 4.5 (記事生成)
  - Google Gemini 2.5 Pro (品質レビュー)
- **GitHub API**: Octokit

## セットアップ

### 1. 依存関係のインストール

```bash
bundle install
```

### 2. 環境変数の設定

`.env.sample` をコピーして `.env` を作成します。

```bash
cp .env.sample .env
```

`.env` ファイルを編集して、以下の環境変数を設定してください。

#### GitHub API Token の作成

1. https://github.com/settings/tokens にアクセス
2. "Generate new token" → "Generate new token (classic)" を選択
3. 必要な権限（Scopes）を選択：
   - **公開リポジトリのみ**: `public_repo` をチェック
   - **プライベートリポジトリも含む**: `repo` をチェック
4. "Generate token" をクリックしてトークンを生成
5. 生成されたトークンをコピーして `.env` に設定

**Fine-grained tokensを使用する場合**:
- Repository permissions:
  - Pull requests: `Read-only`
  - Contents: `Read-only`
  - Metadata: `Read-only` (自動付与)

```bash
# GitHub API Token (必須)
GITHUB_ACCESS_TOKEN=your_github_token_here

# Anthropic API Key (Claude Sonnet 4.5) - 記事生成用
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# Google Gemini API Key - 記事品質レビュー用（オプション）
GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_SERVICE_TYPE=generative-language-api
```

#### Gemini API の設定（記事レビュー機能）

記事の品質レビュー機能にはGoogle Gemini 2.5 Proを使用します。以下の2つの方法があります：

**Option 1: Generative Language API（簡単・開発用）**

1. https://aistudio.google.com/app/apikey にアクセス
2. "Create API Key" をクリックしてAPIキーを生成
3. `.env` に設定：

```bash
GEMINI_API_KEY=your_api_key_here
GEMINI_SERVICE_TYPE=generative-language-api
```

⚠️ **注意**: Generative Language APIは地域制限があります。一部のサーバー環境では `User location is not supported` エラーが発生する可能性があります。

**Option 2: Vertex AI API（本番環境推奨）**

地域制限がなく、本番環境に適しています。

1. **Google Cloud Consoleで新しいプロジェクトを作成**: https://console.cloud.google.com/

2. **必要なAPIライブラリを有効化**:
   - Vertex AI API: https://console.cloud.google.com/apis/library/aiplatform.googleapis.com
   - Cloud Resource Manager API: https://console.cloud.google.com/apis/library/cloudresourcemanager.googleapis.com

   または、gcloudコマンドで有効化：
   ```bash
   gcloud services enable aiplatform.googleapis.com
   gcloud services enable cloudresourcemanager.googleapis.com
   ```

3. **サービスアカウントを作成**:
   - IAM & Admin > サービスアカウント: https://console.cloud.google.com/iam-admin/serviceaccounts
   - 「サービスアカウントを作成」をクリック
   - 名前: `diffdaily-vertex-ai`
   - ロール: `Vertex AI ユーザー` を付与
   - JSONキーを作成してダウンロード

4. `.env` に設定：

```bash
GOOGLE_CLOUD_PROJECT_ID=your-project-id
GOOGLE_CLOUD_REGION=us-central1  # または asia-northeast1 (東京)
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
GEMINI_SERVICE_TYPE=vertex-ai-api
```

**レビュー機能の無効化**

レビュー機能が不要な場合は、環境変数で無効化できます：

```bash
ENABLE_ARTICLE_REVIEW=false
```

#### Google OAuth2 の設定（管理画面ログイン）

管理画面（`/admin`）へのログインにはGoogle OAuth2を使用します。

**1. Google Cloud Consoleでプロジェクトを作成または選択**

https://console.cloud.google.com/

**2. OAuth同意画面を設定**

1. APIs & Services > OAuth consent screen にアクセス
2. User Type: `Internal`（組織内ユーザーのみ）または `External` を選択
3. アプリ名、サポートメールなどを入力
4. スコープは `email`, `profile`, `openid` を追加

**3. OAuth 2.0クライアントIDを作成**

1. APIs & Services > Credentials にアクセス
2. 「認証情報を作成」→「OAuth クライアント ID」を選択
3. アプリケーションの種類: `ウェブ アプリケーション`
4. 承認済みのリダイレクトURI:
   - 開発環境: `http://localhost:3000/auth/google_oauth2/callback`
   - 本番環境: `https://your-domain.com/auth/google_oauth2/callback`
5. 作成後、クライアントIDとクライアントシークレットをコピー

**4. `.env` に設定**

```bash
# Google OAuth2 (for admin login)
GOOGLE_CLIENT_ID=your_client_id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your_client_secret
```

⚠️ **注意**: デフォルトでは `@takeyuweb.co.jp` ドメインのアカウントのみログインが許可されています。別のドメインを使用する場合は `GOOGLE_OAUTH_ALLOWED_DOMAIN` 環境変数を設定してください。

**トラブルシューティング**

Vertex AI API使用時のよくあるエラー：

- **403 Permission Denied**: サービスアカウントに適切なロールが付与されていません
  - 解決: `Vertex AI ユーザー` ロールを追加

- **403 API not enabled**: APIライブラリが有効化されていません
  - 解決: Vertex AI APIとCloud Resource Manager APIを有効化

- **認証情報が見つからない**: 環境変数が正しく設定されていません
  - 確認: `GOOGLE_APPLICATION_CREDENTIALS` のパスが正しいか確認
  - 確認: JSONキーファイルが存在するか確認

確認コマンド：
```bash
# プロジェクトIDの確認
gcloud config get-value project

# 有効化されているAPIの確認
gcloud services list --enabled | grep -E "aiplatform|cloudresourcemanager"

# サービスアカウントの確認
gcloud iam service-accounts list
```

### 3. データベースのセットアップ

```bash
rails db:setup
```

これにより、`basecamp/kamal` リポジトリがデフォルトで登録されます。

## 使い方

### 開発サーバーの起動

```bash
bin/dev
```

ブラウザで `http://localhost:3000` にアクセスしてください。

### ジョブの実行

#### 特定のリポジトリの記事を生成

Railsコンソールから手動でジョブを実行します。

```bash
rails console
```

```ruby
# リポジトリ名を指定
DailySummaryJob.perform_now("rails/rails")

# またはリポジトリIDを指定
DailySummaryJob.perform_now(1)
```

#### 全リポジトリをチェック

登録されているすべてのリポジトリの更新をチェックします。

```bash
rails runner "DailyRepositoryCheckJob.perform_now"
```

### 定期実行（本番環境・開発環境）

Solid Queueの定期実行機能を使って、自動で記事を生成できます。

`config/recurring.yml` で設定されています：

```yaml
production:
  # 完了したジョブのクリーンアップ（毎時12分）
  clear_solid_queue_finished_jobs:
    command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
    schedule: every hour at minute 12

  # 全リポジトリの日次チェック（毎朝6時）
  daily_repository_check:
    class: DailyRepositoryCheckJob
    schedule: every day at 6am

development:
  # 開発環境でも日次チェックを実行（毎朝6時）
  daily_repository_check:
    class: DailyRepositoryCheckJob
    schedule: every day at 6am
```

## プロジェクト構成

```
app/
├── actions/                      # Actionパターン（単一責任の実行可能オブジェクト）
│   ├── application_action.rb    # Action基底クラス
│   ├── github/
│   │   └── fetch_recent_changes.rb  # GitHub PR取得・フィルタリング
│   └── content/
│       └── generate_article.rb      # AI記事生成
├── controllers/
│   └── posts_controller.rb       # 記事の一覧・詳細表示
├── jobs/
│   ├── daily_summary_job.rb           # 特定リポジトリの日次要約ジョブ
│   └── daily_repository_check_job.rb  # 全リポジトリの日次チェックジョブ
├── models/
│   ├── repository.rb             # リポジトリモデル
│   └── post.rb                   # 記事モデル
└── views/
    ├── layouts/
    │   └── application.html.erb  # レイアウト（ヘッダー含む）
    └── posts/
        ├── index.html.erb        # 記事一覧
        └── show.html.erb         # 記事詳細
```

### Actionパターンについて

DiffDailyでは、ビジネスロジックをActionパターンで実装しています。各Actionは単一の責任を持ち、`perform`メソッドで実行されます。

- **Github::FetchRecentChanges**: GitHubのPull Requestsと差分を取得し、ノイズをフィルタリング
- **Content::GenerateArticle**: PR情報からClaude Sonnet 4.5を使って技術記事を生成

使用例:
```ruby
# Actionの実行（クラスメソッド）
changes = Github::FetchRecentChanges.perform("basecamp/kamal", hours_ago: 24)

# インスタンスメソッドとしても実行可能
action = Content::GenerateArticle.new("basecamp/kamal", pr_data)
article = action.perform
model_name = action.model_name  # "Claude Sonnet 4.5"
```

## データモデル

### Repository

| カラム | 型 | 説明 |
|--------|-----|------|
| name | string | リポジトリ名 (例: "basecamp/kamal") |
| url | string | リポジトリURL |

### Post

| カラム | 型 | 説明 |
|--------|-----|------|
| repository_id | integer | 関連リポジトリID |
| title | string | 記事タイトル |
| body | text | 記事本文（Markdown） |
| source_url | string | 元となるPRのURL |
| generated_by | string | 使用したLLMモデル名 |
| published_at | datetime | 公開日時 |
| status | enum | ステータス (draft/published/skipped) |

## カスタマイズ

### 新しいリポジトリの追加

```ruby
Repository.create!(
  name: "owner/repository",
  url: "https://github.com/owner/repository"
)
```

### システムプロンプトのカスタマイズ

記事生成のスタイルや内容を変更したい場合は、`app/actions/content/generate_article.rb` の `SYSTEM_PROMPT` を編集してください。

```ruby
# app/actions/content/generate_article.rb
SYSTEM_PROMPT = <<~PROMPT
  # Role
  あなたは「DiffDaily」の専属ライターです...

  # カスタマイズ例：
  # - 記事のトーン（カジュアル/フォーマル）
  # - 対象読者（初心者/上級者）
  # - 記事の長さ
  # - フィルタリング条件
PROMPT
```

## デプロイ（Kamal）

DiffDailyはKamalを使用してコンテナ化されたアプリケーションをデプロイします。

### 初回デプロイ

1. `.kamal/secrets`ファイルで環境変数を設定
2. サーバーをセットアップ：

```bash
kamal setup
```

### 更新デプロイ

```bash
kamal deploy
```

### Vertex AI APIを使用する場合

サーバー環境で地域制限エラーが発生する場合は、以下の手順でVertex AI APIを設定します。

#### 1. サービスアカウントキーをサーバーにアップロード

```bash
# サーバー上でディレクトリを作成
ssh user@100.117.198.73 "mkdir -p /var/lib/diffdaily/credentials && chmod 700 /var/lib/diffdaily/credentials"

# ローカルからJSONキーファイルをアップロード
scp diffdaily-vertex-ai-xxxxx.json user@100.117.198.73:/var/lib/diffdaily/credentials/google-credentials.json

# パーミッション設定
ssh user@100.117.198.73 "chmod 600 /var/lib/diffdaily/credentials/google-credentials.json"
```

#### 2. `config/deploy.yml`を編集

```yaml
env:
  clear:
    GEMINI_SERVICE_TYPE: "vertex-ai-api"
    GOOGLE_CLOUD_REGION: "us-central1"  # または "asia-northeast1"

# ボリュームマウントを追加
volumes:
  - "/var/lib/diffdaily/storage:/rails/storage"
  - "/var/lib/diffdaily/credentials:/rails/credentials:ro"
```

#### 3. `.kamal/secrets`を編集

コンテナ内のパスを指定：

```bash
GOOGLE_CLOUD_PROJECT_ID=your-project-id
GOOGLE_APPLICATION_CREDENTIALS=/rails/credentials/google-credentials.json
```

#### 4. デプロイ

```bash
kamal deploy
```

#### 代替方法: 環境変数として渡す

JSONキーをbase64エンコードして環境変数として渡すこともできます：

```bash
# ローカルでbase64エンコード
base64 -w 0 diffdaily-vertex-ai-xxxxx.json > credentials.b64

# .kamal/secretsに追加
GOOGLE_CREDENTIALS_BASE64=$(cat credentials.b64)
```

`config/deploy.yml`:
```yaml
env:
  secret:
    - GOOGLE_CREDENTIALS_BASE64
```

アプリケーション起動時にデコード（docker-entrypointなど）：
```bash
if [ -n "$GOOGLE_CREDENTIALS_BASE64" ]; then
  echo "$GOOGLE_CREDENTIALS_BASE64" | base64 -d > /tmp/google-credentials.json
  export GOOGLE_APPLICATION_CREDENTIALS=/tmp/google-credentials.json
fi
```

⚠️ **注意**: この方法は環境変数のサイズ制限に注意が必要です。

#### セキュリティのベストプラクティス

- **パーミッション**: JSONキーファイルは`600`（所有者のみ読み書き可能）
- **ディレクトリ**: 認証情報ディレクトリは`700`（所有者のみアクセス可能）
- **読み取り専用マウント**: `:ro`フラグでコンテナ内を読み取り専用に
- **バックアップ**: サーバー外に安全にバックアップを保管
- **ローテーション**: 定期的にサービスアカウントキーをローテーション
- **.gitignore**: JSONキーファイルは絶対にGitにコミットしない

### 便利なコマンド

```bash
# コンソール接続
kamal console

# ログ確認
kamal logs

# シェル接続
kamal shell

# 環境変数確認
kamal app exec "env | grep GEMINI"
```

## ライセンス

MIT

## 貢献

Pull Requestsを歓迎します。
