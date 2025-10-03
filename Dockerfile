FROM dock.mau.dev/tulir/lottieconverter:alpine-3.22

RUN apk add --no-cache \
      python3 py3-pip py3-setuptools py3-wheel \
      py3-pillow \
      py3-aiohttp \
      py3-asyncpg \
      py3-aiosqlite \
      py3-magic \
      py3-ruamel.yaml \
      py3-commonmark \
      py3-phonenumbers \
      py3-mako \
      py3-idna \
      py3-rsa \
        py3-pyaes \
        py3-aiodns \
        py3-python-socks \
          py3-cffi \
          py3-qrcode \
      py3-brotli \
      ffmpeg \
      ca-certificates \
      su-exec \
      netcat-openbsd \
      py3-olm \
      py3-pycryptodome \
      py3-unpaddedbase64 \
      py3-future \
      bash \
      curl \
      jq \
      yq \
      gettext

COPY requirements.txt /opt/mautrix-telegram/requirements.txt
COPY optional-requirements.txt /opt/mautrix-telegram/optional-requirements.txt
WORKDIR /opt/mautrix-telegram
RUN apk add --virtual .build-deps python3-dev libffi-dev build-base \
 && pip3 install --break-system-packages /cryptg-*.whl \
 && pip3 install --break-system-packages --no-cache-dir -r requirements.txt -r optional-requirements.txt \
 && apk del .build-deps \
 && rm -f /cryptg-*.whl

# Copy config template BEFORE copying main source to prevent overwriting
COPY config.yaml /telegram/config.yaml

COPY . /opt/mautrix-telegram
RUN apk add git && pip3 install --break-system-packages --no-cache-dir .[all] && apk del git \
  && cp mautrix_telegram/example-config.yaml . && rm -rf mautrix_telegram .git build

# Ensure docker-run.sh is executable
RUN chmod +x /opt/mautrix-telegram/docker-run.sh

ENV UID=1337 GID=1337 \
    FFMPEG_BINARY=/usr/bin/ffmpeg

CMD ["/opt/mautrix-telegram/docker-run.sh"]
