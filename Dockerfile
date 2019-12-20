FROM python:3.7

LABEL maintainer Team Stingar <team.stingar@duke.edu>
LABEL name "cowrie"
LABEL version "0.3"
LABEL release "1"
LABEL summary "Cowrie HoneyPot container"
LABEL description "Cowrie is a medium interaction SSH and Telnet honeypot designed to log brute force attacks and the shell interaction performed by the attacker."
LABEL authoritative-source-url "https://github.com/CommunityHoneyNetwork/communityhoneynetwork"
LABEL changelog-url "https://github.com/CommunityHoneyNetwork/communityhoneynetwork/commits/master"

# Set DOCKER var - used by Cowrie init to determine logging
ENV DOCKER "yes"
ENV COWRIE_VERS "v2.0.2"

ENV DEPLOY_KEY "foo"

RUN mkdir /code
ADD output /code/output
ADD requirements.txt /code/

RUN useradd cowrie

RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc python3-dev libssl-dev \
       git authbind jq libsnappy-dev && \
    pip3 install -r /code/requirements.txt && \
    cd /opt && \
    git clone --branch "${COWRIE_VERS}" http://github.com/cowrie/cowrie && \
    pip3 install -r /opt/cowrie/requirements.txt && \
    pip3 install -r /opt/cowrie/requirements-output.txt && \
    cp /code/output/hpfeeds.py /opt/cowrie/src/cowrie/output/hpfeeds.py && \
    cp /opt/cowrie/etc/userdb.example /opt/cowrie/etc/userdb.txt && \
    bash -c "touch /etc/authbind/byport/{1..1024}" && \
    chmod 755 /etc/authbind/byport/* && \
    mkdir /data/ && \
    chgrp -R 0 /data && \
    chmod -R g=u /data && \
    chown -R cowrie /data && \
    chgrp -R 0 /opt/cowrie && \
    chmod -R g=u /opt/cowrie && \
    chown -R cowrie /opt/cowrie && \
    rm -rf /opt/cowrie/.git && \
    apt-get remove -y git libssl-dev gcc python3-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

ADD cowrie.reference.cfg /code/cowrie.reference.cfg
ADD entrypoint.sh /code/

VOLUME /data

USER cowrie
ENTRYPOINT ["/code/entrypoint.sh"]
