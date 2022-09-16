-- This file and its contents are licensed under the Timescale License.
-- Please see the included NOTICE for copyright information and
-- LICENSE-TIMESCALE for a copy of the license.

\ir include/rand_generator.sql
\c :TEST_DBNAME :ROLE_SUPERUSER
\ir include/compression_utils.sql
\c :TEST_DBNAME :ROLE_DEFAULT_PERM_USER

CREATE TABLE test1 ("Time" timestamptz, i integer, value integer);
SELECT table_name from create_hypertable('test1', 'Time', chunk_time_interval=> INTERVAL '1 hour');

-- This will generate 24 chunks
INSERT INTO test1 SELECT t, gen_rand_minstd(), gen_rand_minstd() FROM generate_series('2018-03-02 1:00'::TIMESTAMPTZ, '2018-03-03 0:59', '1 minute') t;

-- Compression is set to merge those 24 chunks into 12 2 hour chunks
ALTER TABLE test1 set (timescaledb.compress, timescaledb.compress_segmentby='i', timescaledb.compress_orderby='"Time"', timescaledb.compress_chunk_time_interval='2 hours');

SELECT
  $$
  SELECT * FROM test1 ORDER BY "Time"
  $$ AS "QUERY" \gset

SELECT 'test1' AS "HYPERTABLE_NAME" \gset
\ir include/compression_test_merge.sql
\set TYPE timestamptz
\set ORDER_BY_COL_NAME Time
\set SEGMENT_META_COL_MIN _ts_meta_min_1
\set SEGMENT_META_COL_MAX _ts_meta_max_1
\ir include/compression_test_hypertable_segment_meta.sql

DROP TABLE test1;

CREATE TABLE test2 ("Time" timestamptz, i integer, loc integer, value integer);
SELECT table_name from create_hypertable('test2', 'Time', chunk_time_interval=> INTERVAL '1 hour');

-- This will generate 24 1 hour chunks.
INSERT INTO test2 SELECT t, gen_rand_minstd(), gen_rand_minstd(), gen_rand_minstd() FROM generate_series('2018-03-02 1:00'::TIMESTAMPTZ, '2018-03-03 0:59', '1 minute') t;

-- Compression is set to merge those 24 chunks into 3 chunks, two 10 hour chunks and a single 4 hour chunk.
ALTER TABLE test2 set (timescaledb.compress, timescaledb.compress_segmentby='i', timescaledb.compress_orderby='loc,"Time"', timescaledb.compress_chunk_time_interval='10 hours');

SELECT
  $$
  SELECT * FROM test2 ORDER BY "Time"
  $$ AS "QUERY" \gset

SELECT 'test2' AS "HYPERTABLE_NAME" \gset
\ir include/compression_test_merge.sql
\set TYPE integer
\set ORDER_BY_COL_NAME loc
\set SEGMENT_META_COL_MIN _ts_meta_min_1
\set SEGMENT_META_COL_MAX _ts_meta_max_1
\ir include/compression_test_hypertable_segment_meta.sql

DROP TABLE test2;

CREATE TABLE test3 ("Time" timestamptz, i integer, loc integer, value integer);
SELECT table_name from create_hypertable('test3', 'Time', chunk_time_interval=> INTERVAL '1 hour');
SELECT table_name from  add_dimension('test3', 'i', chunk_time_interval=> 1);

-- This will generate 25 1 hour chunks with a closed space dimension.
INSERT INTO test3 SELECT t, 1, gen_rand_minstd(), gen_rand_minstd() FROM generate_series('2018-03-02 1:00'::TIMESTAMPTZ, '2018-03-02 12:59', '1 minute') t;
INSERT INTO test3 SELECT t, 2, gen_rand_minstd(), gen_rand_minstd() FROM generate_series('2018-03-02 13:00'::TIMESTAMPTZ, '2018-03-03 0:59', '1 minute') t;
INSERT INTO test3 SELECT t, 3, gen_rand_minstd(), gen_rand_minstd() FROM generate_series('2018-03-02 2:00'::TIMESTAMPTZ, '2018-03-02 2:01', '1 minute') t;

-- Compression is set to merge those 25 chunks into 12 2 hour chunks and a single 1 hour chunks on a different space dimensions.
ALTER TABLE test3 set (timescaledb.compress, timescaledb.compress_orderby='loc,"Time"', timescaledb.compress_chunk_time_interval='2 hours');

SELECT
  $$
  SELECT * FROM test3 WHERE i = 1 ORDER BY "Time"
  $$ AS "QUERY" \gset

SELECT 'test3' AS "HYPERTABLE_NAME" \gset
\ir include/compression_test_merge.sql

\set TYPE integer
\set ORDER_BY_COL_NAME loc
\set SEGMENT_META_COL_MIN _ts_meta_min_1
\set SEGMENT_META_COL_MAX _ts_meta_max_1
\ir include/compression_test_hypertable_segment_meta.sql

DROP TABLE test3;
