# Task 2 - AIS API Overview

Created at: 2026-05-23 15:23:07.205833

## Important implementation note
Grouped PostgREST aggregate queries were rejected by the server with HTTP 400 in this environment. Therefore, this script computes grouped summaries locally from `ais_static`, which is safe because it contains one row per vessel. The large `ais_dynamic` table is only queried with strict time filters or HEAD counts.

## Available API resources
- ais_dynamic
- ais_dynamic_daily_counts
- ais_dynamic_daily_counts_mat
- ais_germany
- ais_static
- geography_columns
- geometry_columns
- germany_h3
- ingested_files
- rpc/__h3_cell_to_children_aux
- rpc/_postgis_deprecate
- rpc/_postgis_index_extent
- rpc/_postgis_pgsql_version
- rpc/_postgis_scripts_pgsql_version
- rpc/_postgis_selectivity
- rpc/_postgis_stats
- rpc/_st_3ddfullywithin
- rpc/_st_3ddwithin
- rpc/_st_3dintersects
- rpc/_st_concavehull
- rpc/_st_contains
- rpc/_st_containsproperly
- rpc/_st_coveredby
- rpc/_st_covers
- rpc/_st_crosses
- rpc/_st_dfullywithin
- rpc/_st_dwithin
- rpc/_st_equals
- rpc/_st_intersects
- rpc/_st_linecrossingdirection
- rpc/_st_longestline
- rpc/_st_maxdistance
- rpc/_st_orderingequals
- rpc/_st_overlaps
- rpc/_st_sortablehash
- rpc/_st_touches
- rpc/_st_voronoi
- rpc/_st_within
- rpc/add_compression_policy
- rpc/add_continuous_aggregate_policy
- rpc/add_dimension
- rpc/add_job
- rpc/add_reorder_policy
- rpc/add_retention_policy
- rpc/addgeometrycolumn
- rpc/alter_job
- rpc/approximate_row_count
- rpc/attach_tablespace
- rpc/by_hash
- rpc/by_range
- rpc/chunk_columnstore_stats
- rpc/chunk_compression_stats
- rpc/chunks_detailed_size
- rpc/compress_chunk
- rpc/create_hypertable
- rpc/decompress_chunk
- rpc/delete_job
- rpc/detach_tablespace
- rpc/detach_tablespaces
- rpc/disable_chunk_skipping
- rpc/drop_chunks
- rpc/dropgeometrycolumn
- rpc/dropgeometrytable
- rpc/enable_chunk_skipping
- rpc/equals
- rpc/generate_uuidv7
- rpc/geography
- rpc/geometry
- rpc/geometry_above
- rpc/geometry_below
- rpc/geometry_cmp
- rpc/geometry_contained_3d
- rpc/geometry_contains
- rpc/geometry_contains_3d
- rpc/geometry_distance_box
- rpc/geometry_distance_centroid
- rpc/geometry_eq
- rpc/geometry_ge
- rpc/geometry_gist_same_2d
- rpc/geometry_gt
- rpc/geometry_le
- rpc/geometry_left
- rpc/geometry_lt
- rpc/geometry_neq
- rpc/geometry_overabove
- rpc/geometry_overbelow
- rpc/geometry_overlaps
- rpc/geometry_overlaps_3d
- rpc/geometry_overleft
- rpc/geometry_overright
- rpc/geometry_right
- rpc/geometry_same
- rpc/geometry_same_3d
- rpc/geometry_within
- rpc/geomfromewkb
- rpc/geomfromewkt
- rpc/get_telemetry_report
- rpc/h3_are_neighbor_cells
- rpc/h3_cell_area
- rpc/h3_cell_to_boundary
- rpc/h3_cell_to_center_child
- rpc/h3_cell_to_child_pos
- rpc/h3_cell_to_children
- rpc/h3_cell_to_children_slow
- rpc/h3_cell_to_lat_lng
- rpc/h3_cell_to_latlng
- rpc/h3_cell_to_local_ij
- rpc/h3_cell_to_parent
- rpc/h3_cell_to_vertex
- rpc/h3_cell_to_vertexes
- rpc/h3_cells_to_directed_edge
- rpc/h3_cells_to_multi_polygon
- rpc/h3_child_pos_to_cell
- rpc/h3_compact_cells
- rpc/h3_directed_edge_to_boundary
- rpc/h3_directed_edge_to_cells
- rpc/h3_edge_length
- rpc/h3_get_directed_edge_destination
- rpc/h3_get_directed_edge_origin
- rpc/h3_get_extension_version
- rpc/h3_get_hexagon_area_avg
- rpc/h3_get_hexagon_edge_length_avg
- rpc/h3_get_num_cells
- rpc/h3_get_pentagons
- rpc/h3_get_res_0_cells
- rpc/h3_great_circle_distance
- rpc/h3_grid_disk
- rpc/h3_grid_disk_distances
- rpc/h3_grid_distance
- rpc/h3_grid_path_cells
- rpc/h3_grid_ring_unsafe
- rpc/h3_is_valid_directed_edge
- rpc/h3_is_valid_vertex
- rpc/h3_lat_lng_to_cell
- rpc/h3_latlng_to_cell
- rpc/h3_local_ij_to_cell
- rpc/h3_polygon_to_cells
- rpc/h3_polygon_to_cells_experimental
- rpc/h3_uncompact_cells
- rpc/h3_vertex_to_lat_lng
- rpc/h3_vertex_to_latlng
- rpc/hypertable_approximate_detailed_size
- rpc/hypertable_approximate_size
- rpc/hypertable_columnstore_stats
- rpc/hypertable_compression_stats
- rpc/hypertable_detailed_size
- rpc/hypertable_index_size
- rpc/hypertable_size
- rpc/interpolate
- rpc/locf
- rpc/move_chunk
- rpc/populate_geometry_columns
- rpc/postgis_constraint_dims
- rpc/postgis_constraint_srid
- rpc/postgis_constraint_type
- rpc/postgis_extensions_upgrade
- rpc/postgis_full_version
- rpc/postgis_geos_compiled_version
- rpc/postgis_geos_version
- rpc/postgis_lib_build_date
- rpc/postgis_lib_revision
- rpc/postgis_lib_version
- rpc/postgis_libjson_version
- rpc/postgis_liblwgeom_version
- rpc/postgis_libprotobuf_version
- rpc/postgis_libxml_version
- rpc/postgis_proj_compiled_version
- rpc/postgis_proj_version
- rpc/postgis_scripts_build_date
- rpc/postgis_scripts_installed
- rpc/postgis_scripts_released
- rpc/postgis_srs
- rpc/postgis_srs_all
- rpc/postgis_srs_codes
- rpc/postgis_srs_search
- rpc/postgis_svn_version
- rpc/postgis_transform_geometry
- rpc/postgis_transform_pipeline_geometry
- rpc/postgis_type_name
- rpc/postgis_version
- rpc/postgis_wagyu_version
- rpc/remove_compression_policy
- rpc/remove_continuous_aggregate_policy
- rpc/remove_reorder_policy
- rpc/remove_retention_policy
- rpc/reorder_chunk
- rpc/set_adaptive_chunking
- rpc/set_chunk_time_interval
- rpc/set_integer_now_func
- rpc/set_number_partitions
- rpc/set_partitioning_interval
- rpc/show_chunks
- rpc/show_tablespaces
- rpc/st_3dclosestpoint
- rpc/st_3ddfullywithin
- rpc/st_3ddistance
- rpc/st_3ddwithin
- rpc/st_3dintersects
- rpc/st_3dlongestline
- rpc/st_3dmakebox
- rpc/st_3dmaxdistance
- rpc/st_3dshortestline
- rpc/st_addpoint
- rpc/st_angle
- rpc/st_area
- rpc/st_asencodedpolyline
- rpc/st_asewkt
- rpc/st_asgeojson
- rpc/st_asgml
- rpc/st_askml
- rpc/st_aslatlontext
- rpc/st_asmarc21
- rpc/st_asmvtgeom
- rpc/st_assvg
- rpc/st_astext
- rpc/st_astwkb
- rpc/st_asx3d
- rpc/st_azimuth
- rpc/st_boundingdiagonal
- rpc/st_buffer
- rpc/st_centroid
- rpc/st_clipbybox2d
- rpc/st_closestpoint
- rpc/st_collect
- rpc/st_concavehull
- rpc/st_contains
- rpc/st_containsproperly
- rpc/st_coorddim
- rpc/st_coveredby
- rpc/st_covers
- rpc/st_crosses
- rpc/st_curven
- rpc/st_curvetoline
- rpc/st_delaunaytriangles
- rpc/st_dfullywithin
- rpc/st_difference
- rpc/st_disjoint
- rpc/st_distance
- rpc/st_distancesphere
- rpc/st_distancespheroid
- rpc/st_dwithin
- rpc/st_equals
- rpc/st_expand
- rpc/st_force3d
- rpc/st_force3dm
- rpc/st_force3dz
- rpc/st_force4d
- rpc/st_forcesfs
- rpc/st_frechetdistance
- rpc/st_generatepoints
- rpc/st_geogfromtext
- rpc/st_geogfromwkb
- rpc/st_geographyfromtext
- rpc/st_geohash
- rpc/st_geomcollfromtext
- rpc/st_geomcollfromwkb
- rpc/st_geometricmedian
- rpc/st_geometryfromtext
- rpc/st_geomfromewkb
- rpc/st_geomfromewkt
- rpc/st_geomfromgeojson
- rpc/st_geomfromgml
- rpc/st_geomfromkml
- rpc/st_geomfrommarc21
- rpc/st_geomfromtext
- rpc/st_geomfromtwkb
- rpc/st_geomfromwkb
- rpc/st_gmltosql
- rpc/st_hasarc
- rpc/st_hausdorffdistance
- rpc/st_hexagon
- rpc/st_hexagongrid
- rpc/st_interpolatepoint
- rpc/st_intersection
- rpc/st_intersects
- rpc/st_inversetransformpipeline
- rpc/st_isvaliddetail
- rpc/st_largestemptycircle
- rpc/st_length
- rpc/st_letters
- rpc/st_linecrossingdirection
- rpc/st_lineextend
- rpc/st_linefromencodedpolyline
- rpc/st_linefromtext
- rpc/st_linefromwkb
- rpc/st_lineinterpolatepoint
- rpc/st_lineinterpolatepoints
- rpc/st_linelocatepoint
- rpc/st_linestringfromwkb
- rpc/st_linetocurve
- rpc/st_locatealong
- rpc/st_locatebetween
- rpc/st_locatebetweenelevations
- rpc/st_longestline
- rpc/st_makebox2d
- rpc/st_makeline
- rpc/st_makevalid
- rpc/st_maxdistance
- rpc/st_maximuminscribedcircle
- rpc/st_minimumboundingcircle
- rpc/st_minimumboundingradius
- rpc/st_mlinefromtext
- rpc/st_mlinefromwkb
- rpc/st_mpointfromtext
- rpc/st_mpointfromwkb
- rpc/st_mpolyfromtext
- rpc/st_mpolyfromwkb
- rpc/st_multilinefromwkb
- rpc/st_multilinestringfromtext
- rpc/st_multipointfromtext
- rpc/st_multipointfromwkb
- rpc/st_multipolyfromwkb
- rpc/st_multipolygonfromtext
- rpc/st_node
- rpc/st_normalize
- rpc/st_numcurves
- rpc/st_offsetcurve
- rpc/st_orderingequals
- rpc/st_overlaps
- rpc/st_perimeter
- rpc/st_point
- rpc/st_pointfromtext
- rpc/st_pointfromwkb
- rpc/st_pointm
- rpc/st_pointz
- rpc/st_pointzm
- rpc/st_polyfromtext
- rpc/st_polyfromwkb
- rpc/st_polygonfromtext
- rpc/st_polygonfromwkb
- rpc/st_project
- rpc/st_quantizecoordinates
- rpc/st_reduceprecision
- rpc/st_relate
- rpc/st_removerepeatedpoints
- rpc/st_scale
- rpc/st_segmentize
- rpc/st_setsrid
- rpc/st_sharedpaths
- rpc/st_shortestline
- rpc/st_simplifypolygonhull
- rpc/st_snap
- rpc/st_snaptogrid
- rpc/st_split
- rpc/st_square
- rpc/st_squaregrid
- rpc/st_srid
- rpc/st_subdivide
- rpc/st_swapordinates
- rpc/st_symdifference
- rpc/st_symmetricdifference
- rpc/st_tileenvelope
- rpc/st_touches
- rpc/st_transform
- rpc/st_transformpipeline
- rpc/st_triangulatepolygon
- rpc/st_unaryunion
- rpc/st_union
- rpc/st_voronoilines
- rpc/st_voronoipolygons
- rpc/st_within
- rpc/st_wkbtosql
- rpc/st_wkttosql
- rpc/st_wrapx
- rpc/time_bucket
- rpc/time_bucket_gapfill
- rpc/timescaledb_post_restore
- rpc/timescaledb_pre_restore
- rpc/to_uuidv7
- rpc/to_uuidv7_boundary
- rpc/updategeometrysrid
- rpc/uuid_timestamp
- rpc/uuid_timestamp_micros
- rpc/uuid_version
- spatial_ref_sys

