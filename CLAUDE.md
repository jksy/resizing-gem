# CLAUDE.md — resizing-gem

[Resizing](https://www.resizing.net/) の Ruby クライアント gem（rubygems.org に `resizing` として公開）。

## 開発環境

devcontainer（`.devcontainer/`）を用意してある。VS Code の "Reopen in Container"、または `devcontainer up --workspace-folder .` で、Ruby・MySQL・`bundle install` まで揃った状態になる。

Ruby は rbenv 管理で `.ruby-version` に従う。別バージョンを試す場合はコンテナ内で `rbenv install <version>` → `rbenv local <version>` → `bundle install`（sudo 不要）。イメージに焼くバージョンを変える場合は `.devcontainer/compose.yaml` の `RUBY_VERSION` を変更してリビルドする。

devcontainer を使わない場合はテスト用に MySQL を自前で起動する（`docker compose up -d mysql`）。接続先は `MYSQL_HOST` / `MYSQL_PORT` / `MYSQL_USER` / `MYSQL_PASSWORD` で上書きでき、既定は `root:secret@127.0.0.1:3306`。

データベースはテストプロセスごとに `resizing_gem_test_<ホスト識別子>_<pid>` を作成し、終了時に破棄する（並行実行しても壊れないようにするため。強制終了で残ったものは次回実行時に掃除する）。`MYSQL_DATABASE` を指定した場合はそのデータベースをそのまま使い破棄もしないので、並行実行するときは名前を分ける。

## テスト・Lint

外部 API 呼び出しは `test/vcr/` のカセットを使い、実 API を叩くテストは追加しない。

```bash
bundle exec rake ci                                         # RuboCop + テスト（push 前チェックと同じ）
bundle exec rake test                                       # 全件
bundle exec ruby -Itest -Ilib test/resizing/client_test.rb  # 単一ファイル
RAILS_VERSION=7.1 bundle exec rake test                     # Rails バージョンを変えて実行
bundle exec rubocop
```

ローカルで実行できない場合、テストの確認は CI（`.github/workflows/test.yml`。Ruby 3.1〜3.4 × Rails 6.1〜7.2）に任せてよい。

## push 前チェック

`git push` すると `git-hooks/pre-push` が `bundle exec rake ci`（RuboCop + テスト）を実行し、失敗した時点で push を中断する。**CI が落ちる前に気づくための仕組みなので、`--no-verify` で飛ばさないこと**（飛ばした場合はその旨を報告する）。

有効化はクローンごとに一度だけ必要で、`bin/setup` が `git config core.hooksPath git-hooks` を設定する。設定済みかは `git config core.hooksPath` で確認できる（worktree でも設定は共有される）。

```bash
bin/setup                        # bundle install + git hooks の有効化
PRE_PUSH_SKIP_TESTS=1 git push   # RuboCop だけにしてテストを省く
```

チェックは gem が入っている環境で走る。`bundle check` が通る環境（devcontainer の中、または `bundle install` 済みのホスト）ならそのまま、通らなければ devcontainer CLI か docker compose 経由で devcontainer 内で実行する。

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
