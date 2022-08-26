# bike_map_50
 
Bike map based on OSM data

Using the map since a while (the earliest print out I have found are dated 2017), so I thought it can be useful to others. It's mainly based on [OpenStreetMap](https://www.openstreetmap.org/) data (you can download it from [Geofabrik](https://download.geofabrik.de/)), uses postgres, postgis and QGIS. The main purpose of the map is to be printed as atlas on A4 paper sheets (you can find QGIS Atlas features in project as well).

For Poland, where I live, I'm using additional online WMS/WFS:
    
* raster relief data from [geoportal.gov.pl](https://www.geoportal.gov.pl/uslugi/usluga-przegladania-wms) as background

* vector boundary data for nature reserves, parks etc from [GDOŚ](https://sdi.gdos.gov.pl/wfs?request=GetCapabilities&service=WFS)
    

  * WMS raster with forest areas where you can stay overnight in the wilderness [Lasy Państwowe](https://www.bdl.lasy.gov.pl/portal/)

How it looks like you can see on the screenshot below.

<div style="text-align:center"><img src="./img/screenshot.png"/></div>


## Data preparation

To use the OSM data we will use `osm2pgsql`[^1] with a slighty adopted style (added in osm2pgsql folder):

    osm2pgsql -c -U postgres -W -d osmdb --slim --hstore-all --style ~/osm2pgsql/default.style --multi-geometry --merc ~/Downloads/poland-latest.osm.pbf

Then we have to run qsl script with views (stored in `sql/views.sql' file), which will be used in QGIS:

    psql -U postgres -W -d osmdb -f views.sql

[^1]: [osm2pgsql](https://osm2pgsql.org/) 

## Footnotes