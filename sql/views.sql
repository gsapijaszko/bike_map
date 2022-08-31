-- FUNCTION: public.bikemap_findangle(geometry)

DROP FUNCTION IF EXISTS public.bikemap_findangle(geometry) CASCADE;

CREATE OR REPLACE FUNCTION public.bikemap_findangle(
	point geometry)
    RETURNS SETOF double precision 
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
    ROWS 1000

AS $BODY$
DECLARE
testPoint geometry;
myWay geometry;

Begin
testPoint := $1;
-- testPoint := (SELECT center FROM bikemap_railway_stations WHERE "name" = 'Pęgów');

myWay := (SELECT ST_Intersection(St_Buffer(cp, 10), way) FROM (
SELECT ST_ClosestPoint(way, testPoint) as cp, way 
	FROM (
		SELECT way FROM (
			SELECT st_distance(way, testPoint) AS distance, way
			FROM bikemap_railways
			ORDER BY distance ASC
			LIMIT 1
			) AS w
		) AS dupa
	) AS dupa1);

RETURN QUERY SELECT ST_Azimuth(ST_StartPoint(myWay), ST_EndPoint(myWay))/(2*pi())*360;
-- RETURN;
End;
$BODY$;

ALTER FUNCTION public.bikemap_findangle(geometry)
    OWNER TO postgres;


-- View: public.bikemap_bicycle_rest_areas

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_bicycle_rest_areas;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_bicycle_rest_areas
TABLESPACE pg_default
AS
 SELECT planet_osm_point.osm_id,
    planet_osm_point.name,
    planet_osm_point.way
   FROM planet_osm_point
  WHERE planet_osm_point.bicycle = 'designated'::text AND planet_osm_point.highway = 'rest_area'::text
UNION
 SELECT planet_osm_line.osm_id,
    planet_osm_line.name,
    st_centroid(planet_osm_line.way)::geometry(Point,3857) AS way
   FROM planet_osm_line
  WHERE planet_osm_line.bicycle = 'designated'::text AND planet_osm_line.highway = 'rest_area'::text
UNION
 SELECT planet_osm_polygon.osm_id,
    planet_osm_polygon.name,
    st_centroid(planet_osm_polygon.way)::geometry(Point,3857) AS way
   FROM planet_osm_polygon
  WHERE planet_osm_polygon.bicycle = 'designated'::text AND planet_osm_polygon.highway = 'rest_area'::text
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_bicycle_rest_areas
    OWNER TO postgres;


CREATE INDEX planet_bikemap_bicycle_rest_areas_way_idx
    ON public.bikemap_bicycle_rest_areas USING gist
    (way)
    TABLESPACE pg_default;
	
-- View: public.bikemap_bicycle_service_and_shop

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_bicycle_service_and_shop;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_bicycle_service_and_shop
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS id,
    bicycle_service.way::geometry(Point,3857) AS way,
    bicycle_service.type
   FROM ( SELECT st_centroid(unnest(st_clusterwithin(aaa.way, 1000::double precision))) AS way,
            aaa.type
           FROM ( SELECT planet_osm_point.way,
                        CASE
                            WHEN planet_osm_point.tags @> '"service:bicycle:repair"=>"yes"'::hstore AND planet_osm_point.shop = 'bicycle'::text THEN 'service'::character varying
                            WHEN planet_osm_point.amenity = 'bicycle_repair_station'::text THEN 'station'::character varying
                            WHEN planet_osm_point.shop = 'bicycle'::text THEN 'shop'::character varying
                            ELSE NULL::character varying
                        END AS type
                   FROM planet_osm_point
                  WHERE planet_osm_point.amenity = 'bicycle_repair_station'::text OR planet_osm_point.shop = 'bicycle'::text
                UNION
                 SELECT st_centroid(planet_osm_line.way) AS way,
                        CASE
                            WHEN planet_osm_line.tags @> '"service:bicycle:repair"=>"yes"'::hstore AND planet_osm_line.shop = 'bicycle'::text THEN 'service'::character varying
                            WHEN planet_osm_line.amenity = 'bicycle_repair_station'::text THEN 'station'::character varying
                            WHEN planet_osm_line.shop = 'bicycle'::text THEN 'shop'::character varying
                            ELSE NULL::character varying
                        END AS type
                   FROM planet_osm_line
                  WHERE planet_osm_line.amenity = 'bicycle_repair_station'::text OR planet_osm_line.shop = 'bicycle'::text
                UNION
                 SELECT st_centroid(planet_osm_polygon.way) AS way,
                        CASE
                            WHEN planet_osm_polygon.tags @> '"service:bicycle:repair"=>"yes"'::hstore AND planet_osm_polygon.shop = 'bicycle'::text THEN 'service'::character varying
                            WHEN planet_osm_polygon.amenity = 'bicycle_repair_station'::text THEN 'station'::character varying
                            WHEN planet_osm_polygon.shop = 'bicycle'::text THEN 'shop'::character varying
                            ELSE NULL::character varying
                        END AS type
                   FROM planet_osm_polygon
                  WHERE planet_osm_polygon.amenity = 'bicycle_repair_station'::text OR planet_osm_polygon.shop = 'bicycle'::text) aaa
          GROUP BY aaa.type) bicycle_service
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_bicycle_service_and_shop
    OWNER TO postgres;


