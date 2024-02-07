FROM debian:stable-slim

ARG rehlds_build=3.13.0.788
ARG metamod_version=1.3.0.138
ARG amxmod_version=1.8.2
ARG regamedll_version=5.26.0.668
ARG reapi_version=5.24.0.300
ARG steamcmd_url=https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
ARG rehlds_url="https://github.com/dreamstalker/rehlds/releases/download/$rehlds_build/rehlds-bin-$rehlds_build.zip"
ARG metamod_url="https://github.com/theAsmodai/metamod-r/releases/download/$metamod_version/metamod-bin-$metamod_version.zip"
ARG amxmod_url="http://www.amxmodx.org/release/amxmodx-$amxmod_version-base-linux.tar.gz"
ARG regamedll_url="https://github.com/s1lentq/ReGameDLL_CS/releases/download/$regamedll_version/regamedll-bin-$regamedll_version.zip"
ARG reapi_url="https://github.com/s1lentq/reapi/releases/download/$reapi_version/reapi-bin-$reapi_version.zip"


# Fix warning:
# WARNING: setlocale('en_US.UTF-8') failed, using locale: 'C'.
# International characters may not work.
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales \
 && rm -rf /var/lib/apt/lists/* \
 && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8
ENV LC_ALL en_US.UTF-8

# Fix error:
# Unable to determine CPU Frequency. Try defining CPU_MHZ.
# Exiting on SPEW_ABORT
ENV CPU_MHZ=2300

RUN groupadd -r steam && useradd -r -g steam -m -d /opt/steam steam

RUN apt-get -y update && apt-get install -y --no-install-recommends \
    ca-certificates=20230311 \
    curl=7.88.1-10+deb12u5 \
    lib32gcc-s1=12.2.0-14 \
    unzip=6.0-28 \
    xz-utils=5.4.1-0.2 \
    zip=3.0-13 \
    gcc-multilib=4:12.2.0-3 \
    g++-multilib=4:12.2.0-3 \
 && apt-get -y autoremove \
 && rm -rf /var/lib/apt/lists/*

USER steam
WORKDIR /opt/steam
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
COPY ./lib/hlds.install /opt/steam

RUN curl -sqL "$steamcmd_url" | tar xzvf - \
    && ./steamcmd.sh +runscript hlds.install

RUN curl -sLJO "$rehlds_url" \
    && unzip -o -j "rehlds-bin-$rehlds_build.zip" "bin/linux32/*" -d "/opt/steam/hlds" \
    && unzip -o -j "rehlds-bin-$rehlds_build.zip" "bin/linux32/valve/*" -d "/opt/steam/hlds"

# Fix error that steamclient.so is missing
RUN mkdir -p "$HOME/.steam" \
    && ln -s /opt/steam/linux32 "$HOME/.steam/sdk32"

# Fix warnings:
# couldn't exec listip.cfg
# couldn't exec banned.cfg
RUN touch /opt/steam/hlds/cstrike/listip.cfg
RUN touch /opt/steam/hlds/cstrike/banned.cfg

# Install Metamod-R
RUN mkdir -p /opt/steam/hlds/cstrike/addons/metamod \
    && touch /opt/steam/hlds/cstrike/addons/metamod/plugins.ini
RUN curl -sqL "$metamod_url" > tmp.zip
RUN unzip -j tmp.zip "addons/metamod/metamod*" -d /opt/steam/hlds/cstrike/addons/metamod
RUN chmod -R 755 /opt/steam/hlds/cstrike/addons/metamod
RUN sed -i 's/dlls\/cs\.so/addons\/metamod\/metamod_i386.so/g' /opt/steam/hlds/cstrike/liblist.gam

# Install AMX mod X
RUN curl -sqL "$amxmod_url" | tar -C /opt/steam/hlds/cstrike/ -zxvf - \
    && echo 'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' >> /opt/steam/hlds/cstrike/addons/metamod/plugins.ini
RUN cat /opt/steam/hlds/cstrike/mapcycle.txt >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/maps.ini

# Install ReGameDLL_CS
RUN curl -sLJO "$regamedll_url" \
 && unzip -o -j regamedll-bin-$regamedll_version.zip "bin/linux32/cstrike/*" -d "/opt/steam/hlds/cstrike" \
 && unzip -o -j regamedll-bin-$regamedll_version.zip "bin/linux32/cstrike/dlls/*" -d "/opt/steam/hlds/cstrike/dlls"

# Install ReAPI
RUN curl -sLJO "$reapi_url" \
 && unzip -o reapi-bin-$reapi_version.zip -d "/opt/steam/hlds/cstrike"
RUN echo 'reapi' >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/modules.ini

# Install bind_key
COPY lib/bind_key/amxx/bind_key.amxx /opt/steam/hlds/cstrike/addons/amxmodx/plugins/bind_key.amxx
RUN echo 'bind_key.amxx            ; binds keys for voting' >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/plugins.ini

WORKDIR /opt/steam/hlds

# Copy default config
COPY --chmod=0755 --chown=steam:steam cstrike cstrike

RUN chmod +x hlds_run hlds_linux

RUN echo 10 > steam_appid.txt

EXPOSE 27015
EXPOSE 27015/udp

# Start server
ENTRYPOINT ["./hlds_run", "-timeout 3", "-pingboost 1", "-game cstrike", "+map de_dust2"]
