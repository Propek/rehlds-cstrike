FROM --platform=$TARGETOS/$TARGETARCH debian:stable-slim
ENV DEBIAN_FRONTEND=noninteractive

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

# Cleanup
RUN apt-get -y autoremove && rm -rf /var/lib/apt/lists/*

RUN groupadd -r container && useradd -r -g container -m -d /home/container container

USER container
WORKDIR /home/container
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN mkdir /home/container/steamcmd
COPY ./lib/cs.install /home/container/steamcmd

RUN curl -sqL "$steamcmd_url" | tar xzvf - -C /home/container/steamcmd \
    && /home/container/steamcmd/steamcmd.sh +force_install_dir /home/container +runscript cs.install
RUN ls /home/container

# Metamod
RUN mkdir -p /home/container/cstrike/addons/metamod
RUN touch /home/container/cstrike/addons/metamod/plugins.ini
RUN curl -sqL "$metamod_url" -o metamod.zip
RUN if [ $? -ne 0 ]; then echo "ERROR: curl metamod failed!"; exit 1; fi
RUN ls -l metamod.zip
RUN unzip -o -j metamod.zip -d /home/container/cstrike/addons/metamod
RUN if [ $? -ne 0 ]; then echo "ERROR: unzip metamod failed!"; exit 1; fi
RUN chmod -R 755 /home/container/cstrike/addons/metamod
RUN sed -i 's/dlls\/cs\.so/addons\/metamod\/metamod_i386.so/g' /home/container/cstrike/liblist.gam

# AMX Mod X
RUN mkdir -p /home/container/cstrike/addons/amxmodx/configs
RUN mkdir -p /home/container/cstrike/addons/amxmodx/plugins
RUN mkdir -p /home/container/cstrike/addons/amxmodx/modules
RUN mkdir -p /home/container/cstrike/addons/amxmodx/scripting/include
RUN mkdir -p /home/container/cstrike/addons/amxmodx/scripting/testsuite
RUN mkdir -p /home/container/cstrike/addons/amxmodx/scripting/amxmod_compat
RUN mkdir -p /home/container/cstrike/addons/amxmodx/logs
RUN mkdir -p /home/container/cstrike/addons/amxmodx/data/lang
RUN mkdir -p /home/container/cstrike/addons/amxmodx/data
RUN mkdir -p /home/container/cstrike/addons/amxmodx/scripting
RUN curl -sqL "$amxmod_url" -o amxmodx.tar.gz
RUN if [ $? -ne 0 ]; then echo "ERROR: curl amxmodx failed!"; exit 1; fi
RUN ls -l amxmodx.tar.gz
RUN tar -C /home/container/cstrike/ -zxvf amxmodx.tar.gz
RUN if [ $? -ne 0 ]; then echo "ERROR: tar amxmodx failed!"; exit 1; fi
RUN echo 'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' >> /home/container/cstrike/addons/metamod/plugins.ini
RUN cat /home/container/cstrike/mapcycle.txt >> /home/container/cstrike/addons/amxmodx/configs/maps.ini

# ReGameDLL
RUN mkdir -p /home/container/cstrike/dlls
RUN curl -sLJO "$regamedll_url"
RUN if [ $? -ne 0 ]; then echo "ERROR: curl regamedll failed!"; exit 1; fi
RUN ls -l regamedll-bin-$regamedll_version.zip
RUN unzip -o -j regamedll-bin-$regamedll_version.zip "bin/linux32/cstrike/*" -d "/home/container/cstrike"
RUN if [ $? -ne 0 ]; then echo "ERROR: unzip regamedll cstrike failed!"; exit 1; fi
RUN unzip -o -j regamedll-bin-$regamedll_version.zip "bin/linux32/cstrike/dlls/*" -d "/home/container/cstrike/dlls"
RUN if [ $? -ne 0 ]; then echo "ERROR: unzip regamedll dlls failed!"; exit 1; fi

# ReAPI
RUN curl -sLJO "$reapi_url"
RUN if [ $? -ne 0 ]; then echo "ERROR: curl reapi failed!"; exit 1; fi
RUN ls -l reapi-bin-$reapi_version.zip
RUN unzip -o reapi-bin-$reapi_version.zip -d "/home/container/cstrike"
RUN if [ $? -ne 0 ]; then echo "ERROR: unzip reapi failed!"; exit 1; fi
RUN echo 'reapi' >> /home/container/cstrike/addons/amxmodx/configs/modules.ini

RUN mkdir -p "$HOME/.steam"
RUN ln -s /linux32 "$HOME/.steam/sdk32"

RUN touch /home/container/cstrike/listip.cfg
RUN touch /home/container/cstrike/banned.cfg

COPY lib/bind_key/amxx/bind_key.amxx /home/container/cstrike/addons/amxmodx/plugins/bind_key.amxx
RUN echo 'bind_key.amxx            ; binds keys for voting' >> /home/container/cstrike/addons/amxmodx/configs/plugins.ini

WORKDIR /home/container

COPY /cstrike /home/container/cstrike

#RUN chmod +x hlds_run hlds_linux

#RUN echo 10 > steam_appid.txt

EXPOSE 27015
EXPOSE 27015/udp

COPY ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
