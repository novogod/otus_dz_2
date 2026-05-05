# Recipe Web — производственная инсталляция

**Status:** ✅ Live at <https://recipies.mahallem.ist>
**Host:** `72.61.181.62` (`ssh -i ~/.ssh/mahallem_key_2 root@…`)

## Где что лежит

| Что | Путь / имя |
|-----|-----------|
| Репозиторий на сервере | `/var/www/recipie/otus_dz_2/` (clone of `https://github.com/novogod/otus_dz_2.git`) |
| Compose-файл | `/var/www/recipie/otus_dz_2/docker-compose.web.yml` |
| Сервис | `flutter-web` |
| Имя контейнера | `recipe_list_web` |
| Образ | `otus_dz_2-flutter-web` (build local) |
| Dockerfile | `recipe_list/Dockerfile` |
| nginx-конфиг внутри контейнера | `recipe_list/nginx.conf` |
| Внутренний порт | `80` (nginx) |
| Маппинг хоста | `127.0.0.1:8088 → 80` |

## Маршрут запросов

```
HTTPS клиент → host nginx (sites-enabled/recipies.mahallem.ist, TLS Certbot)
            → proxy_pass http://127.0.0.1:8088
                       → recipe_list_web (внутренний nginx 1.27-alpine)
                          serves /usr/share/nginx/html (Flutter web build)
```

API (логин/recipes/etc.) запрашивается фронтом отдельно по
`https://mahallem.ist/...` (через тот же host nginx, который
проксирует на `mahallem-user-portal`, `mahallem-backend` и т.д.).

## Dockerfile (multi-stage)

1. **Stage 1 — builder** (`ghcr.io/cirruslabs/flutter:3.41.0`):
   * `flutter pub get` (кэшируемый слой по `pubspec.yaml/lock`).
   * `flutter build web --release --no-tree-shake-icons`.
2. **Stage 2 — runtime** (`nginx:1.27-alpine`):
   * чистит default html;
   * копирует `/app/build/web` → `/usr/share/nginx/html`;
   * подкладывает `nginx.conf` в `/etc/nginx/conf.d/default.conf`
     (gzip + длинный кэш на хеш-ассеты + SPA fallback на
     `index.html`).

Билд занимает несколько минут (Flutter compile-to-JS); итоговый
runtime-образ — обычный Alpine + статика.

## Compose

```yaml
services:
  flutter-web:
    build:
      context: ./recipe_list
      dockerfile: Dockerfile
    container_name: recipe_list_web
    ports:
      - "127.0.0.1:8088:80"
    restart: unless-stopped
```

Сеть compose — `otus_dz_2_default` (172.18.0.0/16). Контейнер не
ходит в `mahallem`-сеть: ему это и не нужно — он раздаёт
статику, всё API-общение идёт от браузера к
`mahallem.ist`/`recipies.mahallem.ist` напрямую.

## Стандартный re-deploy

```bash
ssh -i ~/.ssh/mahallem_key_2 root@72.61.181.62
cd /var/www/recipie/otus_dz_2
git pull --ff-only
docker compose -f docker-compose.web.yml build flutter-web
docker compose -f docker-compose.web.yml up -d flutter-web
```

Опционально перед `up -d` — `docker compose -f docker-compose.web.yml
down flutter-web`, но `up -d` сам пересоздаст контейнер при
новом образе. После рестарта проверять:

```bash
docker ps --format '{{.Names}}\t{{.Status}}' | grep recipe_list_web
curl -sI http://127.0.0.1:8088/ | head -3
```

И проверить публичный URL: `curl -sI https://recipies.mahallem.ist/`.

## Замечания

* В производственной сборке нет hot-reload; любая правка Dart
  требует rebuild образа.
* `pubspec.lock` при build в Docker используется как есть —
  важно коммитить его в репозиторий, иначе локальная и серверная
  сборки разойдутся.
* `--no-tree-shake-icons` — компромисс с MaterialIcons-кастом;
  можно убрать, если каталог иконок свёлся к стандартным.
* Host-nginx (`sites-enabled/recipies.mahallem.ist`) ничего не
  знает про Flutter — он просто прокси на `8088`. При смене
  порта поменять там тоже.
