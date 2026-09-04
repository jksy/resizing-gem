# CLAUDE.md — resizing-gem

[Resizing](https://www.resizing.net/) の Ruby クライアント gem（rubygems.org に `resizing` として公開）。

## テスト・Lint

テストには MySQL が必要（`docker compose up -d mysql`）。外部 API 呼び出しは `test/vcr/` のカセットを使い、実 API を叩くテストは追加しない。

```bash
bundle exec rake test                                       # 全件
bundle exec ruby -Itest -Ilib test/resizing/client_test.rb  # 単一ファイル
RAILS_VERSION=7.1 bundle exec rake test                     # Rails バージョンを変えて実行
bundle exec rubocop
```

ローカルで実行できない場合、テストの確認は CI（`.github/workflows/test.yml`。Ruby 3.1〜3.4 × Rails 6.1〜7.2）に任せてよい。

## PR 運用

- `master` に直接 push しない。feature ブランチ（`claude/` プレフィックス可）から PR を出す
- **PR には種別ラベルを必ず 1 つ付ける**（`enhancement` / `improvement` / `bug` / `security` / `documentation` / `housekeeping` / `breaking change` のいずれか）。リリースノートのカテゴリ分け（`.github/release.yml`）に使われる
  - `improvement` は gem の機能改善。CI・開発環境の整備など利用者に見えない変更は `housekeeping`
  - バージョンバンプだけの PR には `release` を付ける（リリースノートから除外される）
  - `ruby` / `tests` / `github_actions` / `documentation` / `dependencies` は `.github/labeler.yml` で自動付与される。種別ラベルは自動では付かない
- Issue 番号は PR タイトルに含めず、PR 説明に `Closes #N` と書く
- 公開 API を変える場合は `breaking change` ラベルを付け、README も更新する

## リリース手順

1. `lib/resizing/version.rb` を更新する PR に `release` ラベルを付けてマージする
2. `master` で `bundle exec rake release`（rubygems.org への公開と `v<version>` タグの push）
3. GitHub の Releases で該当タグを選び、"Generate release notes" で本文を生成して公開する

`CHANGELOG.md` は v0.8.2 で更新を止めており、リリースノートは GitHub Releases に一本化している。

## 言語ルール

| 場所 | 言語 |
|------|------|
| コミットメッセージ | 英語（Issue 番号は含めない） |
| ソースコード内コメント | 英語 |
| PR タイトル・説明 | 日本語 |
| コードレビューコメント | 日本語 |
| 人間とのやり取り全般 | 日本語 |
