FROM --platform=$TARGETOS/$TARGETARCH debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.utf8
ENV LC_ALL=en_US.UTF-8
ENV CPU_MHZ=2300

ARG rehlds_build=3.13.0.788
ARG metamod_version=1.3.0.138
ARG amxmod_version=1.8.2
ARG regamedll_version=5.26.0.668
ARG reapi_version=5.24.0.300
ARG steamcmd_url="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
ARG rehlds_url="https://github.com/dreamstalker/rehlds/releases/download/$rehlds_build/rehlds-bin-$rehlds_build.zip"
ARG metamod_url="https://github.com/theAsmodai/metamod-r/releases/download/$metamod_version/metamod-bin-$metamod_version.zip"
ARG amxmod_url="http://www.amxmodx.org/release/amxmodx-$amxmod_version-base-linux.tar.gz"
ARG regamedll_url="https://github.com/s1lentq/ReGameDLL_CS/releases/download/$regamedll_version/regamedll-bin-$regamedll_version.zip"
ARG reapi_url="https://github.com/s1lentq/reapi/releases/download/$reapi_version/reapi-bin-$reapi_version.zip"

RUN dpkg --add-architecture i386 \
    && apt update \
    && apt upgrade -y \
    && apt install -y apt-utils tar curl gcc g++ lib32gcc-s1 libgcc1 libcurl4-gnutls-dev:i386 libssl-dev:i386 libcurl4:i386 lib32tinfo6 libtinfo6:i386 lib32z1 lib32stdc++6 libncurses5:i386 libcurl3-gnutls:i386 libsdl2-2.0-0:i386 iproute2 gdb libsdl1.2debian libfontconfig1 telnet net-tools netcat-openbsd unzip tzdata locales \
    && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

RUN groupadd -r steam && useradd -r -g steam -m -d  steam

USER steam
ENV USER=container HOME=
WORKDIR /home/container
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY ./lib/hlds.install 

RUN curl -sqL "$steamcmd_url" | tar xzvf - \
    && ./steamcmd.sh +runscript hlds.install

RUN curl -sLJO "$rehlds_url" \
    && unzip -o -j "rehlds-bin-$rehlds_build.zip" "bin/linux32/*" -d "" \
    && unzip -o -j "rehlds-bin-$rehlds_build.zip" "bin/linux32/valve/*" -d ""

RUN mkdir -p "$HOME/.steam" \
    && ln -s /linux32 "$HOME/.steam/sdk32"

RUN touch /cstrike/listip.cfg
RUN touch /cstrike/banned.cfg

RUN mkdir -p /cstrike/addons/metamod \
    && touch /cstrike/addons/metamod/plugins.ini
RUN curl -sqL "$metamod_url" > tmp.zip
RUN unzip -j tmp.zip "addons/metamod/metamod*" -d /cstrike/addons/metamod
RUN chmod -R 755 /cstrike/addons/metamod
RUN sed -i 's/dlls\/cs\.so/addons\/metamod\/metamod_i386.so/g' /cstrike/liblist.gam

RUN curl -sqL "$amxmod_url" | tar -C /cstrike/ -zxvf - \
    && echo 'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' >> /cstrike/addons/metamod/plugins.ini
RUN cat /cstrike/mapcycle.txt >> /cstrike/addons/amxmodx/configs/maps.ini

RUN curl -sLJO "$regamedll_url" \
    && unzip -o -j regamedll-bin-$regamedll_version.zip "bin/linux32/cstrike/*" -d "/cstrike" \
    && unzip -o -j regamedll-bin-$regamedll_version.zip "bin/linux32/cstrike/dlls/*" -d "/cstrike/dlls"

RUN curl -sLJO "$reapi_url" \
    && unzip -o reapi-bin-$reapi_version.zip -d "/cstrike"
RUN echo 'reapi' >> /cstrike/addons/amxmodx/configs/modules.ini

COPY lib/bind_key/amxx/bind_key.amxx /cstrike/addons/amxmodx/plugins/bind_key.amxx
RUN echo 'bind_key.amxx            ; binds keys for voting' >> /cstrike/addons/amxmodx/configs/plugins.ini

WORKDIR 

COPY --chmod=0755 --chown=steam:steam cstrike cstrike

RUN chmod +x hlds_run hlds_linux

RUN echo 10 > steam_appid.txt

EXPOSE 27015
EXPOSE 27015/udp

COPY ./entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