CREATE INDEX bikemap_bicycle_service_and_shop_type
    ON public.bikemap_bicycle_service_and_shop USING btree
    (type COLLATE pg_catalog."default")
    TABLESPACE pg_default;
CREATE INDEX bikemap_bicycle_service_and_shop_way_idx
    ON public.bikemap_bicycle_service_and_shop USING gist
    (way)
    TABLESPACE pg_default;
	
-- View: public.bikemap_embankments_cuttings

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_embankments_cuttings;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_embankments_cuttings
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS myid,
    embankments.type,
    embankments.way
   FROM ( SELECT DISTINCT planet_osm_line.way,
                CASE
                    WHEN (planet_osm_line.man_made = ANY (ARRAY['embankment'::text, 'dyke'::text])) AND planet_osm_line.highway IS NULL THEN 'embankment'::text
                    WHEN planet_osm_line.embankment = 'yes'::text AND planet_osm_line.highway IS NOT NULL THEN 'emb_highway'::text
                    WHEN planet_osm_line.cutting = 'yes'::text THEN 'cutting'::text
                    ELSE NULL::text
                END AS type
           FROM planet_osm_line
          WHERE (planet_osm_line.man_made = ANY (ARRAY['embankment'::text, 'dyke'::text])) OR planet_osm_line.embankment = 'yes'::text OR planet_osm_line.cutting = 'yes'::text) embankments
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_embankments_cuttings
    OWNER TO postgres;


CREATE INDEX bikemap_embankments_idx
    ON public.bikemap_embankments_cuttings USING btree
    (type COLLATE pg_catalog."default")
    TABLESPACE pg_default;
CREATE INDEX bikemap_embankments_way_idx
    ON public.bikemap_embankments_cuttings USING gist
    (way)
    TABLESPACE pg_default;
	
-- View: public.bikemap_ferries

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_ferries;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_ferries
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS myid,
    ferries.route,
    ferries.way
   FROM ( SELECT DISTINCT planet_osm_line.way,
            planet_osm_line.route
           FROM planet_osm_line
          WHERE planet_osm_line.route = 'ferry'::text) ferries
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_ferries
    OWNER TO postgres;


CREATE INDEX bikemap_ferries_way_idx
    ON public.bikemap_ferries USING gist
    (way)
    TABLESPACE pg_default;
	
-- View: public.bikemap_highways

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_highways;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_highways
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS id,
    highways.ref,
    highways.highway,
    highways.tracktype,
    highways.geom::geometry(MultiLineString,3857) AS geom,
    st_length(highways.geom::geometry(MultiLineString,3857)) AS length
   FROM ( SELECT planet_osm_line.ref,
            planet_osm_line.highway,
            planet_osm_line.tracktype,
            st_multi(st_union(planet_osm_line.way)) AS geom
           FROM planet_osm_line
          WHERE planet_osm_line.highway IS NOT NULL AND planet_osm_line.ref IS NOT NULL
          GROUP BY planet_osm_line.highway, planet_osm_line.ref, planet_osm_line.tracktype
        UNION
         SELECT ''::text AS ref,
            planet_osm_line.highway,
            planet_osm_line.tracktype,
            st_multi(planet_osm_line.way) AS geom
           FROM planet_osm_line
          WHERE planet_osm_line.highway IS NOT NULL AND planet_osm_line.ref IS NULL) highways
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_highways
    OWNER TO postgres;


CREATE INDEX bikemap_highways_geom_idx
    ON public.bikemap_highways USING gist
    (geom)
    TABLESPACE pg_default;
CREATE INDEX bikemap_highways_highway_tracktype_idx
    ON public.bikemap_highways USING btree
    (highway COLLATE pg_catalog."default", tracktype COLLATE pg_catalog."default")
    TABLESPACE pg_default;
	