## Row counts
# A tibble: 3 × 3
  table       count_method                        n_rows
  <chr>       <chr>                                <dbl>
1 ais_static  local exact count / HEAD count      228427
2 ais_dynamic planned / approximate HEAD count 826793024
3 ais_germany planned / approximate HEAD count 389947776

## Distinct vessels
# A tibble: 1 × 3
  source     logic                                                                                                                   distinct_mmsi
  <chr>      <chr>                                                                                                                           <int>
1 ais_static ais_static contains one row per MMSI; therefore distinct vessels are counted from non-missing mmsi values in ais_static        228427

## Most frequent ship types
# A tibble: 14 × 2
   ship_type             n
   <chr>             <int>
 1 Other             57974
 2 Cargo             51781
 3 Fishing Vessel    34736
 4 <NA>              21842
 5 Tanker            16496
 6 Tug               13257
 7 Pleasure Craft     9014
 8 Special Craft      7624
 9 Passenger Ship     7147
10 Sailing Vessel     5164
11 High-Speed Craft   1227
12 Search and Rescue  1201
13 Wing In Ground      644
14 Reserved            320

## Most frequent flags
# A tibble: 30 × 2
   flag      n
   <chr> <int>
 1 CN    67214
 2 US    13771
 3 PA     8024
 4 NL     7635
 5 NO     7303
 6 ID     6538
 7 VN     6308
 8 LR     5629
 9 MH     4991
