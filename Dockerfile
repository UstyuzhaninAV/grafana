FROM debian:stretch-slim
MAINTAINER Anton Ustiuzhanin

ARG GRAFANA_ARCHITECTURE=amd64
ARG GRAFANA_VERSION=6.4.0
ARG GOSU_RELEASE=1.11
ARG GRAFANA_DEB_URL=https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_${GRAFANA_ARCHITECTURE}.deb
ARG GOSU_BIN_URL=https://github.com/tianon/gosu/releases/download/${GOSU_RELEASE}/gosu-${GRAFANA_ARCHITECTURE}
ARG GRAFANA_TITLE=Grafana

ENV \
  GRAFANA_ARCHITECTURE=${GRAFANA_ARCHITECTURE} \
  GRAFANA_VERSION=${GRAFANA_VERSION} \
  GRAFANA_DEB_URL=${GRAFANA_DEB_URL} \
  GOSU_BIN_URL=${GOSU_BIN_URL} \
  GF_PLUGIN_DIR=/grafana-plugins \
  GF_PATHS_LOGS=/var/log/grafana \
  GF_PATHS_DATA=/var/lib/grafana \
  GF_PATHS_CONFIG=/etc/grafana/grafana.ini \
  GF_PATHS_HOME=/usr/share/grafana \
  UPGRADEALL=true

COPY ./run.sh /run.sh

RUN \
  set -ex && \
  apt-get update && \
  apt-get -y --allow-change-held-packages --no-install-recommends install libfontconfig curl ca-certificates git jq && \
  curl -L ${GRAFANA_DEB_URL} > /tmp/grafana.deb && \
  dpkg -i /tmp/grafana.deb && \
  rm -f /tmp/grafana.deb && \
  curl -L ${GOSU_BIN_URL} > /usr/sbin/gosu && \
  chmod +x /usr/sbin/gosu && \
  apt-get autoremove -y --force-yes && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
RUN \
  #install panels
  for plugin in $(curl -s https://grafana.net/api/plugins | jq '.items[] | select(.typeName=="Panel") | .slug ' | tr -d '"' | sort); do grafana-cli --pluginsDir "${GF_PLUGIN_DIR}" plugins install $plugin; done;
RUN \
  #install datasource
  for plugin in $(curl -s https://grafana.net/api/plugins | jq '.items[] | select(.typeName=="Data Source") | .slug ' | tr -d '"' | grep -xwi --color 'prometheus\|influxdb|'); do grafana-cli --pluginsDir "${GF_PLUGIN_DIR}" plugins install $plugin; done;
RUN \
  #install zabbix app
  for plugin in $(curl -s https://grafana.net/api/plugins | jq '.items[] | select(.typeName=="Application") | .slug ' | tr -d '"' | sort | grep -wi --color 'zabbix'); do grafana-cli --pluginsDir "${GF_PLUGIN_DIR}" plugins install $plugin; done;
#RUN \
  #install all
  #for plugin in $(grafana-cli plugins list-remote | awk -F ":" '{print $2}' | awk '{print $1}' | awk 'NF > 0');  do grafana-cli --pluginsDir "${GF_PLUGIN_DIR}" plugins install $plugin; done;
RUN \
  set -ex && \
  chmod +x /run.sh && \
  apt-get remove -y --force-yes git jq && \
  apt-get autoremove -y --force-yes && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

VOLUME ["/var/lib/grafana", "/var/log/grafana", "/etc/grafana"]

EXPOSE 3000
USER grafana
ENTRYPOINT ["/run.sh"]
