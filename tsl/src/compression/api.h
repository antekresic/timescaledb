/*
 * This file and its contents are licensed under the Timescale License.
 * Please see the included NOTICE for copyright information and
 * LICENSE-TIMESCALE for a copy of the license.
 */
#ifndef TIMESCALEDB_TSL_COMPRESSION_API_H
#define TIMESCALEDB_TSL_COMPRESSION_API_H

#include <postgres.h>
#include <fmgr.h>

extern Chunk *find_chunk_to_merge_into(Hypertable *ht, Chunk *current_chunk);
extern bool check_is_chunk_order_violated_by_merge(
	const Dimension *time_dim, Chunk *mergable_chunk, Chunk *compressed_chunk,
	const FormData_hypertable_compression **column_compression_info, int num_compression_infos);
extern Datum tsl_create_compressed_chunk(PG_FUNCTION_ARGS);
extern Datum tsl_compress_chunk(PG_FUNCTION_ARGS);
extern Datum tsl_decompress_chunk(PG_FUNCTION_ARGS);
extern Datum tsl_recompress_chunk(PG_FUNCTION_ARGS);
extern Oid tsl_compress_chunk_wrapper(Chunk *chunk, bool if_not_compressed);
extern bool tsl_recompress_chunk_wrapper(Chunk *chunk);

#endif /* TIMESCALEDB_TSL_COMPRESSION_API_H */
