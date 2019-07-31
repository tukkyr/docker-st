# いろいろなプログラミング環境で使うDockerのコツ

## 第一回目

今回は初心者-中級者向けです。もうすでにdockerを使いこなしている方には退屈かもしれませんが
回を重ねるごとにデープな内容になっていく予定ですので楽しみにしていてください。

docker内部のDNSの仕組みだったり、overlay mountがどのようにDockerに生かされてるとか
gitlab.comのプライベートリポジトリにイメージpushしてCI／CAパイプラインで回す方法とかマルチステージビルドとかをやる予定です。

### 一回目目標

#### docker上にjupyterサーバーを立てて, web browserからアクセスできるようにする

#### dockerをpull, runをしたあとに,現環境のdockerの状態を確認できるようにする

- docker installを完了する
  - windows10 pro (docker for windows)
  - mac (docker for mac)
  - linux
    - CentOS
    - Debian
    - Ubuntu

- docker runでpythonの最新環境(3.7.4)を立ち上げる
  - bashでアクセスしてpythonを動作させてみる

- docker runからのデタッチ
  - `ctl-p ctl-q`

- docker bashで変更した内容を確認してみる
  - `bocker diff`

- dockerのimage, containerって何が違うの
  - イメージの中身を確認してみる `docker container history`

- デタッチしたcontainerにAttachし直す
  - `docker attach`

- docker に jupyterサーバーを立てる

- 次回はcommitで作成したimageをDockerfileで作成する

---

## 用語

- NIC: network interface cardの略
- host PC: docker daemon を動かしているPC

---

## docker install

### もうインストールしたよって方は、VM,AWS,GCPにサーバーを立てて、Dockerをインストールして見ましょう

### windows10 pro

https://docs.docker.com/docker-for-windows/install/

