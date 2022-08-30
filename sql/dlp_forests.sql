DROP SEQUENCE IF EXISTS public."dlp_forests_ogc_fid_seq" CASCADE;

CREATE SEQUENCE IF NOT EXISTS public."dlp_forests_ogc_fid_seq"
    INCREMENT 1
    START 1
    MINVALUE 1
    MAXVALUE 2147483647
    CACHE 1
--    OWNED BY "dlp_forests".ogc_fid;
;

ALTER SEQUENCE public."dlp_forests_ogc_fid_seq"
    OWNER TO postgres;

DROP TABLE IF EXISTS public.dlp_forests;

CREATE TABLE IF NOT EXISTS public.dlp_forests
(
    ogc_fid integer NOT NULL DEFAULT nextval('"dlp_forests_ogc_fid_seq"'::regclass),
    gml_id character varying COLLATE pg_catalog."default" NOT NULL,
    a_i_num bigint,
    adr_for character varying COLLATE pg_catalog."default",
    area_type character varying COLLATE pg_catalog."default",
    site_type character varying COLLATE pg_catalog."default",
    silvicult character varying COLLATE pg_catalog."default",
    forest_fun character varying COLLATE pg_catalog."default",
    stand_stru character varying COLLATE pg_catalog."default",
    rotat_age bigint,
    sub_area double precision,
    prot_categ character varying COLLATE pg_catalog."default",
    species_cd character varying COLLATE pg_catalog."default",
    part_cd character varying COLLATE pg_catalog."default",
    spec_age bigint,
    a_year bigint,
    nazwa character varying COLLATE pg_catalog."default",
    geom geometry(MultiPolygon),
    CONSTRAINT "dlp_forests_pkey" PRIMARY KEY (ogc_fid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.dlp_forests
    OWNER to postgres;

ALTER TABLE IF EXISTS public.dlp_forests
  ALTER COLUMN geom
  TYPE Geometry(MultiPolygon, 2180)
  USING ST_SetSRID(geom, 2180);

-- Index: dlp_forests_geom_geom_idx

DROP INDEX IF EXISTS public."dlp_forests_geom_geom_idx";

CREATE INDEX IF NOT EXISTS "dlp_forests_geom_geom_idx"
    ON public.dlp_forests USING gist
    (geom)
    TABLESPACE pg_default;
