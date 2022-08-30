-- View: public.dlp_forests_addresses

DROP MATERIALIZED VIEW IF EXISTS public.dlp_forests_addresses;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.dlp_forests_addresses
TABLESPACE pg_default
AS
 SELECT "substring"(dlp_forests.adr_for::text, 1, strpos(dlp_forests.adr_for::text, ' '::text)) AS adres_lesny,
    st_union(st_buffer(dlp_forests.geom, 1::double precision, 'endcap=round join=round'::text)) AS geom
   FROM dlp_forests
  GROUP BY ("substring"(dlp_forests.adr_for::text, 1, strpos(dlp_forests.adr_for::text, ' '::text)))
WITH DATA;

ALTER TABLE IF EXISTS public.dlp_forests_addresses
    OWNER TO postgres;


CREATE UNIQUE INDEX dlp_forests_addresses_adres_idx
    ON public.dlp_forests_addresses USING btree
    (adres_lesny COLLATE pg_catalog."default")
    TABLESPACE pg_default;
CREATE INDEX dlp_forests_addresses_geom_idx
    ON public.dlp_forests_addresses USING gist
    (geom)
    TABLESPACE pg_default;
	
-- View: public.dlp_forests_swamp

DROP MATERIALIZED VIEW IF EXISTS public.dlp_forests_swamp;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.dlp_forests_swamp
TABLESPACE pg_default
AS
 SELECT * 
   FROM dlp_forests
  WHERE dlp_forests.area_type::text = 'BAGNO'::text
WITH DATA;

ALTER TABLE IF EXISTS public.dlp_forests_swamp
    OWNER TO postgres;


CREATE UNIQUE INDEX dlp_forests_swamp_ogc_fid_idx
    ON public.dlp_forests_swamp USING btree
    (ogc_fid)
    TABLESPACE pg_default;
CREATE INDEX dlp_forests_swamp_geom_idx
    ON public.dlp_forests_swamp USING gist
    (geom)
    TABLESPACE pg_default;