-- View: public.bikemap_hotels

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_hotels;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_hotels
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS id,
    hotels.myway::geometry(Point,3857) AS way,
    hotels.tourism,
    hotels.name,
    hotels.address,
    hotels.email,
    hotels.phone
   FROM ( WITH table1 AS (
                 SELECT st_centroid(unnest(st_clusterwithin(aaa.way, 1000::double precision))) AS myway,
                    aaa.tourism
                   FROM ( SELECT planet_osm_point.tourism,
                            planet_osm_point.way
                           FROM planet_osm_point
                          WHERE planet_osm_point.tourism = ANY (ARRAY['camp_site'::text, 'hostel'::text, 'apartment'::text, 'guest_house'::text, 'chalet'::text, 'alpine_hut'::text, 'caravan_site'::text, 'hotel'::text, 'motel'::text])
                        UNION
                         SELECT planet_osm_line.tourism,
                            st_centroid(planet_osm_line.way) AS way
                           FROM planet_osm_line
                          WHERE planet_osm_line.tourism = ANY (ARRAY['camp_site'::text, 'hostel'::text, 'apartment'::text, 'guest_house'::text, 'chalet'::text, 'alpine_hut'::text, 'caravan_site'::text, 'hotel'::text, 'motel'::text])
                        UNION
                         SELECT planet_osm_polygon.tourism,
                            st_centroid(planet_osm_polygon.way) AS way
                           FROM planet_osm_polygon
                          WHERE planet_osm_polygon.tourism = ANY (ARRAY['camp_site'::text, 'hostel'::text, 'apartment'::text, 'guest_house'::text, 'chalet'::text, 'alpine_hut'::text, 'caravan_site'::text, 'hotel'::text, 'motel'::text])) aaa
                  GROUP BY aaa.tourism
                ), table2 AS (
                 SELECT planet_osm_point.way,
                    planet_osm_point.name,
                    concat(planet_osm_point.tags -> 'addr:street'::text, ' ', planet_osm_point.tags -> 'addr:housenumber'::text, ', ', planet_osm_point.tags -> 'addr:city'::text) AS address,
                    planet_osm_point.tags -> 'contact:email'::text AS email,
                    planet_osm_point.tags -> 'contact:phone'::text AS phone
                   FROM planet_osm_point
                  WHERE planet_osm_point.tourism = ANY (ARRAY['camp_site'::text, 'hostel'::text, 'apartment'::text, 'guest_house'::text, 'chalet'::text, 'alpine_hut'::text, 'caravan_site'::text, 'hotel'::text, 'motel'::text])
                UNION
                 SELECT st_centroid(planet_osm_line.way) AS way,
                    planet_osm_line.name,
                    concat(planet_osm_line.tags -> 'addr:street'::text, ' ', planet_osm_line.tags -> 'addr:housenumber'::text, ', ', planet_osm_line.tags -> 'addr:city'::text) AS address,
                    planet_osm_line.tags -> 'contact:email'::text AS email,
                    planet_osm_line.tags -> 'contact:phone'::text AS phone
                   FROM planet_osm_line
                  WHERE planet_osm_line.tourism = ANY (ARRAY['camp_site'::text, 'hostel'::text, 'apartment'::text, 'guest_house'::text, 'chalet'::text, 'alpine_hut'::text, 'caravan_site'::text, 'hotel'::text, 'motel'::text])
                UNION
                 SELECT st_centroid(planet_osm_polygon.way) AS way,
                    planet_osm_polygon.name,
                    concat(planet_osm_polygon.tags -> 'addr:street'::text, ' ', planet_osm_polygon.tags -> 'addr:housenumber'::text, ', ', planet_osm_polygon.tags -> 'addr:city'::text) AS address,
                    planet_osm_polygon.tags -> 'contact:email'::text AS email,
                    planet_osm_polygon.tags -> 'contact:phone'::text AS phone
                   FROM planet_osm_polygon
                  WHERE planet_osm_polygon.tourism = ANY (ARRAY['camp_site'::text, 'hostel'::text, 'apartment'::text, 'guest_house'::text, 'chalet'::text, 'alpine_hut'::text, 'caravan_site'::text, 'hotel'::text, 'motel'::text])
                )
         SELECT table1.myway,
            table1.tourism,
            table2.way,
            table2.name,
            table2.address,
            table2.email,
            table2.phone
           FROM table1
             LEFT JOIN table2 ON st_intersects(table1.myway, table2.way)) hotels
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_hotels
    OWNER TO postgres;


CREATE INDEX bikemap_hotels_tourism_idx
    ON public.bikemap_hotels USING btree
    (tourism COLLATE pg_catalog."default")
    TABLESPACE pg_default;
CREATE INDEX bikemap_hotels_way_idx
    ON public.bikemap_hotels USING gist
    (way)
    TABLESPACE pg_default;
	
-- View: public.bikemap_landuse

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_landuse;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_landuse
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS myid,
    lands.landuse,
    lands.name,
    lands.way
   FROM ( SELECT DISTINCT planet_osm_polygon.way,
            'forest'::text AS landuse,
            planet_osm_polygon.name
           FROM planet_osm_polygon
          WHERE planet_osm_polygon.landuse = 'forest'::text OR planet_osm_polygon."natural" = 'wood'::text
        UNION
         SELECT DISTINCT planet_osm_polygon.way,
            'shrubs'::text AS landuse,
            planet_osm_polygon.name
           FROM planet_osm_polygon
          WHERE planet_osm_polygon."natural" = ANY (ARRAY['scrub'::text, 'shrubbery'::text])
        UNION
         SELECT DISTINCT planet_osm_polygon.way,
            'park'::text AS landuse,
            planet_osm_polygon.name
           FROM planet_osm_polygon
          WHERE (planet_osm_polygon.landuse = ANY (ARRAY['park'::text, 'village_green'::text])) OR (planet_osm_polygon.leisure = ANY (ARRAY['park'::text, 'garden'::text]))
        UNION
         SELECT DISTINCT planet_osm_polygon.way,
            'farmland'::text AS landuse,
            planet_osm_polygon.name
           FROM planet_osm_polygon
          WHERE planet_osm_polygon.landuse = ANY (ARRAY['farmland'::text, 'farmyard'::text, 'allotments'::text])
        UNION
         SELECT DISTINCT planet_osm_polygon.way,
            'meadow'::text AS landuse,
            planet_osm_polygon.name
           FROM planet_osm_polygon
          WHERE planet_osm_polygon.landuse = ANY (ARRAY['meadow'::text, 'grassland'::text])
        UNION
         SELECT DISTINCT planet_osm_polygon.way,
            'cemetery'::text AS landuse,
            planet_osm_polygon.name
           FROM planet_osm_polygon
          WHERE (planet_osm_polygon.landuse = ANY (ARRAY['cemetery'::text, 'grave_yard'::text])) OR (planet_osm_polygon.amenity = ANY (ARRAY['cemetery'::text, 'grave_yard'::text]))) lands
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_landuse
    OWNER TO postgres;


