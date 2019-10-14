# 色々なプログラミング環境で使うDockerのコツ

Final

docker swarm は対象にしていません

## 復習

### dockerの基本構成

![dockerimg](https://docs.docker.com/engine/images/architecture.svg)

> RegistryとRepositoryの違い
> - Registry: dockerhub, ECR, GCP Container Registry などのimage置き場そのもの
> - Repository: Registryに置かれる　同じimage名で異なるtagを持つイメージのセット置き場

imageはReadOnlyなlayerを持っている

![img](docker2.png)

Containerも**Writableな**独自のLayerを持っている

> だたし、他のContainerとは独立している

### 基本コマンド
```sh
docker info
docker pull debian
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
# New : 使われていない(＝containerの状態がUPでない)すべてのリソースを削除
docker system prune -a
```


### docker volume

他のContainerやhostpsと共有するするため、データの永続化のために作成

![イメージ](https://docs.docker.com/storage/images/types-of-mounts-volume.png)


![img](docker2-3.png)

```sh
docker volume create ssh
# container作成時にattach(mount)する
docker run -d --name ssh --mount src=ssh,dst=/root/.ssh debian sleep infinity
docker exec -it ssh bash
```

### docker network

> コンテナ間の通知のやり取り

![img](docker2-2.png)

```sh
docker network create backend
docker run -d --name db --network backend debian sleep infinity
# networkを明示的に指定することで dockerが提供するDNSを使えるようになる
docker run -it --rm --network debian bash
$ ping db -c 3
```

### docker file

- remote registory から pull したイメージに独立したlayerを追加して新たなイメージを作成する設計図となる

- Environment variables 
  - FROM
  - COPY
  - RUN
  - ENV : containerの動作後に使う環境変数
  - ARG : build時に使う環境変数
  - CMD

> shellの環境変数はbuild時に利用できない

```dockerfile
FROM debian
RUN set -x \
 && apt-get update \
 && apt-get install -y git vim

ARG VIMRC_VERSION

COPY ./vimrc_${VIMRC_VERSION} /root/.vimrc
```

```sh
docker build --build-arg 'VIMRC_VERSION=0.1.0' -t t:1 .
# contextがDockerfileのある場所とこの異なる場合
# docker build --build-arg 'VIMRC_VERSION=0.1.0' -t t:2 -f Dockerfile-Alt ./context
docker run -it t:1 bash
```

### docker-compose とは

#### できること

- 上記で説明したDokcer container間の連携を宣言的に記述できる
- 一つのhostに独立した環境を作成することができる
  - `-p` or COMPOSE_PROJECT_NAME
- データを引き継いだまま updateできる
  - docker-compose up
- multiple compose file

#### 使われ方

- 開発環境
- 自動テスト環境
- single host deployments

### docker-composeのインストール

> docker for mac (or windows)の方はデフォルトでインストール済み

linux

```sh
sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

# Alternative install options

pip install docker-compose
```

### docker-composeのための3ステップ

- サービス(app)の実装
- Dockerfileの定義
- docker-compose.ymlの定義
- `docker-compose up` によるアプリの起動

### 実際の使用例

[Docker Engine](https://docs.docker.com/install/) と [Docker Compose](https://docs.docker.com/compose/install/) があればOK

#### python + redis

FLASKとRedisを使ってアクセスカウンタを作成する

プロジェクトについて
名前空間を分ける `docker-compose -p`オプションで指定, 指定しないとディレクトリ名としてプロジェクトが作成される

- サービス(app)の実装

app.py

```python
import time

import redis
from flask import Flask

app = Flask(__name__)
cache = redis.Redis(host='redis', port=6379)


def get_hit_count():
    retries = 5
    while True:
        try:
            return cache.incr('hits')
        except redis.exceptions.ConnectionError as exc:
            if retries == 0:
                raise exc
            retries -= 1
            time.sleep(0.5)


@app.route('/')
def hello():
    count = get_hit_count()
    return 'Hello World! I have been seen {} times.\n'.format(count)
```

FLASKのdefault portは5000

Dockerfile

```docker
FROM python:3.7-alpine
WORKDIR /code
ENV FLASK_APP app.py
ENV FLASK_RUN_HOST 0.0.0.0
RUN apk add --no-cache gcc musl-dev linux-headers bash
COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt
COPY . .
CMD ["flask", "run"]
```
docker-compose

```yaml
version: '3.7'
services:
  web:
    build: .
    ports:
      - "5000:5000"
  redis:
    image: "redis:alpine"
```

Build and run

```sh
$ docker-compose up

# 立ち上がったサービスには docker-compose exec でプロセスを立ち上げることができる
# docker-compose execはデフォルトでTTYを確保する
# コンテナ名ではなくサービス名を入れることに注意
$ docker-compose exec web bash

# cmdを上書きし 別のcontainerを立ち上げる
$ docker-compose run web bash
```

Re-build

docker-compose fileを編集する

```yaml
version: '3.7'
services:
  web:
    build: .
    ports:
      - "5000:5000"
    volumes:
      - .:/code
    environment:
      FLASK_ENV: development
  redis:
    image: "redis:alpine"
```

> FLASK_ENV=development は appが変化した場合Flask ServerをReloadし直す

```sh
docker-compose up
docker-compose down
# 指定したserviceのcontainerを立ち上げる ※depends_onに指定されているサービスも立ち上げる
docker-run 
docker-compose stop
# 無名volumeを一緒に削除 redisは無名volumeをdockerfileの中で作成するのでそのvolumeを削除
docker-compose down --volumes
```

> docker-composeを使うときは、コンテキストに位置に注意する docker-composeがdocker-compose.ymlを見つけれないと実行できない

### Multiple Compose files

デフォルトでは docker-compose.ymlとdocker-compose.override.yml

docker-compse -f 1 -f 2 で1をベースに2を上書きできる

### 環境変数

docker-composeならhostpcのshellの環境変数をそのまま利用することができる
docker-compose.yamlと同じディレクトリに置かれた`.env` fileがデフォルトの環境変数ファイルとなる

> Dockerfileは直接 shellの環境変数を扱うことができない

> ```yaml
> version: '3.7'
> services:
>   web:
>     build:
>       context: .
>       args:
>         buildarg: 1
>         #or - buildarg=1 リストでも指定可能
>     ports:
>       - "5000:5000"
>     volumes:
>       - .:/code
>     environment:
>       FLASK_ENV: development
>   redis:
>     image: "redis:alpine"
> ```

環境変数の優先順位

1. Compose file
1. Shell environment variables
1. Environment file (.env)
1. Dockerfile (ENV)
1. Variable is not defined

api.env

```txt
COMPOSE_ENV=test
```

docker-compose.yaml

```yaml
version: '3'
services:
  api:
    image: 'debian:3'
    env_file:
      - ./api.env
    environment:
      - COMPOSE_ENV=production
    command:
      - sleep
      - infinity
```

```sh
export COMPOSE_ENV=shell
docker-compose up
docker-compose exec api bash
$ env | grep COMPOSE_ENV
```

### network aliases

```yaml
version: "3.7"

services:
  web:
    image: "nginx:alpine"
    networks:
      - new

  worker:
    image: "my-worker-image:latest"
    networks:
      - legacy

  db:
    image: mysql
    networks:
      new:
        aliases:
          - database
          # newのnetworkでは db or databeseとして公開される
      legacy:
        aliases:
          - mysql
          # legacyのnetworkでは db or mysqlとして公開される

networks:
  new:
  legacy:
```

### VSCode Remote Container Debug

[VSCode Extention](https://code.visualstudio.com/docs/remote/containers)

```sh
git clone https://github.com/Microsoft/vscode-remote-try-python
```

### リファレンス

ビルドコンテキスト内で飲み有効なコマンドとdocker-compose全体に対するコマンドを区別する

- version
- < service name >
- build
  - context
  - dockerfile
  - args: docker build --build-argと同じ obj or list で指定
  - cache_from : ci のとき有効
  - shm_size
  - target : multi stage buildのtarget指定
- image
  - 単体で使うと registoryからimageのダウンロード
  - buildとあわせるとimage名の指定
- cap_add,cap_drop
- init: init プロセスから起動されるようになる (docker-init) version 3.7 以降
  - 子プロセスのゾンビ化を防ぐ
- command
- depends_on
- devices
- entrypoint
- env_file
- environment
- expose
- logging
- networks: short format, long format
  - aliasesとの組み合わせが強力
- ports
- restart: no, always, on-failure, unless-stopped
- volumes: short format, long format
- name

