# RSSフィード機能設計書

**機能名**: RSSフィード機能
**バージョン**: 1.1
**作成日**: 2026年1月10日
**更新日**: 2026年1月10日

## 1. 機能概要

### 1.1 目的

- 読者がフィードリーダー（Feedly等）を使用して記事更新を購読できるようにする
- リポジトリ単位での購読を可能にする

### 1.2 主要機能

1. **全体フィード**: サイト全体の公開済み記事をRSS 2.0形式で配信する
2. **リポジトリ別フィード**: 各リポジトリの公開済み記事をRSS 2.0形式で配信する
3. **フィード自動検出**: ブラウザ・フィードリーダーがフィードURLを自動検出できるようにする

### 1.3 設計方針

コンテンツネゴシエーションを採用し、既存の記事一覧エンドポイントでRSS形式のレスポンスを返す。

- 専用のFeedsControllerは作成しない
- 既存のPostsController、Repositories::PostsControllerに`respond_to`ブロックを追加する
- URL拡張子（`.rss`）またはAcceptヘッダーでフォーマットを指定可能

### 1.4 処理フロー概要

#### 1.4.1 全体フィードの配信

1. `/posts.rss`へのリクエストを受け付ける
2. 公開済み記事を公開日時の降順で最大50件取得する
3. RSS 2.0形式のXMLを生成して返却する

#### 1.4.2 リポジトリ別フィードの配信

1. `/repositories/:repository_id/posts.rss`へのリクエストを受け付ける
2. 該当リポジトリを検索し、存在しない場合は404エラーを返す
3. 該当リポジトリの公開済み記事を公開日時の降順で最大50件取得する
4. RSS 2.0形式のXMLを生成して返却する

## 2. データ要件

### 2.1 既存テーブル（変更なし）

本機能では既存のテーブルをそのまま使用する。データベースへの変更は不要。

#### 2.1.1 リポジトリ
**テーブル名**: `repositories`

| 項目名 | キー | データ型 | 必須 | 説明 |
|--------|------|----------|------|------|
| id | PK | bigint | ○ | 主キー |
| name | UK | varchar | ○ | リポジトリ名（一意） |
| url | | varchar | ○ | GitHubリポジトリURL |

#### 2.1.2 記事
**テーブル名**: `posts`

| 項目名 | キー | データ型 | 必須 | 説明 |
|--------|------|----------|------|------|
| id | PK | bigint | ○ | 主キー |
| repository_id | FK | bigint | ○ | リポジトリID |
| title | | varchar | ○ | 記事タイトル |
| summary | | text | | 記事の要約 |
| source_url | | varchar | | 元PRのURL |
| status | | varchar | ○ | 公開状態 |
| published_at | | datetime | | 公開日時 |

## 3. ビジネスルール

### 3.1 フィード対象

#### 3.1.1 記事の表示条件
- statusが「published」の記事のみをフィードに含める
- draft、skippedの記事は含めない

#### 3.1.2 件数制限
- 1フィードあたり最大50件の記事を含める
- 50件を超える場合は新しいものから50件を返す

### 3.2 ソート順

- 公開日時（published_at）の降順
- 新しい記事が先頭に配置される

### 3.3 コンテンツ形式

- 記事本文（body）は含めず、要約（summary）のみを配信する
- summaryが空の場合は空文字列とする

## 4. RSS 2.0フィード仕様

### 4.1 チャンネル要素

#### 4.1.1 全体フィード

| 要素 | 値 |
|------|------|
| title | DiffDaily |
| description | OSS変更の定点観測 - GitHubリポジトリの変更をAIが要約 |
| link | サイトルートURL |
| language | ja |
| lastBuildDate | フィード生成日時（RFC 2822形式） |

#### 4.1.2 リポジトリ別フィード

| 要素 | 値 |
|------|------|
| title | DiffDaily - {リポジトリ名} |
| description | {リポジトリ名}の変更をAIが要約 |
| link | リポジトリ別記事一覧ページURL |
| language | ja |
| lastBuildDate | フィード生成日時（RFC 2822形式） |

### 4.2 アイテム要素

各記事について以下の要素を出力する。

| 要素 | 値 | 説明 |
|------|------|------|
| title | Post.title | 記事タイトル |
| description | Post.summary | 記事の要約 |
| link | 記事詳細ページURL | posts/:idへの絶対URL |
| guid | 記事詳細ページURL | 一意識別子（isPermaLink="true"） |
| pubDate | Post.published_at | 公開日時（RFC 2822形式） |
| category | Repository.name | リポジトリ名 |
| source | Post.source_url | 元PRへのリンク（url属性として設定） |