CREATE INDEX bikemap_landuse_landuse_idx
    ON public.bikemap_landuse USING btree
    (landuse COLLATE pg_catalog."default")
    TABLESPACE pg_default;
CREATE INDEX bikemap_landuse_way_idx
    ON public.bikemap_landuse USING gist
    (way)
    TABLESPACE pg_default;
	

-- View: public.bikemap_man_made

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_man_made;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_man_made
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS id,
    man_made.man_made,
    man_made.tower_type,
    man_made.drinking_water,
    man_made.wikipedia,
    man_made.center::geometry(Point,3857) AS center
   FROM ( SELECT st_centroid(planet_osm_polygon.way) AS center,
            planet_osm_polygon.man_made,
            planet_osm_polygon.tags -> 'tower:type'::text AS tower_type,
            planet_osm_polygon.tags -> 'drinking_water'::text AS drinking_water,
            planet_osm_polygon.tags -> 'wikipedia'::text AS wikipedia
           FROM planet_osm_polygon
          WHERE planet_osm_polygon.man_made = ANY (ARRAY['lighthouse'::text, 'water_tower'::text, 'watermill'::text, 'windmill'::text, 'mast'::text, 'tower'::text, 'water_well'::text])
        UNION
         SELECT st_centroid(planet_osm_line.way) AS center,
            planet_osm_line.man_made,
            planet_osm_line.tags -> 'tower:type'::text AS tower_type,
            planet_osm_line.tags -> 'drinking_water'::text AS drinking_water,
            planet_osm_line.tags -> 'wikipedia'::text AS wikipedia
           FROM planet_osm_line
          WHERE planet_osm_line.man_made = ANY (ARRAY['lighthouse'::text, 'water_tower'::text, 'watermill'::text, 'windmill'::text, 'mast'::text, 'tower'::text, 'water_well'::text])
        UNION
         SELECT planet_osm_point.way AS center,
            planet_osm_point.man_made,
            planet_osm_point.tags -> 'tower:type'::text AS tower_type,
            planet_osm_point.tags -> 'drinking_water'::text AS drinking_water,
            planet_osm_point.tags -> 'wikipedia'::text AS wikipedia
           FROM planet_osm_point
          WHERE planet_osm_point.man_made = ANY (ARRAY['lighthouse'::text, 'water_tower'::text, 'watermill'::text, 'windmill'::text, 'mast'::text, 'tower'::text, 'water_well'::text])) man_made
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_man_made
    OWNER TO postgres;


CREATE INDEX bikemap_man_made_center_idx
    ON public.bikemap_man_made USING gist
    (center)
    TABLESPACE pg_default;
	
-- View: public.bikemap_places

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_places;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_places
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS myid,
    places.place,
    places.name,
    places.way
   FROM ( SELECT DISTINCT planet_osm_point.way,
            planet_osm_point.place,
            planet_osm_point.name
           FROM planet_osm_point
          WHERE planet_osm_point.place = ANY (ARRAY['city'::text, 'town'::text, 'village'::text, 'hamlet'::text, 'isolated_dwelling'::text])) places
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_places
    OWNER TO postgres;


CREATE INDEX bikemap_places_idx
    ON public.bikemap_places USING btree
    (place COLLATE pg_catalog."default")
    TABLESPACE pg_default;
CREATE INDEX bikemap_places_way_idx
    ON public.bikemap_places USING gist
    (way)
    TABLESPACE pg_default;

-- View: public.bikemap_railways

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_railways;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_railways
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS myid,
    railways.railway,
    railways.way
   FROM ( SELECT DISTINCT planet_osm_line.way,
            planet_osm_line.railway
           FROM planet_osm_line
          WHERE (planet_osm_line.railway = ANY (ARRAY['rail'::text, 'yes'::text, 'narrow_gauge'::text, 'disused'::text])) AND planet_osm_line.service IS NULL) railways
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_railways
    OWNER TO postgres;


CREATE INDEX bikemap_railways_railway_idx
    ON public.bikemap_railways USING btree
    (railway COLLATE pg_catalog."default")
    TABLESPACE pg_default;
CREATE INDEX bikemap_railways_way_idx
    ON public.bikemap_railways USING gist
    (way)
    TABLESPACE pg_default;


