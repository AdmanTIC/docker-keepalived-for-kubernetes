FROM alpine:3.18.3

RUN set -ex \
  && apk --no-cache add \
      sed \
      grep \
      patch \
      bash \
      keepalived \
      curl \
      iptables

COPY install /

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "keepalived", "-nlGdPD"]

