FROM alpine:3.3

# Setup Operable APK repository
COPY config/docker/operable-56f35cdd.rsa.pub /etc/apk/keys/operable-56f35cdd.rsa.pub
RUN echo "@operable https://storage.googleapis.com/operable-apk/" > /etc/apk/repositories.operable && \
    cat /etc/apk/repositories >> /etc/apk/repositories.operable && \
    mv /etc/apk/repositories.operable /etc/apk/repositories

# Select mix environment to use. We declare the MIX_ENV at build time
ARG MIX_ENV
ENV MIX_ENV ${MIX_ENV:-dev}

# Install dependencies that will be used at runtime. Build
# time dependencies are installed _and_ removed during the
# build stage layer.
RUN apk update -U && \
    apk add erlang erlang-crypto erlang-dev erlang-ssh erlang-ssl erlang-mnesia erlang-syntax-tools erlang-parsetools \
            bash git postgresql-client elixir@operable

# Setup operable user
RUN adduser -h /home/operable -D operable

# Create directories and upload cog source
RUN mkdir -p /home/operable/cog /home/operable/cogctl
COPY . /home/operable/cog/
RUN chown -R operable /home/operable && \
    rm -f /home/operable/.dockerignore

# We do this all in one huge RUN command to get the smallest
# possible image.
USER root
RUN apk update -U && \
    apk add expat-dev gcc g++ make && \
    # build cog and cogctl \
    su operable - -c /home/operable/cog/scripts/docker-build && \
    # install cogctl and delete source directory \
    cp /home/operable/cogctl/cogctl /usr/local/bin/cogctl && \
    rm -rf /home/operable/cogctl && \
    # cleanup dependencies
    apk del gcc g++ && \
    rm -f /var/cache/apk/*

USER operable
WORKDIR /home/operable/cog