- hyper-vの有効化: [参照](https://docs.microsoft.com/ja-jp/virtualization/hyper-v-on-windows/quick-start/enable-hyper-v)
  - Window管理ツールにHyper-v マネージャーが表示されていればOK

- dockerhubのアカウントを作成
- [インストール先](https://hub.docker.com/editions/community/docker-ce-desktop-windows)

---

### mac

https://docs.docker.com/docker-for-mac/install/

- [インストール先](https://hub.docker.com/editions/community/docker-ce-desktop-mac)
- `Docker.dmg`をダブルクリックすればOK

---

### linux

https://docs.docker.com/install/

#### CentOS

```sh
sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine

sudo yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2

sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.rep

sudo yum install docker-ce docker-ce-cli containerd.io

sudo systemctl start docker

# 再起動後も有効にしたい場合は
sudo systemctl enable docker

# sudo なしで dockerを実行するため 一回shellを再起動する必要がある
sudo usermod -aG docker your-user

# 動作確認
docker info
```

---

#### Debian

```sh
sudo apt-get remove docker docker-engine docker.io containerd runc

sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -

# x86_64 / amd64 アーキの場合
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"

sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io

# systemctl list-units --type=service でdockerのサービス名を確認する
sudo systemctl start docker.service

# 再起動後も有効にしたい場合は
sudo systemctl enable docker.service

# sudo なしで dockerを実行するため 一回shellを再起動する必要がある
sudo usermod -aG docker your-user

# 動作確認
docker info
```

---

#### Ubuntu

```sh
sudo apt-get remove docker docker-engine docker.io containerd runc

sudo apt-get update

sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo apt-key fingerprint 0EBFCD88

# x86_64 / amd64 アーキの場合
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

sudo apt-get update

sudo apt-get install docker docker-compose

# systemctl list-units --type=service でdockerのサービス名を確認する
sudo systemctl start docker.service

# 再起動後も有効にしたい場合は
sudo systemctl enable docker.service

# sudo なしで dockerを実行するため 一回shellを再起動する必要がある
sudo usermod -aG docker your-user

# 動作確認
docker info
```

## Pythonの環境を立ち上げる

official repo: https://hub.docker.com/_/python

```sh
docker search python
docker run -it python:3.7.4-buster bash
```

docker が localに python:3.7.4-busterのimageがなければ Dockerhubからimageを取得する

imageはコンテナを作成する設計図だと思ってくれればOK

`-it` 標準入力とターミナルを作成することを指定今回はbashを動かすためにしていていると思ってくれればOK

- `--interactive` 対話
- `--tty`

python:3.7.4-buster は image名:tagの組み合わせでできている

タグの一覧は

https://registry.hub.docker.com/v2/repositories/library/${image}/tags/

```sh
# 例
curl https://registry.hub.docker.com/v2/repositories/library/python/tags/?page=4 | jq .results[].name
```

から取得できる レスポンスがjsonフォーマットなので`jq`で加工すれば良い
https://stedolan.github.io/jq/manual/

※windows for dockerはpullに失敗する404 not foundを出す可能性が有るその際は settingから**DNSサーバーを8.8.8.8(google dns)にすれば解決することがある**

```sh
root@host名(コンテナ名):
```

のような表示になるはず

```sh
cat /etc/debian_version
uname -a
python --version
```

を実行すれば debian, linux, python のバージョンを確認することできる

せっかくなので python3.7.4 からサポートされた `dataclasses` を使ってみましょう

エディターはcontainer上から好きなものをインストールして使ってください

```sh
# docker
# vimをインストールする例
apt update
apt install -y vim iproute2
```

```py
import dataclasses

@dataclasses.dataclass
class Point:
    x: float
    y: float
    z: float = 0.0

p = Point(1.5, 2.5)

print(f'Set your Point is {p}')
```

動作することを確認したら一旦コンテナから抜け出して見ましょう

`ctl-p, clt-q`を順番に押せば抜け出すことができます。 - attachで復帰

※ `exit`でも終了することができますが復帰するときのコマンドが異なります。 - docker start で復帰

## docker image と docker container ってなに

### docker imageは設計図(Registryは設計図置き場)

### docker containerは実際にできたもの

![dockerimg](https://docs.docker.com/engine/images/architecture.svg)

関係値でいうと

- class = image
- instance = container

のように考えるとわかりやすい

なので、containerには状態があって、imageには状態がない

containerからimage, imageからcontainerを作成することができる

imageを確認するコマンド (host pcで実行)

```sh
docker images
docker image ls

# imageの中身 実際にimageは積層された単なるファイルの塊なのですが詳しくは次回以降にやります
docker image history <imagename>
```

containerを確認するコマンド

```sh
docker ps
# exit した container も確認する
docker ps -a
```

---

## コンテナの状態

[dockerコマンド一覧](https://docs.docker.com/engine/reference/commandline/docker/)

![dockersts](https://miro.medium.com/max/2258/1*vca4e-SjpzSL5H401p4LCg.png)

結構わかりにくい

覚えておきたいポイント、runningとstop状態がある

まずは対になるコマンドのみ覚えよう

- docker run - docker stop : running -> stop
- docker stop - docker rm : stop -> deleted
- docker run (c-p,c-qで抜けた) - docker attach: running -> running
- docker stop - docker start : stop -> running
- docker run - docker exec : runnig さらに別のプロセスをcontainer上で実行

~~注意点はdeletedするためにはstop状態にする必要がある~~
`docker rm -f` で強制的に削除できました。

### localのDocker環境と確認・整理する

#### container

- コンテナのリストを表示 `docker container ls -a` or `docker ps -a`
- stop状態のcontainerを一斉削除 `docker container prune`
- すべての動作中のcontainerをstop状態にする `docker stop $(docker ps -q)`

`q`オプションを付けることで、containerのidのみ表示することができる = 他のコマンドと連携しやすい

#### image

- imageのリスト表示 `docker image ls` or `docker images`
- imageの詳細表示 `docker image history <containerid>`
- 使われていないかつtagがついていないimageの削除 `docker image prune`
- すべてのイメージを強制的に削除 `docker rmi -f $(docker images -q)`

コンテナに状態を残す必要はないとおもっていますので必要がなくなれば消してしまってよいと思います

- データの永続化、設計書のカスタマイズ(Dockerfile)の作成は次回以降にやります

---

## Jupiterの環境を整える

```sh
docker ps
docker attach <container id>
```

でdockercontainerの中に入れます

```sh

pip install jupyter
jupyter-notebook --generate-config
# Writing default config to: /root/.jupyter/jupyter_notebook_config.py
cd
# /roo
vim .jupyter/jupyter_notebook_config.py
# # c.NotebookApp.open_browser = True -> c.NotebookApp.open_browser = False
# # c.NotebookApp.port = 8888 -> c.NotebookApp.port = 8888
# "eth0のipaddressに ap address コマンドで調べる"
# c.NotebookApp.ip = '0.0.0.0'
jupyter-notebook --allow-root
ss -tnlp # jupyter-notebootが立ち上がっていることを確認
```

これで立ち上がるのですが、このままだとhost psからjupyter-notebookにAccessできません

アクセスできるように host psのportをcontainerにバインドするひつようがあります

しかも、docker runにしかportのバインドを指定することができません

なので、ここまでの変更をcontainerからimageを作って再現できるようにします。

detatch(c-p, c-q)で抜けます

```sh
docker diff
```

で python:3.7.4-busterとの差分確認

```sh
docker commit <container id> jupyter-notebook:latest
```

で新しくイメージを作成します。

```sh
docker run -d -p 8888:8888 -w /root jupyter:latest jupyter-notebook --allow-root
```

でdocker containerを立ち上げて

```sh
docker log <container id>
```

でtokenを調べる

- .
- .
- .

じつは上のコマンドにセキュリティー上おおきな問題がありますなにかわかりますか

-p NICを指定してあげないと、*:8888 でbindされてしまう 同じLANから見えてしまう

```sh
docker run -d -p 127.0.0.1:8888:8888 -w /root imagename:tag jupyter-notebook --allow-host
```

でlocalhostからのみしか見えないように改善できる

- rootで起動している
- tlsを使ってないので平文で通信している

---

## 宿題

jupyter-note ブックで変更した内容を
host pc にコピーする

ヒント：

```sh
docker cp --help
```

でコピーの使い方を見てみよう

container上にhttpserverを立ち上げて、host pcからアクセスする

ヒント：

```sh
python -m http.server 8080
```

で http server port 8080 で立ち上げることができる

---

## これから課題

- bash上でやったことをDockerfileに記述したい(冪等性を確保する)
- rootで起動しているため、jupyter専用のユーザーを作成してjyupyterサーバーを立ち上げたい
- notobookの内容を別のcontainerとも共有したい
- hostpc <-> container間でファイルのやり取りをしたい
  - `docker run --mount`, `docker cp src dst`
- docker compose

![compose](https://knowledge.sakura.ad.jp/images/2019/04/docker-compose-01-04-fix-680x445.png)
- 開発環境用のpip moduleとサービス用のpip モジュールを分けたい

## TODO

- 実験環境を記載する
- cis dockerを確認する

## おまけ

- [Best practices for Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/) これは絶対に読みましょう　日本語版は古いです
- mac はこれで docker daemon が動作しているttyにアタッチできる
`screen ~/Library/Containers/com.docker.docker/Data/vms/0/tty`