10 KR     4903
11 JP     4810
12 GB     4418
13 SG     4161
14 DE     4098
15 MT     3056
16 AU     3055
17 HK     2800
18 RU     2595
19 ES     2574
20 DK     2560
21 FR     2537
22 CA     2334
23 IN     2272
24 TR     2200
25 IT     1964
26 TW     1928
27 CY     1831
28 BR     1818
29 SA     1607
30 PT     1595
Distinct flags in ais_static: 229

## ais_static columns
# A tibble: 13 × 4
   column            guessed_r_type n_non_missing example_values                                                                                                 
   <chr>             <chr>                  <int> <chr>                                                                                                          
 1 mmsi              integer               228427 355289000, 367168640, 308621000, 229630000, 244660429                                                          
 2 imo               integer               121121 8918978, 9243162, 9169744, 9365960, 0                                                                          
 3 name              character             214784 MSC SUEZ, CHARLESTON EXPRESS, GSP ALTAIR, X-PRESS MULHACEN, RS ALINDA@@@@@@@@@@@                               
 4 call_sign         character             184208 HPMS, WDD6126, C6PW6, 9HA3465, PH4782@                                                                         
 5 flag              character             228405 PA, US, BS, MT, NL                                                                                             
 6 draught           numeric               121121 8.7, 10, 5, 7, 0                                                                                               
 7 ship_type_code    integer               216262 74, 70, 72, 79, 75                                                                                             
 8 ship_type         character             206585 Cargo, Passenger Ship, Other, Tanker, Wing In Ground                                                           
 9 length            integer               216537 237, 243, 83, 142, 86                                                                                          
