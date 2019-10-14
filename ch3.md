# 色々なプログラミング環境で使うDockerのコツ

## 第３回目

参考資料

- https://www.slideshare.net/Docker/dcsf19-dockerfile-best-practices/52
- https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
- https://www.slideshare.net/zembutsu/dockerfile-bestpractices-19-and-advice?next_slideshow=1
- https://www.slideshare.net/AkihiroSuda/buildkit

### 今までの振り返り

#### Dockerの基本的な概念
- Docker Registry, Images, Containers
- Docker volume, network

#### Dockerで最も使うコマンドの復習

```sh
docker info
docker run -it alpine ash
/ # exit
docker run -d --name st debian sleep infinity
docker container inspect st
docker exec -it st bash
docker ps
docker ps -f status=exited
docker images
docker container prune
docker image prune
docker stop st
docker start st
docker rm -f $(docker ps -a -q)
docker rmi -f $(docker images -q)
```

#### 図でDockerの概要を振り返る
- Docker repgitry image container

![dockerimg](https://docs.docker.com/engine/images/architecture.svg)

- repgitry: パブリック・ローカルのdocker image 管理場所 (docker における git repgitry みたいなもの)
- image: クラス
- container: インスタンス

- Dokcer image の階層構造

![img](docker2.png)

- docker history < container id > で確認できる
- コンテナは独自のlayerを持っている

- volumeのマウント

![img](docker2-3.png)

- --mount オプションを `docker run` 時に使う
- type: volume, bind, tmpfs など

- docker container 間の Network 

![img](docker2-2.png)

- --net オプションを `docker run`に使う
- 指定しないと defualt  bridge が使われる ipで通信できるが host名で通信できない
- `docker network create xx` で新しい　bridge networkが作成できる host名で通信できる
  - `docker network inspect` で networkに所属するcontainerの情報を確認できる

### Dockerfileの基本コマンド

- `FROM` < base layer の取得 >
- `COPY` < layer が作成される >
- `RUN`  < layer が作成される >
- `CMD`
  - `["bash"]` `[]`を省略すると bin/shから呼び出されたことになる
- `WORKDIR`

> ADD は使わないことを推奨
> For other items (files, directories) that do not require ADD’s tar auto-extraction capability, you should always use COPY.

### stdinを利用して Docker imageを作成する

- Build Context なし
- Build Context  あり
  - local build context
  - remote build context (from Github < https: xxx >)
- .dockerignore

### image サイズ ビルド時間をへらすコツ

- 不要なパッケージのインストールをへらす `--no-install-recommends` `apk add --no-cache`
- multi-stage builds はアーティファクトのみ入れる
- パッケージ用のキャッシュは削除
  - `rm -rf /var/lib/apt/list/*`
  - `rm -rf /var/cache/yum/*`

### 構築キャッシュの利用

- ADDとCOPYはチェックサムをチェックする
  - ADDは余計なものもキャッシュする可能性がある (curl tar を使う)
- RUN 命令文の差分しか見ない RUN apt-get update が古くても比較されない
- 最小限のものをコピーする

### ENV と ARG の使い分け

- ARGもENVもimageのヒストリーに値が記録されてしまう
- ARGはbuild時に指定して変更することができる
- ENVは変化しない値として Dockerfile CMD なので使う
  - ARG docker build時のみ RUNの前で渡される
  - ENVは docker container 上でも使える 
  - http_proxyとhttps_proxyをargとして使った場合は特別にヒストリーに値が保存されない

### multi-stage builds

- Imagenのサイズ 減らすコツ
- CIパイプラインの構築もできる

> cacheをへらす手段もある
- ステージとしての検討例 (stage を base に image に イメージを作成できる)
  - builder: 依存関係
  - build: builder + ビルド成果物
  - cross: 複数プラットフォーム向けに構築
  - dev: builder + 開発 / デバッグツール
  - lint: 最小限の構築チェック
  - test
  - release
- COPY --from で並列化 (18.09からサポートされている buildkitを有効にする必要がある)
  - prefixをつける

### パイプの利用

- `|`,`&&`,`||`の3パターン

#### 本番環境で使う

- 構築部分は依存関係をチェック
- multi-stage buildsで生成物のみ入れる
- user `exec gosu`, `exec su-exec`

### Docker BuildKit

### その他のコマンド

- `USER`

---
## 初めてのDockerfile

Dockerfileを作成する際に最低限覚えておく必要があるコマンド

- FROM : ベースとなるイメージの指定
- RUN : docker上で実行するコマンド実行
  - 後記しますが、 `&&` と `\` 連結することで RUNコマンドで複数コマンドを実行することができる
- COPY : hostpc コンテキストをdocker上にcopyする
  - 似たようなコマンドにAddがありますが 公式でも非推奨 copyで代用できる
- CMD : docker run で実行コマンドを省略したときに実行される　["sleep" "infinity"] のように使う

> For other items (files, directories) that do not require ADD’s tar auto-extraction capability, you should always use COPY.

### stdinを使ったデモ

```sh
echo -e 'FROM alpine:3\nRUN echo "hello Dockerfile?"' | docker build -t t:t -

# または ヒアドキュメントを使って

docker build -t t:t --no-cache -<<EOF
FROM alpine:3
RUN echo "hello Dockerfile?"
EOF
```

コンテキストつき hostpcのファイルをdocker上に copyする

> コンテキストとはhostps上に存在するディレクトリを指定すると それ以下のファイルをすべて COPYコマンドで build 中に扱うことができるようになる
> すべてのファイルを一度コピーするのでビルドに時間がかかるようになる
> コンテキストは最低限にどうしても入れる必要がある場合(templateの保持など) .dockerignoreでコピー対象外とすることができる

```sh
echo "hello context" > hello.txt
mkdir child && echo "child context" > child/ctx.txt
echo -e 'FROM alpine:3\nCOPY . /root/ \nRUN cat /root/hello.txt && cat /root/child/ctx.txt' | docker build -t t:t -f- .
```

- コンテキストで指定した親フォルダをしていすることはできない `..`
- かんたんなコマンドを実行するなら, stdinの利用でOK

### Dockerfileを使ったデモ

```sh
cat -<<EOF > Dockerfile
FROM alpine:3
RUN echo "hello Dockerfile?"
EOF

docker build -t t:t .
```

このようにしておけば ベースを作ったあとDockerfileの編集をvimなどのEditorで編集を継続できる

---

## Dockerfile上で環境変数を使いたい
```sh
export ST_ENV=hello

echo ${ST_ENV}

echo -e 'FROM alpine:3\nRUN set -ux && echo ${ST_ENV} > /root/hello.txt' | docker build -t t:t -

# hostの環境変数は引き継ぐことができない
```

### Dockerfileで環境変数を扱う前に考えること

いつのタイミングでその値が必要になるかで使うコマンド等が異なる

- docker build 時のみ: 機密でなければARGを使おう
- docker build 時のみ: 機密であれば　--mount
- docker cmd 時 : 機密でなければ ENVを使いましょう
- docker cmd 時 : 機密であれば `docker run` の引数として渡しましょう

### ARGを使ったデモ

build時に値を変更できる

> 注意: docker historyを使うと設定した値を取得できてしまう
> https_proxy, http_proxyに関しては historyに残さずに利用できるようになっている
> https://github.com/moby/moby/issues/30721 に記載あり

```sh
# ヒアドキュメンで変数が展開されてしまうので \EOF or "EOF" とする
cat -<<\EOF > Dockerfile
ARG PYTHON_VERSION_ARG=2
FROM python:"${PYTHON_VERSION_ARG}"
ARG test=1
RUN python --version
EOF

# 何もつけないと python:2 をbase imageとしてビルドを行う
docker build -t t:t .
# Status: Downloaded newer image for python:2

# 指定すると build時に好きなtag を指定することができる
docker build --build-arg PYTHON_VERSION_ARG=3 --build-arg test=2 -t t:t .
# Status: Downloaded newer image for python:3
docker image history t:t
# RUNコマンドの前に変数として渡される
```

ビルド時にbaseとするイメージの指定 指定がなければデフォルトバージョンを利用する

### ENVを使ったデモ

cmd実行時に利用する (利用の仕方はビルド時に決定してcmd実行に使う定数として使うイメージ)

app.py

```python
import os

print(f'BUILD_ARG is {os.environ.get("BUILD_ARG", "not found")}')
print(f'BUILD_ENV is {os.environ.get("BUILD_ENV", "not found")}')
```

```sh
cat -<<\EOF > Dockerfile
FROM python:3

WORKDIR /app

ARG BUILD_ARG="hello"
ENV BUILD_ENV=${BUILD_ARG}

COPY app.py .

CMD ["python", "app.py"]
EOF
# ちなみに["", ""]を使わずCMD を直接書くと sh -c として実行される
# ["", ""]の形書くと execから呼ばれる = processが書き換わる
# entrypoitに関しても同様

docker build -t t:t .
```

---

## RUN の使い方のコツ

### 出来上がるイメージのサイズを削減する

RUN 実行時一回に付き, レイヤーが一つ作られる

```sh

cat -<<\EOF > Dockerfile
FROM alpine

WORKDIR /app
RUN head -c 1000000 /dev/random > rand
RUN rm rand
EOF

docker build -t t:1 .
docker image history t:1
```

改善しましょう

```sh
cat -<<\EOF > Dockerfile
FROM alpine

WORKDIR /app
RUN set -x && head -c 1000000 /dev/random > rand \
 && rm rand
EOF
# ワンライナーで &&で接続すると どこでエラーがでたか後でトレースしにくい set -x でデバッグ表示
# && は前のコマンドが成功したら次のコマンドを実行する

docker build -t t:2 .
docker image history t:2
docker images
```

余計なレイヤーができていないことが確認できる
どういうときに有効なのapt-getなどのchachを削除するとき

`apt-get update && apt-get install --no-install-recommends xx && rm -rf /var/lib/apt/list/*` のようにセットとして利用すると良い

alpine linux を使う場合は`apk add --no-cache xx` そもそもキャッシュしない

オフィシャルがdockerhubにイメージを上げているならofficialのものを使う

```sh

docker build -t python:myenv -<<EOF
FROM debian:10

RUN set -x && apt-get update \
 && apt-get install --no-install-recommends python3 python3-pip \
 && rm -rf /var/lib/apt/list/*

# 他のコマンド
EOF

#このように使うより

docker build -t python:myenv -<<EOF

FROM python:3

# 他のコマンド
EOF

# のようにしたほうが良い
```

> baseを alpine linux にしても良いが 開発環境として使う場合やりすぎかも
> pip install numpy 時にインストールが失敗する など、ちょっと開発としての環境としては削減しすぎ <あくまで個人的な感想>

時間を減らすためには前述したコンテキストを最低限にするのも効果的

> .dockerignoreの利用

キャッシュが利くようにコマンドの順番に気をつける

キャッシュが利くタイミング

- ADD, COPY: 対象のコンテキストのハッシュ値
- RUN: docker file の　更新履歴

> RUNの場合は docker fileのRUNコマンドが変更されたかどうかしか見ていない = `RUN apt-get update` を別に書いてしまうと 以降の`RUN apt-get install xx`の対象を変更しても 古い listを使ってしまう可能性がある
> RUN一つで apt-get update と　apt-get install を実行するようにしましょう。

### `|`, `&&` , `||` のパイプの使い分け

```sh
false || echo 1
true || echo 1
# || 前のコマンドの実行が失敗した場合のみ実行
true && echo 1
# && 前のコマンドの実行が成功した場合のみ実行
false | true | echo 1
# | 結果に関わらず実行
```

> && の使い所　[-n ${ENV}] || exit 1 のように環境変数が定義されているかどうか確かめるときに使う
> set -u && でもOK

---

## マルチビルドについて

- 本番リリースのためにビルド環境とリリース環境を分ける
  - CIパイプラインがDockerfile一つでかけるのではないかと思うほど強力
- **ベース環境を作って 言語ごとに環境を使い回す**

main.go
```go
package main

import "fmt"

func main() {
    fmt.Println("test")
}
```

`go mod init` で作成

go.mod
```go
module tukky/multibuild

go 1.13
```

リリース用 Dockerfile

```docker
FROM golang:1-buster AS builder

WORKDIR /app

COPY . . 

RUN GOOS=linux GOARCH=amd64 go build -o a.out

FROM alpine:3

WORKDIR /app

COPY --from=builder /app/a.out . 

CMD ["/app/a.out"]
```
alpine linuxをベースにリリース環境を構築できるのでimageサイズを小さくできる

> go GOOS と GOARCH を指定するとクロスコンパイルできる更にシングルバイナリ　コンテナと相性バツグン

開発用 Dockerfile

```docker
FROM golang:1-buster AS base-env
WORKDIR /app

FROM base-env AS dev-env

RUN set -x && apt-get update && apt-get install -y --no-install-recommends vim && rm -rf /var/lib/apt/list/*
CMD ["bash"]

FROM base-env AS builder

COPY . . 
RUN GOOS=linux GOARCH=amd64 go build -o a.out

FROM alpine:3 AS release
WORKDIR /app
COPY --from=builder /app/a.out . 
CMD ["/app/a.out"]
```
WORKDIR も 引き継ぐことができる

```sh
#targetでステージを指定
docker build --target dev-env -t t:t .
docker run -it --mount type=bind,src=$(pwd),dst=/app t:t

docker build --target release -t t:t .

export DOKCER_BUILDKIT=1
docker build --target release -t t:t .
```

> Defaultのbuildでは `--target release`としても 依存関係のない builder stageもビルドしようとする なので対策としてDockerfileを２つ用意した
>
> 後述する [buildkit](https://github.com/moby/buildkit) を使えば 依存関係のあるステージのみビルドするようになる

### gitlab へのimageのアップ

gitlab.comは無料で使える イメージリポジトリ tagのバージョン管理もできるので個人開発用途なら利用するの良いかも

```sh
docker login registry.gitlab.com -p < access token > -u < user name >
docker tag t:t registry.gitlab.com/<user name>/<project>/t:v0.1.0
docker push registry.gitlab.com/<user name>/<project>/t:v0.1.0
docker logout registry.gitlab.com
```

> access token を使うと、個人用のpassもssh key も必要ない scope は api のみ

### 本番環境のリリースについて補足

今まですべて root 権限で動作させてきた 本番環境では user 設定が必要 redis が参考としてわかりやすい

https://hub.docker.com/_/redis

docker-entrypoint.sh
```sh
#!/bin/sh
set -e

# first arg is `-f` or `--some-option`
# or first arg is `something.conf`
if [ "${1#-}" != "$1" ] || [ "${1%.conf}" != "$1" ]; then
	set -- redis-server "$@"
fi

# allow the container to be started with `--user`
if [ "$1" = 'redis-server' -a "$(id -u)" = '0' ]; then
	find . \! -user redis -exec chown redis '{}' +
	exec gosu redis "$0" "$@"
fi

exec "$@"
```

```docker
# 抜粋
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 6379
CMD ["redis-server"]
```

これを呼び出すと `docker-entrypoint.sh redis-server` として呼び出される
サービスに必要なファイルだけ オーナーを redisに変えて exec gosu redis でユーザーを redisに変えて
docker-entroypoint.sh を呼び出し直す

> gosu ユーザーを指定して実行 apline linux では su-exec

---

## その他のチェックポイント

- **本番リリース環境では1コンテナ1プロセスを守る**
- latestタグを本番環境で使わない tagは明示する
- キャッシュする順番が重要
- 行はまとめる (特に`apt-update`などを分けると古いものをキャッシュしてしまう)
- Docker公式のパッケージを使う
- タグの指定をする(プログラムで使いたいバージョンを指定する)
- BaseImageを最小のものを使う (numpyを使いたい場合はalpineを使わないこともある)
- WORKDIRでrootファイルを移動 COPY XXX . の相対パスを使う
- `>>` よりも `{} | tee` を使う

---

## moby/buildkit の利用

[moby/buildkit](https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/experimental.md)

```sh
export DOCKER_BUILDKIT=1
```
で一部機能を有効かできる

```sh
# 無効化は
unset DOCKER_BUILDKIT
```

### buildkitの効果

- buildが早い
- multi build の効率化
  - 関連するステージのみのビルド
  - --from xx と --from yy が独立している場合は ビルドの並列処理を行う

- 新機能の追
  - `# syntax` の行を Dockerfileのはじめに追加する必要がある
  - build 時の 特定のRUNコマンドのみで利用できる host psの情報を `--mount`する機能の追加
    - コンテキストマウント : hostのコンテキストをRUNコマンド実行時に行う copyが発生しないので通常のbuildより早い
    - キャッシュ : hostに直接キャッシュすることができる 同じパスのcacheは使いまわしできる
    - SECRET: **おすすめ** ビルド時だけ必要な情報を `docker build`時にしていでき、imageのヒストリーには一切情報を残さない

> docker for window では現在サポートされていない

### 新機能の一部紹介 (SECRET)

```dockerfile
# syntax=docker/dockerfile:experimental

FROM alpine:3

WORKDIR /app

RUN set -x && apk add --no-cache git jq

RUN --mount=type=secret,id=test,target=/app/secret.json jq '.' secret.json > check
```

secret.json

```json
{"TEST": "HELLO"}
```

```sh
docker build --secret id=test,src=$(pwd)/secret.json -t t:t .
docker run -it --rm t:t ash
/app # ls -lh
# secret.jsonが0byteのfileとして残っているはず
```

## 次回

### docker-compose

#### 新機能を有効にする
- https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/experimental.md
- dockerfileの中でmount
  - cache ホスト上でキャッシュ
    - docker builder prune で削除
    - `/var/cache/apt`
    - `/var/lib/apt`
    - `~/.cache/go-build`
- docker secret ビルド時のみの参照

- docker --mount=type,target=.,rw
  - コンテキストをbuild時に指定できる copyの必要がなくなる
- docker cache キャッシュを有効にする
- git clone `https://username:password@repourl.git`


> windowsでは対応してない