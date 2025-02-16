FROM        --platform=$TARGETOS/$TARGETARCH debian:stable-slim
ENV         DEBIAN_FRONTEND=noninteractive

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

# Add architecture and update
RUN dpkg --add-architecture i386 && apt-get -y update

# Install packages (grouped logically)
RUN apt-get -y install --no-install-recommends \
        ca-certificates curl lib32gcc-s1 unzip xz-utils zip=3.0-13 \
        gcc-multilib g++-multilib tar gcc g++ libgcc1 \
        libcurl4-gnutls-dev:i386 lib32tinfo6 libtinfo6:i386 lib32z1 \
        lib32stdc++6 libncurses5:i386 libcurl3-gnutls:i386 libsdl2-2.0-0:i386 \
        iproute2 gdb libsdl1.2debian libfontconfig1 telnet \
        net-tools netcat-openbsd libssl-dev

RUN apt-get -y install --no-install-recommends libssl-dev:i386 # Install i386 libssl-dev separately

# Create user
#RUN useradd -m -d /home/container container

# Cleanup
RUN apt-get -y autoremove && rm -rf /var/lib/apt/lists/*

RUN groupadd -r steam && useradd -r -g steam -m -d /home/container steam

USER steam
WORKDIR /home/container
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
COPY ./lib/hlds.install /home/container

RUN curl -sqL "$steamcmd_url" | tar xzvf - \
    && ./steamcmd.sh +runscript hlds.install

RUN curl -sLJO "$rehlds_url" \
    && unzip -o -j "rehlds-bin-$rehlds_build.zip" "bin/linux32/*" -d "/home/container/" \
    && unzip -o -j "rehlds-bin-$rehlds_build.zip" "bin/linux32/valve/*" -d "/home/container"

RUN mkdir -p "$HOME/.steam" \
    && ln -s /linux32 "$HOME/.steam/sdk32"

#RUN find /home/container/Steam/steamapps/common/Half-Life -mindepth 1 -exec ln -s {} /home/container/ \;
RUN find /home/container/Steam/steamapps/common/Half-Life -mindepth 1 -exec sh -c ' \
  relpath="${1#/home/container/Steam/steamapps/common/Half-Life}"; \
  dest="/home/container$relpath"; \
  destdir=$(dirname "$dest"); \
  mkdir -p "$destdir"; \
  ln -s "$1" "$dest" \
' sh {} \;

RUN touch /home/container/cstrike/listip.cfg
RUN touch /home/container/cstrike/banned.cfg

RUN mkdir -p /home/container/cstrike/addons/metamod \
    && touch /home/container/cstrike/addons/metamod/plugins.ini
RUN curl -sqL "$metamod_url" > tmp.zip
RUN unzip -j tmp.zip "addons/metamod/metamod*" -d /home/container/cstrike/addons/metamod
RUN chmod -R 755 /home/container/cstrike/addons/metamod
RUN sed -i 's/dlls\/cs\.so/addons\/metamod\/metamod_i386.so/g' /home/container/cstrike/liblist.gam

RUN curl -sqL "$amxmod_url" | tar -C /home/container/cstrike/ -zxvf - \
    && echo 'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' >> /home/container/cstrike/addons/metamod/plugins.ini
RUN cat /home/container/cstrike/mapcycle.txt >> /home/container/cstrike/addons/amxmodx/configs/maps.ini

RUN curl -sLJO "$regamedll_url" \
    && unzip -o -j regamedll-bin-$regamedll_version.zip "bin/linux32/cstrike/*" -d "/home/container/cstrike" \
    && unzip -o -j regamedll-bin-$regamedll_version.zip "bin/linux32/cstrike/dlls/*" -d "/home/container/cstrike/dlls"

RUN curl -sLJO "$reapi_url" \
    && unzip -o reapi-bin-$reapi_version.zip -d "/home/container/cstrike"
RUN echo 'reapi' >> /home/container/cstrike/addons/amxmodx/configs/modules.ini

COPY lib/bind_key/amxx/bind_key.amxx /home/container/cstrike/addons/amxmodx/plugins/bind_key.amxx
RUN echo 'bind_key.amxx            ; binds keys for voting' >> /home/container/cstrike/addons/amxmodx/configs/plugins.ini

WORKDIR /home/container

COPY --chmod=0755 --chown=steam:steam cstrike cstrike

RUN chmod +x hlds_run hlds_linux

RUN echo 10 > steam_appid.txt

EXPOSE 27015
EXPOSE 27015/udp

#COPY --chown=steam:steam ./entrypoint.sh /home/container/entrypoint.sh
#COPY --chmod=0755 --chown=steam:steam ./entrypoint.sh /home/container/entrypoint.sh
COPY        ./entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]