10 width             integer               216537 32, 19, 20, 8, 29                                                                                              
11 eta               character              95439 2024-01-23T13:00:00+00:00, 2021-05-06T14:00:00+00:00, 2022-03-09T01:00:00+00:00, 2024-01-23T14:00:00+00:00, 20…
12 destination       character             119123 CISPY, GBLGP, ANA RIG, NLRTM, ROTTERDAM BOTLEK@@@@                                                             
13 static_updated_at character             203288 2024-01-24T23:28:44+00:00, 2021-05-04T18:40:39+00:00, 2022-03-08T19:10:18+00:00, 2024-01-24T23:51:50+00:00, 20…

## Numeric summaries for ais_static
# A tibble: 6 × 5
  column         n_non_missing     min         max          avg
  <chr>                  <int>   <dbl>       <dbl>        <dbl>
1 draught               121121       0        25.5         4.72
2 imo                   121121       0 977392300     5416987.  
3 length                216537       0      1022          63.6 
4 mmsi                  228427 2010002 995093791   387793157.  
5 ship_type_code        216262       0       255          45.2 
6 width                 216537       0       126          11.5 

## Categorical top values for ais_static
# A tibble: 35 × 3
   column            value                         n
   <chr>             <chr>                     <int>
 1 call_sign         @@@@@@@                   25653
 2 call_sign         0000000                    7492
 3 call_sign         0@@@@@@                    3205
 4 call_sign         1234567                    1500
 5 call_sign         YYYY@@@                     755
 6 destination       @@@@@@@@@@@@@@@@@@@@      17135
 7 destination       0@@@@@@@@@@@@@@@@@@@        692
 8 destination       SHANGHAI@@@@@@@@@@@@        593
 9 destination       ZHOUSHAN                    459
