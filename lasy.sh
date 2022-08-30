# mkdir -p lasy
# wget -O ./lasy/bialystok.gml  "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Bia%C5%82ystok_wydzielenia"
# wget -O ./lasy/gdansk.gml     "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Gdańsk_wydzieleni"
# wget -O ./lasy/katowice.gml   "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Katowice_wydzielenia"
# wget -O ./lasy/krakow.gml     "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Kraków_wydzielenia"
# wget -O ./lasy/krosno.gml     "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Krosno_wydzielenia"
# wget -O ./lasy/lublin.gml     "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Lublin_wydzielenia"
# wget -O ./lasy/olsztyn.gml    "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Olsztyn_wydzielenia"
# wget -O ./lasy/pila.gml       "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Piła_wydzielenia"
# wget -O ./lasy/poznan.gml     "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Poznań_wydzielenia"
# wget -O ./lasy/radom.gml      "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Radom_wydzielenia"
# wget -O ./lasy/szczecin.gml   "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Szczecin_wydzielenia"
# wget -O ./lasy/szczecinek.gml  "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Szczecinek_wydzielenia"
# wget -O ./lasy/torun.gml      "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Toruń_wydzielenia"
# wget -O ./lasy/warszawa.gml   "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Warszawa_wydzielenia"
# wget -O ./lasy/wroclaw.gml    "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Wrocław_wydzielenia"
# wget -O ./lasy/zg.gml         "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Zielona_Góra_wydzielenia"
# wget -O ./lasy/lodz.gml       "https://wfs.bdl.lasy.gov.pl/geoserver/BDL/ows?SERVICE=WFS&version=1.0.0&request=GetFeature&typeName=BDL:RDLP_Łódź_wydzielenia"
#
psql -U postgres -W -d osmdb -f ./sql/dlp_forests.sql
for file in ./lasy/*.gml; 
  do 
    echo $file;
    ogr2ogr -append -f "PostgreSQL" PG:"host=localhost port=5432 dbname=osmdb user=postgres password=" -nln public.dlp_forests $file; 
done;
psql -U postgres -W -d osmdb -f ./sql/views_forests.sql
