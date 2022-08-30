rm -f ~/Downloads/poland-latest.osm.pbf
wget -c -O ~/Downloads/poland-latest.osm.pbf https://download.geofabrik.de/europe/poland-latest.osm.pbf
osm2pgsql -c -U postgres -W -d osmdb --slim --hstore-all --style ~/osm2pgsql/default.style --multi-geometry --merc ~/Downloads/poland-latest.osm.pbf
psql -U postgres -W -d osmdb -f ./sql/views.sql
rm -f ~/Downloads/poland-latest.osm.pbf
#