-- View: public.bikemap_railway_stations

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_railway_stations;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_railway_stations
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS id,
    railway_stations.center,
    bikemap_findangle(railway_stations.center) AS station_angle,
    railway_stations.name,
    railway_stations.railway
   FROM ( SELECT st_centroid(planet_osm_point.way)::geometry(Point,3857) AS center,
            planet_osm_point.name,
            planet_osm_point.railway
           FROM planet_osm_point
          WHERE planet_osm_point.railway = ANY (ARRAY['station'::text, 'stop'::text, 'halt'::text])
        UNION
         SELECT st_centroid(planet_osm_line.way)::geometry(Point,3857) AS center,
            planet_osm_line.name,
            planet_osm_line.railway
           FROM planet_osm_line
          WHERE planet_osm_line.railway = ANY (ARRAY['station'::text, 'stop'::text, 'halt'::text])
        UNION
         SELECT st_centroid(planet_osm_polygon.way)::geometry(Point,3857) AS center,
            planet_osm_polygon.name,
            planet_osm_polygon.railway
           FROM planet_osm_polygon
          WHERE planet_osm_polygon.railway = ANY (ARRAY['station'::text, 'stop'::text, 'halt'::text])) railway_stations
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_railway_stations
    OWNER TO postgres;


CREATE INDEX planet_osm_railway_stations_center_idx
    ON public.bikemap_railway_stations USING gist
    (center)
    TABLESPACE pg_default;


-- View: public.bikemap_resind

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_resind;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_resind
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS myid,
    resind.landuse,
    resind.way
   FROM ( SELECT DISTINCT planet_osm_polygon.way,
            'industrial'::text AS landuse
           FROM planet_osm_polygon
          WHERE planet_osm_polygon.landuse = 'industrial'::text OR planet_osm_polygon.aeroway IS NOT NULL
        UNION
         SELECT DISTINCT planet_osm_polygon.way,
            'residential'::text AS landuse
           FROM planet_osm_polygon
          WHERE planet_osm_polygon.landuse = 'residential'::text
        UNION
         SELECT DISTINCT planet_osm_polygon.way,
            'military'::text AS landuse
           FROM planet_osm_polygon
          WHERE planet_osm_polygon.landuse = 'military'::text OR planet_osm_polygon.military IS NOT NULL) resind
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_resind
    OWNER TO postgres;


CREATE INDEX bikemap_resind_landuse_idx
    ON public.bikemap_resind USING btree
    (landuse COLLATE pg_catalog."default")
    TABLESPACE pg_default;
CREATE INDEX bikemap_resind_way_idx
    ON public.bikemap_resind USING gist
    (way)
    TABLESPACE pg_default;
	
-- View: public.bikemap_routes

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_routes;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_routes
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS myid,
    routes.route,
    routes.route_name,
    routes.colour,
    routes.way
   FROM ( SELECT DISTINCT planet_osm_line.way,
                CASE
                    WHEN (planet_osm_line.route = ANY (ARRAY['hiking'::text, 'foot'::text])) OR (planet_osm_line.network = ANY (ARRAY['iwn'::text, 'nwn'::text, 'rwn'::text, 'lwn'::text])) THEN 'hiking'::text
                    WHEN (planet_osm_line.route = ANY (ARRAY['bicycle'::text, 'mtb'::text])) OR (planet_osm_line.network = ANY (ARRAY['icn'::text, 'ncn'::text, 'rcn'::text, 'lcn'::text])) THEN 'bicycle'::text
                    ELSE NULL::text
                END AS route,
                CASE
                    WHEN (planet_osm_line.colour = ANY (ARRAY['red'::text, 'Red'::text, '#FF0000'::text])) OR planet_osm_line."osmc:symbol" ~~ 'red%'::text THEN 'red'::text
                    WHEN (planet_osm_line.colour = ANY (ARRAY['green'::text, 'Green'::text, '#00FF00'::text])) OR planet_osm_line."osmc:symbol" ~~ 'green%'::text THEN 'green'::text
                    WHEN (planet_osm_line.colour = ANY (ARRAY['blue'::text, 'Blue'::text, '#0000FF'::text])) OR planet_osm_line."osmc:symbol" ~~ 'blue%'::text THEN 'blue'::text
                    WHEN (planet_osm_line.colour = ANY (ARRAY['yellow'::text, 'Yellow'::text, '#FFFF00'::text])) OR planet_osm_line."osmc:symbol" ~~ 'yellow%'::text THEN 'yellow'::text
                    WHEN planet_osm_line.colour = ANY (ARRAY['orange'::text, 'Orange'::text, '#FF8000'::text]) THEN 'orange'::text
                    WHEN (planet_osm_line.colour = ANY (ARRAY['black'::text, 'Black'::text, '#000000'::text])) OR planet_osm_line.colour IS NULL OR planet_osm_line."osmc:symbol" ~~ 'black%'::text THEN 'black'::text
                    ELSE planet_osm_line.colour
                END AS colour,
            planet_osm_line.route_name
           FROM planet_osm_line
          WHERE (planet_osm_line.route = ANY (ARRAY['hiking'::text, 'foot'::text, 'bicycle'::text, 'mtb'::text])) OR (planet_osm_line.network = ANY (ARRAY['iwn'::text, 'nwn'::text, 'rwn'::text, 'lwn'::text, 'icn'::text, 'ncn'::text, 'rcn'::text, 'lcn'::text]))) routes
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_routes
    OWNER TO postgres;


CREATE INDEX bikemap_routes_way_idx
    ON public.bikemap_routes USING gist
    (way)
    TABLESPACE pg_default;
	