10 destination       @                           401
11 eta               2024-01-01T00:00:00+00:00  1833
12 eta               2024-01-01T01:01:00+00:00  1119
13 eta               2024-01-25T08:00:00+00:00   497
14 eta               2024-01-25T12:00:00+00:00   446
15 eta               2024-01-25T06:00:00+00:00   399
16 flag              CN                        67214
17 flag              US                        13771
18 flag              PA                         8024
19 flag              NL                         7635
20 flag              NO                         7303
21 name              @@@@@@@@@@@@@@@@@@@@        666
22 name              @@@@@@@@@@@@@@@@@@@         112
23 name              SH                           71
24 name              0@@@@@@@@@@@@@@@@@@@         47
25 name              ORION                        33
26 ship_type         Other                     57974
27 ship_type         Cargo                     51781
28 ship_type         Fishing Vessel            34736
29 ship_type         Tanker                    16496
30 ship_type         Tug                       13257
31 static_updated_at 2024-01-24T23:49:28+00:00    75
32 static_updated_at 2024-01-24T23:49:36+00:00    73
33 static_updated_at 2024-01-24T23:46:41+00:00    72
34 static_updated_at 2024-01-24T23:43:56+00:00    70
35 static_updated_at 2024-01-24T23:47:04+00:00    70

## Task 2.4 answers
- Benelux ships: 9476
- German cargo ships: 291
- German cargo ships longer than 150 m: 76
- Vessels with EXPRESS in name: 572
- Dynamic AIS records in first five minutes of 2022: 1506
- Distinct vessels in first five minutes of 2022: 1100
- Vessels faster than 12 knots in the 30-minute interval: 76
- Of these, cargo vessels: 31
- Limit example: GET /ais_static?select=mmsi,name,flag,ship_type&limit=5
