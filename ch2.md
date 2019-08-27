# いろいろなプログラミング環境で使うDockerのコツ

## 第二回目

### 第二回目の目標

#### 第一回目の振り返り

- Dockerの基本的な概念 docker image, container について
- Docker で最も使うコマンドの復習

#### Dockerのstrageとvolumeについて

- imageのLayer管理について
- Container 独自のLayerについて

- image type
  - volume
  - bind
  - tempfs

- 実際にデモで
  - volumeを使う
    - コンテナ間のデータの共有
    - データのバックアップ
  - bindを使う

#### Dockerのネットワーク

- ネットワークの確認方法
  - ss コマンド
  - ip コマンド
    - vethのペアを見つけよう
      - namespace デモ
  - dig コマンド

- container間の通信
  - デフォルト network (bridge)
  - user network (type bridge)

#### etcdをマルチコンテナーで構成

- T.B.D

### Dockerのストレージ

![img](docker2.png)

imageがLayer構成になっていることは説明したが、
Containerも独自のLayerを持っている

```sh
docker pull python:latest
docker history python:latest
```

Containerとイメージの差分はdiffで取得できる
(削除も追加も記録される 削除してもimageのサイズは変更されない)

```sh
docker run -it alpine ash
# 以下alpine linuxでの作業
/ # cd
/ # touch test.txt
/ # ctl+p, ctl+q
# 以下host psでの作業
docker diff <container id>

# or
# runを使わずにash(bash)を立ち上げる方法 <こっちの方が好み>
docker run -d alpine sleep infinity
#<container id>
docker exec -it <container id> ash
```

```sh
docker ps -s
# size: R/W layer で利用した size
# virtual size: imase + R/W layer
# CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES               SIZE
# 606d3c712c48        alpine              "ash"               5 minutes ago       Up 5 minutes                            pensive_ride        1.42MB (virtual 7MB)
```

実装はlnux kernel1の`overlayfs`で実現されている

```sh
docker info
```