-- View: public.bikemap_routes_surface

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_routes_surface;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_routes_surface
TABLESPACE pg_default
AS
 SELECT DISTINCT planet_osm_line.osm_id,
    planet_osm_line.surface,
    planet_osm_line.way
   FROM planet_osm_line
  WHERE (planet_osm_line.osm_id IN ( SELECT btrim("substring"(ala.members, 2, 20))::bigint AS way_id
           FROM ( SELECT unnest(planet_osm_rels.members) AS members
                   FROM planet_osm_rels
                  WHERE (planet_osm_rels.id IN ( SELECT abs(planet_osm_line_1.osm_id) AS abs
                           FROM planet_osm_line planet_osm_line_1
                          WHERE planet_osm_line_1.network = ANY (ARRAY['ncn'::text, 'rcn'::text, 'lcn'::text, 'icn'::text, 'nwn'::text, 'rwn'::text, 'lwn'::text, 'iwn'::text])))) ala
          WHERE ala.members !~~ 'we%'::text AND ala.members ~~ 'w%'::text AND btrim("substring"(ala.members, 2, 20)) <> 'an'::text))
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_routes_surface
    OWNER TO postgres;


CREATE INDEX bikemap_routes_surface_way_idx
    ON public.bikemap_routes_surface USING gist
    (way)
    TABLESPACE pg_default;
	
-- View: public.bikemap_shelters

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_shelters;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_shelters
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS id,
    shelters.way::geometry(Point,3857) AS way,
    shelters.type
   FROM ( SELECT st_centroid(unnest(st_clusterwithin(aaa.way, 1000::double precision))) AS way,
            aaa.type
           FROM ( SELECT planet_osm_point.way,
                        CASE
                            WHEN planet_osm_point.leisure = 'firepit'::text THEN 'firepit'::text
                            WHEN planet_osm_point.amenity = 'bicycle_parking'::text THEN 'bicycle_parking'::text
                            WHEN planet_osm_point.amenity = 'shelter'::text OR planet_osm_point.highway = 'bus_stop'::text AND planet_osm_point.tags @> '"shelter"=>"yes"'::hstore THEN 'shelter'::text
                            WHEN planet_osm_point.tourism = 'picnic_site'::text THEN 'picnic_site'::text
                            ELSE NULL::text
                        END AS type
                   FROM planet_osm_point
                  WHERE planet_osm_point.leisure = 'firepit'::text OR (planet_osm_point.amenity = ANY (ARRAY['bicycle_parking'::text, 'shelter'::text])) OR (planet_osm_point.tourism = ANY (ARRAY['alpine_hut'::text, 'picnic_site'::text])) OR planet_osm_point.highway = 'bus_stop'::text
                UNION
                 SELECT st_centroid(planet_osm_line.way) AS way,
                        CASE
                            WHEN planet_osm_line.leisure = 'firepit'::text THEN 'firepit'::text
                            WHEN planet_osm_line.amenity = 'bicycle_parking'::text THEN 'bicycle_parking'::text
                            WHEN planet_osm_line.amenity = 'shelter'::text OR planet_osm_line.highway = 'bus_stop'::text AND planet_osm_line.tags @> '"shelter"=>"yes"'::hstore THEN 'shelter'::text
                            WHEN planet_osm_line.tourism = 'picnic_site'::text THEN 'picnic_site'::text
                            ELSE NULL::text
                        END AS type
                   FROM planet_osm_line
                  WHERE planet_osm_line.leisure = 'firepit'::text OR (planet_osm_line.amenity = ANY (ARRAY['bicycle_parking'::text, 'shelter'::text])) OR (planet_osm_line.tourism = ANY (ARRAY['alpine_hut'::text, 'picnic_site'::text])) OR planet_osm_line.highway = 'bus_stop'::text
                UNION
                 SELECT st_centroid(planet_osm_polygon.way) AS way,
                        CASE
                            WHEN planet_osm_polygon.leisure = 'firepit'::text THEN 'firepit'::text
                            WHEN planet_osm_polygon.amenity = 'bicycle_parking'::text THEN 'bicycle_parking'::text
                            WHEN planet_osm_polygon.amenity = 'shelter'::text OR planet_osm_polygon.highway = 'bus_stop'::text AND planet_osm_polygon.tags @> '"shelter"=>"yes"'::hstore THEN 'shelter'::text
                            WHEN planet_osm_polygon.tourism = 'picnic_site'::text THEN 'picnic_site'::text
                            ELSE NULL::text
                        END AS type
                   FROM planet_osm_polygon
                  WHERE planet_osm_polygon.leisure = 'firepit'::text OR (planet_osm_polygon.amenity = ANY (ARRAY['bicycle_parking'::text, 'shelter'::text])) OR (planet_osm_polygon.tourism = ANY (ARRAY['alpine_hut'::text, 'picnic_site'::text])) OR planet_osm_polygon.highway = 'bus_stop'::text) aaa
          GROUP BY aaa.type) shelters
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_shelters
    OWNER TO postgres;


CREATE INDEX bikemap_shelters_type
    ON public.bikemap_shelters USING btree
    (type COLLATE pg_catalog."default")
    TABLESPACE pg_default;
CREATE INDEX bikemap_shelters_way_idx
    ON public.bikemap_shelters USING gist
    (way)
    TABLESPACE pg_default;
	
