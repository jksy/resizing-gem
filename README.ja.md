# Resizing

[![Gem Version](https://img.shields.io/gem/v/resizing.svg)](https://rubygems.org/gems/resizing)
[![test](https://github.com/jksy/resizing-gem/actions/workflows/test.yml/badge.svg)](https://github.com/jksy/resizing-gem/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/jksy/resizing-gem/graph/badge.svg)](https://codecov.io/gh/jksy/resizing-gem)

[English](README.md) | 日本語

画像のホスティング・変換サービス [Resizing](https://www.resizing.net/) のクライアントとユーティリティです。

## 動作環境

- Ruby 3.1.0 以上（3.1、3.2、3.3、3.4、4.0 でテスト）
- CarrierWave 連携を使う場合は Rails 7.0 以上（7.0、7.1、7.2、8.0、8.1 でテスト）
- Faraday 1.x または 2.x（1.10 と最新の 2.x でテスト）
- CarrierWave 連携を使う場合は CarrierWave 2.2.5 以上または 3.x（2.2 と 3.1 でテスト）

CI でテストしている組み合わせは `.github/workflows/test.yml` を参照してください。
上流のサポートが終了した Ruby・Rails のシリーズは、マイナーリリースでサポートを終了することがあります。その場合はリリースノートでお知らせします。

## インストール

アプリケーションの Gemfile に次の行を追加します。

```ruby
gem 'resizing'
```

続けて次を実行します。

    $ bundle install

または、直接インストールします。

    $ gem install resizing

## 設定

```ruby
Resizing.configure = {
  image_host: 'https://img.resizing.net',
  project_id: 'your-project-id',
  secret_token: 'your-secret-token'
}
```

`video_host` は動画 API の廃止にともない非推奨です。指定しても利用されず、`Configuration#video_host` や `Configuration::DEFAULT_VIDEO_HOST` を参照すると警告が出ます。将来のバージョンで削除します。

## 使い方

### クライアントの基本的な使い方

```ruby
# クライアントを初期化する
client = Resizing::Client.new

# 画像を Resizing にアップロードする
file = File.open('sample.jpg', 'r')
response = client.post(file)
# => {
#      "id"=>"a4ed2bf0-a4cf-44fa-9c82-b53e581cb469",
#      "project_id"=>"098a2a0d-0000-0000-0000-000000000000",
#      "content_type"=>"image/jpeg",
#      "latest_version_id"=>"LJY5bxBF7Ryxfr5kC1F.63W8bzp3pcUm",
#      "latest_etag"=>"\"190143614e6c342637584f46f18f8c58\"",
#      "created_at"=>"2020-05-15T15:33:10.711Z",
#      "updated_at"=>"2020-05-15T15:33:10.711Z",
#      "url"=>"/projects/098a2a0d-0000-0000-0000-000000000000/upload/images/a4ed2bf0-a4cf-44fa-9c82-b53e581cb469"
#    }

# 変換用の URL を生成する
image_id = response['id']
transformation_url = Resizing.url_from_image_id(image_id, nil, ['w_200', 'h_300'])
# => "https://img.resizing.net/projects/.../upload/images/.../w_200,h_300"
```

#### 一時画像

`temporary: true` を指定してアップロードした画像は一時画像になり、期限（`expires_at`）までに確定しなければ Resizing が削除します。`expires_in` には期限までの秒数を指定します（省略すると Resizing の既定値）。

```ruby
response = client.post(file, content_type: 'image/jpeg', temporary: true, expires_in: 3600)
response['temporary']  # => true
response['expires_at'] # => "2020-05-15T16:33:10.711Z"

# 画像を残す
client.confirm(response['id'])
```

一時画像も、期限までは通常の画像と同じように取得・変換できます。確定済みの画像を確定しても何も変わらずに成功します。期限切れや削除済みの画像を確定しようとすると `Resizing::APIError` が発生します。

### CarrierWave 連携

```ruby
class ImageUploader < CarrierWave::Uploader::Base
  include Resizing::CarrierWave

  version :list_smallest do
    process resize_to_fill: [200, 200]
  end
end

class User
  mount_uploader :image, ImageUploader
end
```

`process` は、ブラウザが画像の URL を取得するときに適用する変換を宣言するものです。アップロード時にローカルで画像処理が実行されることはありません。

CarrierWave の `:cache` コールバックに登録される uploader のバリデーションは、画像を Resizing にアップロードする前にチェックされます。

```ruby
class ImageUploader < CarrierWave::Uploader::Base
  include Resizing::CarrierWave

  def extension_allowlist
    %w[jpg jpeg gif png]
  end

  def content_type_allowlist
    [%r{\Aimage/}]
  end

  def size_range
    0..(5 * 1024 * 1024)
  end
end
```

`extension_denylist` と `content_type_denylist` も同じように働きます。拒否されたファイルはアップロードされず、通常の CarrierWave と同じく、マウントしたカラムにエラーが付いてモデルが無効になります。

`extension_allowlist` / `extension_denylist` でチェックする拡張子は、ファイルの Content-Type がわかる場合はファイル名ではなく Content-Type から決めます。Resizing の URL からダウンロードしたファイル（`remote_<column>_url=` で代入した場合など）はファイル名の末尾がバージョン文字列なので、ファイル名からは意味のある拡張子が取れません。そのため、レスポンスの `Content-Type` を使います。Content-Type が不明な場合（`application/octet-stream`）は、通常の CarrierWave と同じくファイル名の拡張子を使います。

バージョンごとに別々にアップロードすることはありません。バージョンは生成する URL の変換を変えるだけなので、1 回のアップロードですべてのバージョンをまかないます。

#### キャッシュ

マウントしたカラムにファイルを代入すると、Resizing に一時画像としてアップロードされ、モデルを保存すると確定します。バリデーションの失敗などでモデルが保存されなかった場合、画像は確定されず、期限が来ると Resizing が削除します。そのため、どこからも参照されない画像が残りません。

トランザクションがロールバックされた場合も画像は残りません。ただし、経過は CarrierWave のバージョンで異なります。

- CarrierWave 2.x はコミット後に確定するので、画像は確定されず、期限が来ると Resizing が削除します
- CarrierWave 3.x はモデルの保存時（コミット前）に確定し、ロールバックされると画像を削除します

一時画像は Resizing の既定の期間で期限切れになります。フォームを長時間開いたままにすることがある場合などは、`cache_expires_in`（秒）を上書きして変更できます。

```ruby
class ImageUploader < CarrierWave::Uploader::Base
  include Resizing::CarrierWave

  def cache_expires_in
    2.days.to_i
  end
end
```

##### フォームの再表示でアップロードを引き継ぐ

通常の CarrierWave と同じく、フォームで `<column>_cache` を送り返すと、バリデーションエラーでフォームを再表示したときに画像をアップロードし直す必要がありません。strong parameters ではカラムと一緒に `<column>_cache` も permit してください。permit しないと値が捨てられます。

```erb
<%= form_with model: @user do |form| %>
  <%= form.file_field :image %>
  <%= form.hidden_field :image_cache %>
  <%= form.submit %>
<% end %>
```

```ruby
class UsersController < ApplicationController
  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to @user
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:image, :image_cache)
  end
end
```

`<column>_cache` は、確定前の一時画像の public id を返します。復元されるのは、設定したプロジェクトの、期限切れでない一時画像だけです。それ以外（確定済みの画像など）は、CarrierWave が不正なキャッシュ名を扱うのと同じく無視されます。

#### 画像の削除

Resizing の画像は CarrierWave がファイルを削除するときに削除されます。そのため、削除のタイミングは CarrierWave のバージョンに従います。

| 操作 | CarrierWave 2.x | CarrierWave 3.x |
|---|---|---|
| `remove_<column>!` | 保存時に削除 | その場で削除 |
| カラムに `nil` / `''` を代入 | 無視（画像は残る） | 保存時に削除 |
| 別の画像を代入 | 保存時に前の画像を削除 | 保存時に前の画像を削除 |

## 開発

### Dev Container（推奨）

全員が同じ Ruby / MySQL 環境で開発できるよう、このリポジトリには [Dev Container](https://containers.dev/) を用意しています。

必要なもの：Docker と、VS Code + *Dev Containers* 拡張機能、または [`devcontainer` CLI](https://github.com/devcontainers/cli)。

1. VS Code でリポジトリを開き、**Dev Containers: Reopen in Container** を実行します
   （または `devcontainer up --workspace-folder .` を実行します）。
2. `bundle install` と MySQL の起動待ちは `.devcontainer/post-create.sh` が自動で行います。
3. コンテナ内で次を実行します。

   ```console
   $ bundle exec rake test    # テストを実行する
   $ bundle exec rubocop      # Lint を実行する
   $ bin/console              # 対話的なプロンプト
   ```

コンテナには次のものが用意されています。

- [rbenv](https://github.com/rbenv/rbenv) で管理する Ruby。コンテナ内でバージョンを切り替えられます（後述）
- CI と同じ、`resizing_gem_test` データベースを持つ MySQL 5.7
- 別の Rails バージョンでテストするための `RAILS_VERSION`。`Gemfile` と CI の `RAILS_VERSION` の切り替えと同じものです。指定しない場合、`Gemfile` は現在の Ruby で動く最新のサポート対象 Rails（8.1、Ruby 3.1 では 7.2）を選びます

gem は名前付きボリューム（`/usr/local/bundle`）にインストールされます。`vendor/`、`.bundle/`、`.ruby-lsp/` はそれぞれ専用のボリュームに置き、ホストで生成された Ruby の成果物がバインドマウント経由でコンテナに入り込まないようにしています。`vendor/` にはホストのライブラリに対してネイティブ拡張をビルドした gem が入り、`.bundle/config` は `BUNDLE_PATH` をそこに向け、`.ruby-lsp/` には Ruby LSP 拡張機能がインストールした gem が記録されるためです。ホスト側のファイルには手を加えません。

#### Ruby のバージョンを変える

イメージのビルド時に Ruby 3.1.7 がインストールされ、コンテナ作成時には `.ruby-version` に従います。コンテナ内で別のバージョンに切り替えるには次を実行します。

```console
$ rbenv install 3.3.12
$ rbenv local 3.3.12    # .ruby-version を書き込む（gitignore 済み）
$ bundle install
```

`rbenv install` に `sudo` は不要で、ビルドに必要な依存関係はイメージに入っています。イメージに入れる Ruby のバージョンを変える場合は、`.devcontainer/compose.yaml` のビルド引数 `RUBY_VERSION` を変えてリビルドします。

### Dev Container を使わない場合

リポジトリをチェックアウトしたら、`bin/setup` を実行して依存関係をインストールします。その後 `rake test` でテストを実行します。`bin/console` で、試しながら使える対話的なプロンプトも起動できます。

テストには MySQL サーバーが必要です。リポジトリ直下の `docker-compose.yml` で適切なものを起動できます（`docker compose up -d mysql`）。

テストプロセスはそれぞれ専用のデータベース（`resizing_gem_test_<host>_<pid>`）を作成し、実行が終わると削除します。そのため、複数のテストプロセスが 1 つの MySQL サーバーを共有しても、互いのテーブルを壊しません。強制終了したプロセスが残したデータベースは、次回の実行時に掃除されます。

接続先の既定値は `root:secret@127.0.0.1:3306` で、環境変数 `MYSQL_HOST`、`MYSQL_PORT`、`MYSQL_USER`、`MYSQL_PASSWORD` で上書きできます。`MYSQL_DATABASE` を指定すると、そのデータベースをそのまま使い、削除もしません。その場合、並行して実行するテストプロセスにはそれぞれ別の名前を付けてください。同じ名前だと互いのテーブルを上書きしてしまいます。

この gem をローカルマシンにインストールするには `bundle exec rake install` を実行します。新しいバージョンをリリースするには、`version.rb` のバージョン番号を更新してから `bundle exec rake release` を実行します。バージョンの git タグが作成され、git のコミットとタグが push され、`.gem` ファイルが [rubygems.org](https://rubygems.org) に公開されます。

## コントリビュート

バグ報告やプルリクエストは GitHub（https://github.com/jksy/resizing-gem ）で受け付けています。

## ライセンス

この gem は [MIT License](https://opensource.org/licenses/MIT) のもとでオープンソースとして公開しています。