※[実際はLinux distributionによって異なる](https://docs.docker.com/storage/storagedriver/select-storage-driver/)

```sh
sudo ls /var/lib/docker/containers
sudo du -sh /var/lib/docker/containers/*
```

> docker for macの人は vm上に作成されているため 直接 /var/lib/docker 以下を見ることができない
>
> `screen ~/Library/Containers/com.docker.docker/Data/vms/0/tty` で vmのttyにアタッチすることで確認可能

containerのlayerはcontainer毎にことなるため、変化内容をcontainer間で共有することが
できない、そこで volume が登場する

### Dockerのvolume

![img](docker2-3.png)

Dockerのvolumeではよく使われるものが3種類ある

- 永続化可能
  - volume: docker専用領域を使う デフォルトでは /var/lib/docker/volume/XX/_data
  - bind: host pcのfilesystemの領域をそのまま containerでも利用する
- 永続化不可能
  - tempfs: memory上に一時的に領域を確保する

> docker for macの人は vm上に作成されているため 直接 /var/lib/docker 以下を見ることができない
>
> `screen ~/Library/Containers/com.docker.docker/Data/vms/0/tty` で vmのttyにアタッチすることで確認可能

![イメージ](https://docs.docker.com/storage/images/types-of-mounts-volume.png)

-v (--volume) と --mount のオプションがあり
Docker 17.06 から --mount オプションを使うことを推奨されている
ただしこちらは削除予定はなく`should`レベルにとどまっている

 > New users should try --mount syntax which is simpler than --volume syntax.

本イベントでは`--mount`を使う

- The type of the mount, which can be `bind`, `volume`, or `tmpfs`. This topic discusses volumes, so the type is always `volume`.
- The source of the mount. For named volumes, this is the name of the volume. For anonymous volumes, this field is omitted. May be specified as `source` or `src`.
- The destination takes as its value the path where the file or directory is mounted in the container. May be specified as `destination`, `dst`, or `target`.
- The readonly option, if present, causes the bind mount to be mounted into the container as `read-only`.
The volume-opt option, which can be specified more than once, takes a key-value pair consisting of the option name and its value.

英語で書かれているが、要するに タイプとsource(マウント元)とdestination(マウント先)を決めて、
read-onlyにするかどうか選ぶだけのこと

`--mount type=volume,src=vol,dst=/app`のように使う

#### volumeを作成する(type volume)

```sh
docker volume create vol
docker volume inspect vol
# 存在しないvolumeを指定すると 自動的に新しいvolumeが作成される
docker run -d --name devtest --mount src=vol2,dst=/app nginx:latest
# docker run -d --name devtest -v myvol2:/app nginx:latest
docker run -d --name nonametest --mount dst=/app nginx:latest
docker volume ls
```

#### volume mount 共有

```sh
docker run -d --mount src=vol,dst=/app alpine touch /app/test.txt
docker ps -a
docker run -d --mount src=vol,dst=/app alpine ls /app
# 後片付け
docker volume prune
```

#### bind

```sh
docker run -d -it --name devtest --mount type=bind,source="$(pwd)"/target,target=/app nginx:latest
# docker run -d -it --name devtest -v "$(pwd)"/target:/app nginx:latest
```

#### Backup (時間が余った方は)

dockerの領域は直接Accessできないためtype volumeとbindを使ってcontainerを介して行う

```sh
# backup a container
docker run -v /dbdata --name dbstore ubuntu /bin/bash
docker run --rm --volumes-from dbstore -v $(pwd):/backup ubuntu tar cvf /backup/backup.tar /dbdata
```

```sh
# restore container from backup
docker run -v /dbdata --name dbstore2 ubuntu /bin/bash
docker rundocker run --rm --volumes-from dbstore2 -v $(pwd):/backup ubuntu bash -c "cd /dbdata && tar xvf /backup/backup.tar --strip 1"
```

### Dockerのネットワークについて

ipv4のネットワークとvethによる仮想L2スイッチ, brctlによる仮想L３スイッチが内部で使われているため
ネットワークのL2,L3に詳しくないとついていくのは厳しいかも

内容が理解できなかった方はcontainer間の通信方法注目していただけると助かります

![img](docker2-2.png)

上の図のようにBridge networkを利用して通信を行う
実際の実装は kernel namespace と veth により実現

--linkと環境変数をつかったやり方は将来削除予定のため今回は説明の対象外　詳しくは[こちら](https://docs.docker.com/network/links/)

> Warning: The --link flag is a legacy feature of Docker. It may eventually be removed. Unless you absolutely need to continue using it, we recommend that you use user-defined networks to facilitate communication between two containers instead of using --link.

#### 公式のチュートリアルにトライしよう

[リンク先](https://docs.docker.com/network/network-tutorial-standalone/)

##### User-Dridge

```sh
docker run -dit --name co1 --network net alpine ash
docker run -dit --name co2 --network net alpine ash
docker run -dit --name co3 alpine ash
docker run -dit --name co4 --network net alpine ash
docker connect bridge co4
docker network connect bridge co4
```

```sh
docker container ls
docker network inspect bridge
docker network inspect net

# Subnetが 172.18 と 178.19 でネットワークが分離されている
```

```sh
docker container attach co1

/ # ping -c 2 co2
/ # ping -c 2 c3
# 同じネットワーク上にいないので見つからない
# ip address show で ネットワークが見れる
```

```sh
docker container attach co4
/ # ping -c 2 co1
/ # ping -c 3 co3
# bad address 'co3'
/ # ping -c 172.17.0.2
```

```sh
ip link show
docker container attach co4
/ # ip link show
/ # apk add --no-cache bind-tool
/ # dig co1 A
/ # cat /etc/resolv.conf
# 127.0.0.11 に向いているはず
docker container attach co3
/ # cat /etc/resolv.conf
# host pc と同じ DNS server に向いているはず
docker rm -f co1 co2 co3 co4
docker network rm net
```

##### ホストネットワーク

localhostでお互いと通信することができる

hostのnetifをそのまま利用している

eh0もdocker0のnetifもそのまま利用できる

[リンク先](https://docs.docker.com/network/network-tutorial-host/)

### localdynamodbを使う

T.B.D

### 補足

#### Docker の logging

[loging](https://docs.docker.com/config/containers/logging/configure/)

#### Docker の セキュリティー

```sh
--cap-add=SYS_PTRACE --security-opt seccomp=unconfined
```