-- View: public.bikemap_shops

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_shops;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_shops
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS id,
    shops.center::geometry(Point,3857) AS center,
    shops.shop
   FROM ( SELECT st_centroid(unnest(st_clusterwithin(aaa.way, 3000::double precision))) AS center,
            aaa.shop
           FROM ( SELECT planet_osm_point.way,
                    planet_osm_point.shop
                   FROM planet_osm_point
                  WHERE planet_osm_point.shop = ANY (ARRAY['bakery'::text, 'convenience'::text, 'deli'::text, 'departament_store'::text, 'supermarket'::text])
                UNION
                 SELECT st_centroid(planet_osm_line.way) AS st_centroid,
                    planet_osm_line.shop
                   FROM planet_osm_line
                  WHERE planet_osm_line.shop = ANY (ARRAY['bakery'::text, 'convenience'::text, 'deli'::text, 'departament_store'::text, 'supermarket'::text])
                UNION
                 SELECT st_centroid(planet_osm_polygon.way) AS st_centroid,
                    planet_osm_polygon.shop
                   FROM planet_osm_polygon
                  WHERE planet_osm_polygon.shop = ANY (ARRAY['bakery'::text, 'convenience'::text, 'deli'::text, 'departament_store'::text, 'supermarket'::text])) aaa
          GROUP BY aaa.shop) shops
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_shops
    OWNER TO postgres;


CREATE INDEX bikemap_shops_center_idx
    ON public.bikemap_shops USING gist
    (center)
    TABLESPACE pg_default;
CREATE INDEX bikemap_shops_shop
    ON public.bikemap_shops USING btree
    (shop COLLATE pg_catalog."default")
    TABLESPACE pg_default;

-- View: public.bikemap_tourism

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_tourism;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_tourism
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS id,
    tourism.tourism,
    tourism.name,
    tourism.center
   FROM ( SELECT st_centroid(planet_osm_polygon.way) AS center,
                CASE
                    WHEN planet_osm_polygon.tourism = 'viewpoint'::text THEN 'viewpoint'::text
                    WHEN planet_osm_polygon.tourism = ANY (ARRAY['museum'::text, 'gallery'::text]) THEN 'museum'::text
                    WHEN planet_osm_polygon.tourism = 'attraction'::text AND planet_osm_polygon.historic IS NULL THEN 'attraction'::text
                    WHEN planet_osm_polygon.historic = 'ruins'::text THEN 'ruins'::text
                    WHEN planet_osm_polygon.historic = 'archaeological_site'::text THEN 'archaeological_site'::text
                    WHEN planet_osm_polygon.historic = 'battlefield'::text THEN 'battlefield'::text
                    WHEN planet_osm_polygon.historic = 'wayside_cross'::text THEN 'wayside_cross'::text
                    WHEN planet_osm_polygon.historic = ANY (ARRAY['castle'::text, 'fortification'::text, 'fort'::text]) THEN 'castle'::text
                    WHEN (planet_osm_polygon.historic = ANY (ARRAY['manor'::text, 'palace'::text, 'heritage'::text])) OR (planet_osm_polygon.tags -> 'manor'::text) <> ''::text THEN 'manor'::text
                    WHEN (planet_osm_polygon.historic = ANY (ARRAY['memorial'::text, 'monument'::text])) OR (planet_osm_polygon.tags -> 'monument'::text) = 'yes'::text THEN 'monument'::text
                    WHEN planet_osm_polygon.historic = 'church'::text THEN 'church'::text
                    ELSE NULL::text
                END AS tourism,
            planet_osm_polygon.name
           FROM planet_osm_polygon
          WHERE planet_osm_polygon.tourism <> ''::text OR planet_osm_polygon.historic <> ''::text
        UNION
         SELECT st_centroid(planet_osm_line.way) AS center,
                CASE
                    WHEN planet_osm_line.tourism = 'viewpoint'::text THEN 'viewpoint'::text
                    WHEN planet_osm_line.tourism = ANY (ARRAY['museum'::text, 'gallery'::text]) THEN 'museum'::text
                    WHEN planet_osm_line.tourism = 'attraction'::text AND planet_osm_line.historic IS NULL THEN 'attraction'::text
                    WHEN planet_osm_line.historic = 'ruins'::text THEN 'ruins'::text
                    WHEN planet_osm_line.historic = 'archaeological_site'::text THEN 'archaeological_site'::text
                    WHEN planet_osm_line.historic = 'battlefield'::text THEN 'battlefield'::text
                    WHEN planet_osm_line.historic = 'wayside_cross'::text THEN 'wayside_cross'::text
                    WHEN planet_osm_line.historic = ANY (ARRAY['castle'::text, 'fortification'::text, 'fort'::text]) THEN 'castle'::text
                    WHEN (planet_osm_line.historic = ANY (ARRAY['manor'::text, 'palace'::text, 'heritage'::text])) OR (planet_osm_line.tags -> 'manor'::text) <> ''::text THEN 'manor'::text
                    WHEN (planet_osm_line.historic = ANY (ARRAY['memorial'::text, 'monument'::text])) OR (planet_osm_line.tags -> 'monument'::text) = 'yes'::text THEN 'monument'::text
                    WHEN planet_osm_line.historic = 'church'::text THEN 'church'::text
                    ELSE NULL::text
                END AS tourism,
            planet_osm_line.name
           FROM planet_osm_line
          WHERE planet_osm_line.tourism <> ''::text OR planet_osm_line.historic <> ''::text
        UNION
         SELECT planet_osm_point.way AS center,
                CASE
                    WHEN planet_osm_point.tourism = 'viewpoint'::text THEN 'viewpoint'::text
                    WHEN planet_osm_point.tourism = ANY (ARRAY['museum'::text, 'gallery'::text]) THEN 'museum'::text
                    WHEN planet_osm_point.tourism = 'attraction'::text AND planet_osm_point.historic IS NULL THEN 'attraction'::text
                    WHEN planet_osm_point.historic = 'ruins'::text THEN 'ruins'::text
                    WHEN planet_osm_point.historic = 'archaeological_site'::text THEN 'archaeological_site'::text
                    WHEN planet_osm_point.historic = 'battlefield'::text THEN 'battlefield'::text
                    WHEN planet_osm_point.historic = 'wayside_cross'::text THEN 'wayside_cross'::text
                    WHEN planet_osm_point.historic = ANY (ARRAY['castle'::text, 'fortification'::text, 'fort'::text]) THEN 'castle'::text
                    WHEN (planet_osm_point.historic = ANY (ARRAY['manor'::text, 'palace'::text, 'heritage'::text])) OR (planet_osm_point.tags -> 'manor'::text) <> ''::text THEN 'manor'::text
                    WHEN (planet_osm_point.historic = ANY (ARRAY['memorial'::text, 'monument'::text])) OR (planet_osm_point.tags -> 'monument'::text) = 'yes'::text THEN 'monument'::text
                    WHEN planet_osm_point.historic = 'church'::text THEN 'church'::text
                    ELSE NULL::text
                END AS tourism,
            planet_osm_point.name
           FROM planet_osm_point
          WHERE planet_osm_point.tourism <> ''::text OR planet_osm_point.historic <> ''::text) tourism
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_tourism
    OWNER TO postgres;


