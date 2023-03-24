FROM ubuntu:18.04
USER 0

RUN apt-get -y update && apt-get -y upgrade
RUN apt-get -y install openjdk-8-jdk wget
RUN apt-get update && apt-get install -y iputils-ping
RUN mkdir /opt/tomcat
RUN mkdir /opt/helicalinsight
RUN wget https://dlcdn.apache.org/tomcat/tomcat-8/v8.5.87/bin/apache-tomcat-8.5.87.tar.gz -O /tmp/tomcat.tar.gz
RUN cd /tmp && tar xvfz tomcat.tar.gz
RUN cp -Rv /tmp/apache-tomcat-8.5.87/* /opt/tomcat/

#mysql section starts
ENV MYSQL_ROOT_PASSWORD mysql188$
ENV MYSQL_MAJOR 5.7
ENV MYSQL_VERSION 5.7.41-1debian10
#
RUN apt-get update && apt-get install -y gnupg
#Add an account for running MySQL
RUN groupadd -r mysql && useradd -r -g mysql mysql
ENV GOSU_VERSION 1.16
RUN set -eux; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates wget; \
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true

RUN mkdir /docker-entrypoint-initdb.d

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		bzip2 \
		openssl \
		perl \
		xz-utils \
		zstd \
	; \
	rm -rf /var/lib/apt/lists/*


ENV MYSQL_MAJOR 5.7
ENV MYSQL_VERSION 5.7.41-1debian10
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 467B942D3A79BD29
RUN apt-key adv --keyserver pgp.mit.edu --recv-keys 3A79BD29
RUN  { echo mysql-community-server mysql-community-server/root-pass password 'mysql188$'; echo mysql-community-server mysql-community-server/re-root-poss password 'mysql188$';} | debconf-set-selections \
  && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -yq install mysql-server-5.7 \
	&& find /etc/mysql/ -name '*.cnf' -print0 \
		| xargs -0 grep -lZE '^(bind-address|log)' \
		| xargs -rt -0 sed -Ei 's/^(bind-address|log)/#&/' \
# don't reverse lookup hostnames, they are usually another container
	&& echo '[mysqld]\nskip-host-cache\nskip-name-resolve' > /etc/mysql/conf.d/docker.cnf \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
	&& chmod 1777 /var/run/mysqld /var/lib/mysql

#Solve the problem that ubuntu cannot log in from another container
RUN sed -i 's/bind-address/#bind-address/' /etc/mysql/mysql.conf.d/mysqld.cnf

# VOLUME /var/lib/mysql
COPY ./hice_mysql_nocache.sql /docker-entrypoint-initdb.d/hice.sql
COPY mysql-docker-entrypoint.sh /usr/local/bin/
RUN ln -s /usr/local/bin/mysql-docker-entrypoint.sh /entrypoint.sh # backwards compat
RUN chmod 777 /usr/local/bin/mysql-docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/mysql-docker-entrypoint.sh"]
#mysql section ends

EXPOSE 3306 33060 8080
RUN chmod 777 /usr/local/bin/mysql_tomcat_startup.sh

CMD ["mysqld","--user","mysql"]
