FROM python:3.7

LABEL maintainer "Team Stingar <team.stingar@duke.edu>"
LABEL name "cowrie"
LABEL version "1.9"
LABEL release "1"
LABEL summary "Cowrie HoneyPot container"
LABEL description "Cowrie is a medium interaction SSH and Telnet honeypot designed to log brute force attacks and the shell interaction performed by the attacker."
LABEL authoritative-source-url "https://github.com/CommunityHoneyNetwork/communityhoneynetwork"
LABEL changelog-url "https://github.com/CommunityHoneyNetwork/communityhoneynetwork/commits/master"

# Set DOCKER var - used by Cowrie init to determine logging
ENV DOCKER "yes"
ENV COWRIE_VERS "v2.1.0"
ENV DEBIAN_FRONTEND "noninteractive"
# hadolint ignore=DL3008,DL3005

RUN mkdir /code
COPY requirements.txt /code/

RUN useradd cowrie

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install --no-install-recommends -y gcc python3-dev libssl-dev git authbind jq libsnappy-dev \
    && python3 -m pip install --upgrade pip setuptools wheel \
    && python3 -m pip install poetry==1.0.8 \
    && python3 -m pip install --no-build-isolation pendulum==2.1.0 \
    && python3 -m pip install -r /code/requirements.txt \
    && cd /opt \
    && git clone --branch "${COWRIE_VERS}" http://github.com/cowrie/cowrie \
    && python3 -m pip install -r /opt/cowrie/requirements.txt \
    && python3 -m pip install -r /opt/cowrie/requirements-output.txt \
    && cp /opt/cowrie/etc/userdb.example /opt/cowrie/etc/userdb.txt \
    && bash -c "touch /etc/authbind/byport/{1..1024}" \
    && chmod 755 /etc/authbind/byport/* \
    && mkdir /data/ /etc/cowrie \
    && chgrp -R 0 /data \
    && chmod -R g=u /data \
    && chown -R cowrie /data \
    && chgrp -R 0 /opt/cowrie \
    && chmod -R g=u /opt/cowrie \
    && chown -R cowrie /opt/cowrie \
    && chown -R cowrie /etc/cowrie \
    && rm -rf /opt/cowrie/.git \
    && apt-get remove -y git libssl-dev gcc python3-dev \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm /opt/cowrie/src/cowrie/output/hpfeeds.py
COPY patches/src_cowrie_ssh_transport.py /opt/cowrie/src/cowrie/ssh/transport.py
COPY output/hpfeeds3.py /opt/cowrie/src/cowrie/output/
COPY cowrie.reference.cfg /code/cowrie.reference.cfg
COPY entrypoint.sh /code/
RUN chown -R cowrie /usr/local/lib/python3.7/site-packages/twisted/plugins/
VOLUME /data

USER cowrie
ENTRYPOINT ["/code/entrypoint.sh"]