### 4.3 出力例

```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>DiffDaily</title>
    <description>OSS変更の定点観測 - GitHubリポジトリの変更をAIが要約</description>
    <link>https://example.com/</link>
    <language>ja</language>
    <lastBuildDate>Fri, 10 Jan 2026 12:00:00 +0900</lastBuildDate>
    <item>
      <title>Rails 8.1: Active Record暗号化の改善</title>
      <description>Rails 8.1では暗号化機能が強化され...</description>
      <link>https://example.com/posts/123</link>
      <guid isPermaLink="true">https://example.com/posts/123</guid>
      <pubDate>Fri, 10 Jan 2026 10:00:00 +0900</pubDate>
      <category>rails/rails</category>
      <source url="https://github.com/rails/rails/pull/12345">GitHub PR</source>
    </item>
  </channel>
</rss>
```

## 5. 画面表示機能

### 5.1 フィード自動検出（autodiscovery）

HTMLの`<head>`内にフィードへのリンクタグを追加する。

#### 5.1.1 全ページ共通

```html
<link rel="alternate" type="application/rss+xml" title="DiffDaily RSS" href="/posts.rss">
```

#### 5.1.2 リポジトリ別記事一覧ページ

全体フィードに加え、リポジトリ別フィードへのリンクも追加する。

```html
<link rel="alternate" type="application/rss+xml" title="DiffDaily - {リポジトリ名} RSS" href="/repositories/{id}/posts.rss">
```

### 5.2 フィードリンクの表示

#### 5.2.1 ヘッダー領域

ヘッダーにRSSフィードへのリンクを追加する。

#### 5.2.2 リポジトリ別記事一覧ページ

リポジトリ名の近くにリポジトリ別フィードへのリンクを追加する。

## 6. ルーティング

### 6.1 変更内容

既存のルートにRSS形式のレスポンスを追加する。新規ルートの追加は不要。

| メソッド | パス | コントローラ#アクション | 説明 |
|----------|------|------------------------|------|
| GET | /posts(.rss) | posts#index | 記事一覧（HTML/RSS） |
| GET | /repositories/:repository_id/posts(.rss) | repositories/posts#index | リポジトリ別記事一覧（HTML/RSS） |

### 6.2 URLヘルパー

| ヘルパー名 | パス |
|------------|------|
| posts_path(format: :rss) | /posts.rss |
| repository_posts_path(repository, format: :rss) | /repositories/:repository_id/posts.rss |

## 7. コントローラ設計

### 7.1 PostsController（変更）

```
app/controllers/posts_controller.rb
```

#### 7.1.1 indexアクション

- HTMLリクエスト: 従来通りページネーション付きで返す
- RSSリクエスト: 公開済み記事を50件取得してRSS形式でレンダリング

```ruby
def index
  @repositories = Repository.with_published_posts

  respond_to do |format|
    format.html do
      @posts = Post.published.page(params[:page]).per(20)
    end
    format.rss do
      @posts = Post.published.includes(:repository).limit(50)
    end
  end
end
```

### 7.2 Repositories::PostsController（変更）

```
app/controllers/repositories/posts_controller.rb
```

#### 7.2.1 indexアクション

- HTMLリクエスト: 従来通りページネーション付きで返す
- RSSリクエスト: 該当リポジトリの公開済み記事を50件取得してRSS形式でレンダリング

```ruby
def index
  @repository = Repository.find(params[:repository_id])

  respond_to do |format|
    format.html do
      @posts = @repository.posts.published.page(params[:page]).per(20)
    end
    format.rss do
      @posts = @repository.posts.published.limit(50)
    end
  end
end
```

### 7.3 レスポンス

- Content-Type: `application/rss+xml; charset=utf-8`
- キャッシュ: 適切なCache-Controlヘッダーを設定

## 8. ビュー設計

### 8.1 RSSテンプレート

```
app/views/posts/index.rss.builder
app/views/repositories/posts/index.rss.builder
```

XML Builderを使用してRSS 2.0形式のXMLを生成する。

### 8.2 レイアウト変更

#### 8.2.1 application.html.erb

`<head>`内にautodiscoveryリンクを追加。

#### 8.2.2 repositories/posts/index.html.erb

リポジトリ別フィードのautodiscoveryリンクを追加。

## 9. エラーハンドリング

### 9.1 エラー分類

| エラーレベル | 説明 | 処理 |
|-------------|------|------|
| NOT_FOUND | 存在しないリポジトリIDが指定された | 404エラーを返す |

---

**関連資料**:
- [RSSフィード機能 要件定義書](../requirements/rss-feed.md)
