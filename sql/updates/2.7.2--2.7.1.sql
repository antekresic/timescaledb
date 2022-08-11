ALTER TABLE _timescaledb_catalog.dimension ADD COLUMN compress_interval_length bigint NULL;
ALTER TABLE _timescaledb_catalog.dimension ADD CONSTRAINT dimension_compress_interval_length_check CHECK (compress_interval_length IS NULL OR compress_interval_length > 0);
