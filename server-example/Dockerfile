FROM blsalin/rehlds-cstrike

COPY cstrike /opt/steam/hlds/cstrike 
RUN cat /opt/steam/hlds/cstrike/mapcycle.txt > /opt/steam/hlds/cstrike/addons/amxmodx/configs/maps.ini

ENTRYPOINT ["./hlds_run", "-timeout 3", "-pingboost 1", "-game cstrike", "+map de_dust2"]
