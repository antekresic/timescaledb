DROP FUNCTION IF EXISTS @extschema@.add_retention_policy;
DROP FUNCTION IF EXISTS @extschema@.add_compression_policy;
DROP FUNCTION IF EXISTS @extschema@.detach_data_node;

DROP FUNCTION _timescaledb_internal.attach_osm_table_chunk( hypertable REGCLASS, chunk REGCLASS);
DROP FUNCTION _timescaledb_internal.alter_job_set_hypertable_id( job_id INTEGER, hypertable REGCLASS );

