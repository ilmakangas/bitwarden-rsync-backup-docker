FROM node:alpine3.18 AS builder
RUN apk add --no-cache python3 build-base make
RUN npm install --prefix /bw @bitwarden/cli@2023.9.0

FROM node:alpine3.18
RUN apk add --no-cache bash age rsync openssh
COPY --from=builder /bw /bw
COPY app.sh /app.sh
COPY bw /usr/local/bin/bw
WORKDIR /
ENTRYPOINT ["/app.sh"]