CREATE INDEX bikemap_tourism_center_idx
    ON public.bikemap_tourism USING gist
    (center)
    TABLESPACE pg_default;
CREATE INDEX bikemap_tourism_tourism_idx
    ON public.bikemap_tourism USING btree
    (tourism COLLATE pg_catalog."default")
    TABLESPACE pg_default;


-- View: public.bikemap_water

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_water;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_water
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS myid,
    water.landuse,
    water.way
   FROM ( SELECT DISTINCT planet_osm_polygon.way,
            'water'::text AS landuse
           FROM planet_osm_polygon
          WHERE (planet_osm_polygon.landuse = ANY (ARRAY['reservoir'::text, 'basin'::text])) OR planet_osm_polygon."natural" = 'water'::text
        UNION
         SELECT DISTINCT planet_osm_polygon.way,
            'wetland'::text AS landuse
           FROM planet_osm_polygon
          WHERE planet_osm_polygon."natural" = 'wetland'::text
        UNION
         SELECT DISTINCT planet_osm_polygon.way,
            'beach'::text AS landuse
           FROM planet_osm_polygon
          WHERE planet_osm_polygon."natural" = 'beach'::text OR planet_osm_polygon.military IS NOT NULL) water
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_water
    OWNER TO postgres;


CREATE INDEX bikemap_water_landuse_idx
    ON public.bikemap_water USING btree
    (landuse COLLATE pg_catalog."default")
    TABLESPACE pg_default;
CREATE INDEX bikemap_water_way_idx
    ON public.bikemap_water USING gist
    (way)
    TABLESPACE pg_default;
	
-- View: public.bikemap_waterways

DROP MATERIALIZED VIEW IF EXISTS public.bikemap_waterways;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.bikemap_waterways
TABLESPACE pg_default
AS
 SELECT row_number() OVER () AS id,
    waterways.name,
    waterways.waterway,
    waterways.geom::geometry(MultiLineString,3857) AS geom
   FROM ( SELECT planet_osm_line.name,
            planet_osm_line.waterway,
            st_multi(st_union(planet_osm_line.way)) AS geom
           FROM planet_osm_line
          WHERE (planet_osm_line.waterway = ANY (ARRAY['river'::text, 'stream'::text, 'canal'::text, 'ditch'::text, 'drain'::text])) AND planet_osm_line.name IS NOT NULL
          GROUP BY planet_osm_line.waterway, planet_osm_line.name
        UNION
         SELECT ''::text AS name,
            planet_osm_line.waterway,
            st_multi(planet_osm_line.way) AS geom
           FROM planet_osm_line
          WHERE (planet_osm_line.waterway = ANY (ARRAY['river'::text, 'stream'::text, 'canal'::text, 'ditch'::text, 'drain'::text])) AND planet_osm_line.name IS NULL) waterways
WITH DATA;

ALTER TABLE IF EXISTS public.bikemap_waterways
    OWNER TO postgres;


CREATE INDEX bikemap_waterways_geom_idx
    ON public.bikemap_waterways USING gist
    (geom)
    TABLESPACE pg_default;
CREATE INDEX bikemap_waterways_id
    ON public.bikemap_waterways USING btree
    (id)
    TABLESPACE pg_default;
