
-- gapfill with timezone support
CREATE FUNCTION @extschema@.time_bucket_gapfill(bucket_width INTERVAL, ts TIMESTAMPTZ, timezone TEXT, start TIMESTAMPTZ=NULL, finish TIMESTAMPTZ=NULL) RETURNS TIMESTAMPTZ
AS '@MODULE_PATHNAME@', 'ts_gapfill_timestamptz_timezone_bucket' LANGUAGE C VOLATILE PARALLEL SAFE;

ALTER TABLE _timescaledb_catalog.compression_chunk_size DROP CONSTRAINT compression_chunk_size_pkey;
ALTER TABLE _timescaledb_catalog.compression_chunk_size ADD CONSTRAINT compression_chunk_size_pkey PRIMARY KEY(chunk_id);

DROP PROCEDURE IF EXISTS @extschema@.cagg_migrate (REGCLASS, BOOLEAN, BOOLEAN);

CREATE PROCEDURE @extschema@.cagg_migrate (
    cagg REGCLASS,
    override BOOLEAN DEFAULT FALSE,
    drop_old BOOLEAN DEFAULT FALSE
)
LANGUAGE plpgsql AS
$BODY$
DECLARE
    _cagg_schema TEXT;
    _cagg_name TEXT;
    _cagg_name_new TEXT;
    _cagg_data _timescaledb_catalog.continuous_agg;
BEGIN
    SELECT nspname, relname
    INTO _cagg_schema, _cagg_name
    FROM pg_catalog.pg_class
    JOIN pg_catalog.pg_namespace ON pg_namespace.oid OPERATOR(pg_catalog.=) pg_class.relnamespace
    WHERE pg_class.oid OPERATOR(pg_catalog.=) cagg::pg_catalog.oid;

    -- maximum size of an identifier in Postgres is 63 characters, se we need to left space for '_new'
    _cagg_name_new := pg_catalog.format('%s_new', pg_catalog.substr(_cagg_name, 1, 59));

    -- pre-validate the migration and get some variables
    _cagg_data := _timescaledb_internal.cagg_migrate_pre_validation(_cagg_schema, _cagg_name, _cagg_name_new);

    -- create new migration plan
    CALL _timescaledb_internal.cagg_migrate_create_plan(_cagg_data, _cagg_name_new, override, drop_old);
    COMMIT;

    -- execute the migration plan
    CALL _timescaledb_internal.cagg_migrate_execute_plan(_cagg_data);

    -- finish the migration plan
    UPDATE _timescaledb_catalog.continuous_agg_migrate_plan
    SET end_ts = pg_catalog.clock_timestamp()
    WHERE mat_hypertable_id OPERATOR(pg_catalog.=) _cagg_data.mat_hypertable_id;
END;
$BODY$;

-- Recreate _timescaledb_catalog.dimension table with the compress_interval_length column --
CREATE TABLE _timescaledb_internal.dimension_tmp
AS SELECT * from _timescaledb_catalog.dimension;

CREATE TABLE _timescaledb_internal.tmp_dimension_seq_value AS
SELECT last_value, is_called FROM _timescaledb_catalog.dimension_id_seq;

--drop foreign keys on dimension table
ALTER TABLE _timescaledb_catalog.dimension_partition DROP CONSTRAINT 
dimension_partition_dimension_id_fkey;
ALTER TABLE _timescaledb_catalog.dimension_slice DROP CONSTRAINT 
dimension_slice_dimension_id_fkey;

--drop dependent views
DROP VIEW IF EXISTS timescaledb_information.chunks;
DROP VIEW IF EXISTS timescaledb_information.dimensions;

ALTER EXTENSION timescaledb DROP TABLE _timescaledb_catalog.dimension;
ALTER EXTENSION timescaledb DROP SEQUENCE _timescaledb_catalog.dimension_id_seq;
DROP TABLE _timescaledb_catalog.dimension;

CREATE TABLE _timescaledb_catalog.dimension (
  id serial NOT NULL ,
  hypertable_id integer NOT NULL,
  column_name name NOT NULL,
  column_type REGTYPE NOT NULL,
  aligned boolean NOT NULL,
  -- closed dimensions
  num_slices smallint NULL,
  partitioning_func_schema name NULL,
  partitioning_func name NULL,
  -- open dimensions (e.g., time)
  interval_length bigint NULL,
  compress_interval_length bigint NULL,
  integer_now_func_schema name NULL,
  integer_now_func name NULL,
  -- table constraints
  CONSTRAINT dimension_pkey PRIMARY KEY (id),
  CONSTRAINT dimension_hypertable_id_column_name_key UNIQUE (hypertable_id, column_name),
  CONSTRAINT dimension_check CHECK ((partitioning_func_schema IS NULL AND partitioning_func IS NULL) OR (partitioning_func_schema IS NOT NULL AND partitioning_func IS NOT NULL)),
  CONSTRAINT dimension_check1 CHECK ((num_slices IS NULL AND interval_length IS NOT NULL) OR (num_slices IS NOT NULL AND interval_length IS NULL)),
  CONSTRAINT dimension_check2 CHECK ((integer_now_func_schema IS NULL AND integer_now_func IS NULL) OR (integer_now_func_schema IS NOT NULL AND integer_now_func IS NOT NULL)),
  CONSTRAINT dimension_interval_length_check CHECK (interval_length IS NULL OR interval_length > 0),
  CONSTRAINT dimension_compress_interval_length_check CHECK (compress_interval_length IS NULL OR compress_interval_length > 0),
  CONSTRAINT dimension_hypertable_id_fkey FOREIGN KEY (hypertable_id) REFERENCES _timescaledb_catalog.hypertable (id) ON DELETE CASCADE
);

INSERT INTO _timescaledb_catalog.dimension
( id, hypertable_id, column_name, column_type,
  aligned, num_slices, partitioning_func_schema,
  partitioning_func, interval_length,
  integer_now_func_schema, integer_now_func)
SELECT id, hypertable_id, column_name, column_type,
  aligned, num_slices, partitioning_func_schema,
  partitioning_func, interval_length,
  integer_now_func_schema, integer_now_func
FROM _timescaledb_internal.dimension_tmp;

ALTER SEQUENCE _timescaledb_catalog.dimension_id_seq OWNED BY _timescaledb_catalog.dimension.id;
SELECT setval('_timescaledb_catalog.dimension_id_seq', last_value, is_called) FROM _timescaledb_internal.tmp_dimension_seq_value;

SELECT pg_catalog.pg_extension_config_dump('_timescaledb_catalog.dimension', '');
SELECT pg_catalog.pg_extension_config_dump(pg_get_serial_sequence('_timescaledb_catalog.dimension', 'id'), '');

--add the foreign key constraints
ALTER TABLE _timescaledb_catalog.dimension_partition ADD CONSTRAINT 
dimension_partition_dimension_id_fkey FOREIGN KEY (dimension_id) 
REFERENCES _timescaledb_catalog.dimension(id) ON DELETE CASCADE; 
ALTER TABLE _timescaledb_catalog.dimension_slice ADD CONSTRAINT
dimension_slice_dimension_id_fkey FOREIGN KEY (dimension_id) 
REFERENCES _timescaledb_catalog.dimension(id) ON DELETE CASCADE;

--cleanup
DROP TABLE _timescaledb_internal.dimension_tmp;
DROP TABLE _timescaledb_internal.tmp_dimension_seq_value;

GRANT SELECT ON _timescaledb_catalog.dimension_id_seq TO PUBLIC;
GRANT SELECT ON _timescaledb_catalog.dimension TO PUBLIC;

-- end recreate _timescaledb_catalog.dimension table --
