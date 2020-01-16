#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
FROM ubuntu:18.04

RUN  export DEBIAN_FRONTEND=noninteractive
ENV  DEBIAN_FRONTEND noninteractive
RUN  dpkg-divert --local --rename --add /sbin/initctl

RUN apt-get -y update; apt-get -y install gnupg2 wget ca-certificates rpl pwgen

RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

#-------------Application Specific Stuff ----------------------------------------------------

# We add postgis as well to prevent build errors (that we dont see on local builds)
# on docker hub e.g.
# The following packages have unmet dependencies:
RUN apt-get update; apt-get install -y postgresql-client-11 postgresql-common postgresql-11 \
    postgresql-11-postgis-2.5 postgresql-11-pgrouting netcat libpq-dev \
    software-properties-common gdal-bin

# Open port 5432 so linked containers can see them
EXPOSE 5432

# We need Python 3.5 because it's the last version that supports Pandas 0.18.
# Python 3.5 is no longer included in the default apt-get repo in Ubuntu 18.04, so we
# add the "Deadsnakes" repo where apt-get can find older Python version:
RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt-get update

# Install python 3.5 from deadsnakes
RUN apt-get install -y libpq-dev build-essential python3.5 python3.5-dev python3-pip python3.5-venv

# update pip
RUN python3.5 -m pip install pip --upgrade
RUN python3.5 -m pip install wheel

# `python` should point to python3.5
RUN ln -s /usr/bin/python3.5  /usr/bin/python

# Run any additional tasks here that are too tedious to put in
# this dockerfile directly.
ADD env-data.sh /env-data.sh
ADD setup.sh /setup.sh
RUN chmod +x /setup.sh
RUN /setup.sh

# We will run any commands in this when the container starts
ADD docker-entrypoint.sh /docker-entrypoint.sh
ADD setup-conf.sh /
ADD setup-database.sh /
ADD setup-pg_hba.sh /
ADD setup-replication.sh /
ADD setup-ssl.sh /
ADD setup-user.sh /
RUN chmod +x /docker-entrypoint.sh

# Heliostats specific commands
# copied from https://github.com/kwha-docker/postgis-marvin/blob/master/Dockerfile
RUN apt-get install -y libssl-dev libffi-dev \
    python-tk libncurses5-dev bash s3cmd jq git lftp curl virtualenv

ADD . /postgis-public

RUN pip install -r /postgis-public/requirements-marvin.txt
RUN pip install -r /postgis-public/requirements-heliostats.txt

ENTRYPOINT /docker-entrypoint.sh
