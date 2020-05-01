FROM ubuntu:18.04


# Sonradan Eklendi
ENV PYTHON2_DEBIAN_VERSION 2.7
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64

RUN apt-get update \
    && apt-get install -y \
    openjdk-8-jre python less curl openssh-server openssh-client \
    --allow-unauthenticated curl wget less \
    --no-install-recommends python"${PYTHON2_DEBIAN_VERSION}" \
    sudo \
    vim
# Sonradan Eklend

# ---------- HADOOP SETUP ----------
ARG HADOOP_MIRROR="http://apache.mirrors.ionfish.org/hadoop/common/hadoop"
ARG HADOOP_VERSION="2.9.2"
ARG HADOOP_BIN="${HADOOP_MIRROR}-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"

RUN curl -s $HADOOP_BIN | tar -xz -C / && \
    mv hadoop-$HADOOP_VERSION hadoop

RUN mkdir /hadoop/dfs
COPY hadoop/hadoop-env.sh /hadoop/etc/hadoop/hadoop-env.sh
COPY hadoop/core-site.xml /hadoop/etc/hadoop/core-site.xml
COPY hadoop/hdfs-site.xml /hadoop/etc/hadoop/hdfs-site.xml

## ssh without password
RUN ssh-keygen -t rsa -P '' -f /root/.ssh/id_rsa
RUN cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
RUN chmod 0600 /root/.ssh/authorized_keys
COPY ssh_config /root/.ssh/config
RUN chmod 400 /root/.ssh/config

ENV HADOOP_HOME /hadoop

## Format namenode
RUN /hadoop/bin/hdfs namenode -format
# ---------- HADOOP SETUP ----------

# ---------- HIVE SETUP ----------
ARG HIVE_MIRROR="http://apache.mirrors.ionfish.org/hive"
ARG HIVE_VERSION="2.3.7"
ARG HIVE_BIN="${HIVE_MIRROR}/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz"

# Setup Hive
RUN curl -s $HIVE_BIN | tar -xz -C / \
    && mv apache-hive-$HIVE_VERSION-bin hive

COPY hive/hive-site.xml /hive/conf/hive-site.xml
# ---------- HIVE SETUP ---------

## Setup Postgres
RUN DEBIAN_FRONTEND=noninteractive apt install -y postgresql postgresql-contrib
RUN su postgres -c '/usr/lib/postgresql/10/bin/initdb -D /var/lib/postgresql/10/main2 --auth-local trust --auth-host md5'

# ---------- PRESTO SETUP ----------
ARG MIRROR="https://repo1.maven.org/maven2/io/prestosql"
ARG PRESTO_VERSION="331"
ARG PRESTO_BIN="${MIRROR}/presto-server/${PRESTO_VERSION}/presto-server-${PRESTO_VERSION}.tar.gz"
ARG PRESTO_CLI_BIN="${MIRROR}/presto-cli/${PRESTO_VERSION}/presto-cli-${PRESTO_VERSION}-executable.jar"

USER root

ENV PRESTO_HOME /presto
ENV PRESTO_USER presto
ENV PRESTO_CONF_DIR ${PRESTO_HOME}/etc
ENV PATH $PATH:$PRESTO_HOME/bin

RUN useradd \
        --create-home \
        --home-dir ${PRESTO_HOME} \
        --shell /bin/bash \
        --password presto \
        $PRESTO_USER

RUN echo "presto ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN mkdir -p $PRESTO_HOME \
    && wget --quiet $PRESTO_BIN \
    && tar xzf presto-server-${PRESTO_VERSION}.tar.gz \
    && rm -rf presto-server-${PRESTO_VERSION}.tar.gz \
    && mv presto-server-${PRESTO_VERSION}/* $PRESTO_HOME \
    && rm -rf presto-server-${PRESTO_VERSION} \
    && mkdir -p ${PRESTO_CONF_DIR}/catalog/ \
    && mkdir -p ${PRESTO_HOME}/data \
    && cd ${PRESTO_HOME}/bin \
    && wget --quiet ${PRESTO_CLI_BIN} \
    && mv presto-cli-${PRESTO_VERSION}-executable.jar presto \
    && chmod +x presto \
    && chown -R ${PRESTO_USER}:${PRESTO_USER} $PRESTO_HOME
# ---------- PRESTO SETUP ----------

COPY presto/catalog $PRESTO_HOME/etc/catalog
COPY presto/jvm.config.template $PRESTO_HOME/etc/jvm.config.template
COPY presto/config.properties.template $PRESTO_HOME/etc/config.properties.template
COPY presto/log.properties $PRESTO_HOME/etc/log.properties
COPY presto/node.properties $PRESTO_HOME/etc/node.properties


# Copy setup script
COPY start_services.sh /root/start_services.sh
RUN chown root:root /root/start_services.sh
RUN chmod 700 /root/start_services.sh

# Start services
CMD ["/root/start_services.sh"]

EXPOSE 8080
