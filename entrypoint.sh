#!/bin/bash

#
# Copyright (c) 2021 Matthew Penner
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# --- Variables ---------------------------------
REHLDS_VERSION="3.13.0.788"
METAMOD_VERSION="1.3.0.138"
AMXMOD_VERSION="1.10.0-git5467"
REGAMEDLL_VERSION="5.26.0.668"
REAPI_VERSION="5.24.0.300"

SERVER_DIR="/home/container"
STEAMCMD_DIR="${SERVER_DIR}/steamcmd"
CS_DIR="${SERVER_DIR}/cstrike"
ADDONS_DIR="${CS_DIR}/addons"
# -----------------------------------------------

# Give everything time to initialize for preventing SteamCMD deadlock
sleep 1

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

curl -sSL -o steamcmd.tar.gz http://media.steampowered.com/installer/steamcmd_linux.tar.gz

mkdir -p $SERVER_DIR/steamcmd
tar -xzvf steamcmd.tar.gz -C $SERVER_DIR/steamcmd
rm steamcmd.tar.gz

# Convert all of the "{{VARIABLE}}" parts of the command into the expected shell
# variable format of "${VARIABLE}" before evaluating the string and automatically
# replacing the values.
PARSED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")

## just in case someone removed the defaults.
if [ "${STEAM_USER}" == "" ]; then
    echo -e "steam user is not set.\n"
    echo -e "Using anonymous user.\n"
    STEAM_USER=anonymous
    STEAM_PASS=""
    STEAM_AUTH=""
else
    echo -e "user set to ${STEAM_USER}"
fi

## if auto_update is not set or to 1 update
if [ -z ${AUTO_UPDATE} ] || [ "${AUTO_UPDATE}" == "1" ]; then
    # Update Source Server
    if [ ! -z ${SRCDS_APPID} ]; then
        ./steamcmd/steamcmd.sh +force_install_dir /home/container +login ${STEAM_USER} ${STEAM_PASS} ${STEAM_AUTH} +app_update ${SRCDS_APPID} $( [[ -z ${SRCDS_BETAID} ]] || printf %s "-beta ${SRCDS_BETAID}" ) $( [[ -z ${SRCDS_BETAPASS} ]] || printf %s "-betapassword ${SRCDS_BETAPASS}" ) $( [[ -z ${HLDS_GAME} ]] || printf %s "+app_set_config 90 mod ${HLDS_GAME}" ) $( [[ -z ${VALIDATE} ]] || printf %s "validate" ) +quit
    else
        echo -e "No appid set. Starting Server"
    fi

else
    echo -e "Not updating game server as auto update was set to 0"
fi

echo -e " ### Installing mods ###"

# Install ReHLDS
REHLDS_URL="https://github.com/dreamstalker/rehlds/releases/download/${REHLDS_VERSION}/rehlds-bin-${REHLDS_VERSION}.zip"
wget -O rehlds-bin.zip "$REHLDS_URL"
unzip -o -j rehlds-bin.zip "bin/linux32/*" -d "$CS_DIR"
unzip -o -j rehlds-bin.zip "bin/linux32/valve/*" -d "$CS_DIR"
rm rehlds-bin.zip

# Install MetaMod
METAMOD_URL="https://github.com/theAsmodai/metamod-r/releases/download/${METAMOD_VERSION}/metamod-bin-${METAMOD_VERSION}.zip"
mkdir -p "${ADDONS_DIR}/metamod"
chmod 755 "${ADDONS_DIR}/metamod"
touch "${ADDONS_DIR}/metamod/plugins.ini"
wget -O metamod-bin.zip "$METAMOD_URL"
unzip -o -j metamod-bin.zip "addons/metamod/metamod*" -d "${ADDONS_DIR}/metamod"
rm metamod-bin.zip
sed -i 's/dlls\/cs\.so\/addons\/metamod\/metamod_i386.so/g' "$CS_DIR/liblist.gam"

# Install AMX Mod X
AMXMOD_URL="http://www.amxmodx.org/amxxdrop/1.10/amxmodx-${AMXMOD_VERSION}-base-linux.tar.gz"
wget -O amxmodx.tar.gz "$AMXMOD_URL"
tar -C "$CS_DIR" -zxvf amxmodx.tar.gz
rm amxmodx.tar.gz
echo 'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' >> "${ADDONS_DIR}/metamod/plugins.ini"
cat "$CS_DIR/mapcycle.txt" >> "$CS_DIR/addons/amxmodx/configs/maps.ini"

# Install ReGameDLL
REGAMEDLL_URL="https://github.com/s1lentq/ReGameDLL_CS/releases/download/${REGAMEDLL_VERSION}/regamedll-bin-${REGAMEDLL_VERSION}.zip"
wget -O regamedll.zip "$REGAMEDLL_URL"
unzip -o -j regamedll.zip "bin/linux32/cstrike/delta.lst" -d "$CS_DIR"
unzip -o -j ragemedll.zip "bin/linux32/cstrike/game.cfg" -d "$CS_DIR"
unzip -o -j ragemedll.zip "bin/linux32/cstrike/game_init.cfg" -d "$CS_DIR"
unzip -o -j regamedll.zip "bin/linux32/cstrike/dlls/*" -d "${CS_DIR}/dlls"
rm regamedll.zip

# Install ReAPI
REAPI_URL="https://github.com/s1lentq/reapi/releases/download/${REAPI_VERSION}/reapi-bin-${REAPI_VERSION}.zip"
wget -O reapi.zip "$REAPI_URL"
unzip -o reapi.zip -d "$CS_DIR"
rm reapi.zip

# Copy bind_key plugin (with check)
mkdir -p "${ADDONS_DIR}/amxmodx/plugins"
chmod 755 "${ADDONS_DIR}/amxmodx/plugins"

if [[ -f "bind_key.amxx" ]]; then
  cp "bind_key.amxx" "${ADDONS_DIR}/amxmodx/plugins/bind_key.amxx"
  echo 'bind_key.amxx                        ; binds keys for voting' >> "${ADDONS_DIR}/amxmodx/configs/plugins.ini"
else
  echo "Warning: bind_key.amxx not found in the script's directory."
fi

echo -e " ### Mods installed. Server should now start ###"

# Display the command we're running in the output, and then execute it with the env
# from the container itself.
printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n" "$PARSED"
# shellcheck disable=SC2086
exec env ${PARSED}
