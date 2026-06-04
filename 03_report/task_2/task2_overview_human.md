# Task 2 - AIS API Overview

Created at: 2026-06-04 14:17:40.981417

## Important implementation note
This script uses the now-enabled PostgREST aggregate functions for grouped summaries such as `select=ship_type,n:count()`. The large `ais_dynamic` table is still only queried with strict time filters, HEAD counts, or grouped aggregate queries to avoid downloading large unfiltered datasets.

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

## Row counts
# A tibble: 3 × 3
  table       count_method                        n_rows
  <chr>       <chr>                                <dbl>
1 ais_static  exact HEAD count                    228427
2 ais_dynamic planned / approximate HEAD count 826793024
3 ais_germany planned / approximate HEAD count 389947776

## Distinct vessels
# A tibble: 1 × 3
  source     logic                                                                                                              distinct_mmsi
  <chr>      <chr>                                                                                                                      <dbl>
1 ais_static ais_static contains one row per MMSI; therefore the exact HEAD row count is used as the number of distinct vessels        228427

## Most frequent ship types
# A tibble: 13 × 2
   ship_type             n
   <chr>             <dbl>
 1 Other             57974
 2 Cargo             51781
 3 Fishing Vessel    34736
 4 Tanker            16496
 5 Tug               13257
 6 Pleasure Craft     9014
 7 Special Craft      7624
 8 Passenger Ship     7147
 9 Sailing Vessel     5164
10 High-Speed Craft   1227
11 Search and Rescue  1201
12 Wing In Ground      644
13 Reserved            320

## Most frequent flags
# A tibble: 30 × 2
   flag      n
   <chr> <dbl>
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
  <chr>                  <dbl>   <dbl>       <dbl>        <dbl>
1 mmsi                  228427 2010002 995093791   387793157.  
2 imo                   121121       0 977392300     5416987.  
3 draught               121121       0        25.5         4.72
4 ship_type_code        216262       0       255          45.2 
5 length                216537       0      1022          63.6 
6 width                 216537       0       126          11.5 

## Data quality note
Some AIS metadata contain implausible placeholder or outlier values (e.g., unusually large IMO values or placeholder-like text such as '@@@@@'). This indicates minor data quality issues in the source AIS metadata but does not materially affect the task results.

## Categorical top values for ais_static
# A tibble: 35 × 3
   column            value                         n
   <chr>             <chr>                     <dbl>
 1 name              @@@@@@@@@@@@@@@@@@@@        666
 2 name              @@@@@@@@@@@@@@@@@@@         112
 3 name              SH                           71
 4 name              0@@@@@@@@@@@@@@@@@@@         47
 5 name              ORION                        33
 6 call_sign         @@@@@@@                   25653
 7 call_sign         0000000                    7492
 8 call_sign         0@@@@@@                    3205
 9 call_sign         1234567                    1500
10 call_sign         YYYY@@@                     755
11 flag              CN                        67214
12 flag              US                        13771
13 flag              PA                         8024
14 flag              NL                         7635
15 flag              NO                         7303
16 ship_type         Other                     57974
17 ship_type         Cargo                     51781
18 ship_type         Fishing Vessel            34736
19 ship_type         Tanker                    16496
20 ship_type         Tug                       13257
21 eta               2024-01-01T00:00:00+00:00  1833
22 eta               2024-01-01T01:01:00+00:00  1119
23 eta               2024-01-25T08:00:00+00:00   497
24 eta               2024-01-25T12:00:00+00:00   446
25 eta               2024-01-25T06:00:00+00:00   399
26 destination       @@@@@@@@@@@@@@@@@@@@      17135
27 destination       0@@@@@@@@@@@@@@@@@@@        692
28 destination       SHANGHAI@@@@@@@@@@@@        593
29 destination       ZHOUSHAN                    459
30 destination       @                           401
31 static_updated_at 2024-01-24T23:49:28+00:00    75
32 static_updated_at 2024-01-24T23:49:36+00:00    73
33 static_updated_at 2024-01-24T23:46:41+00:00    72
34 static_updated_at 2024-01-24T23:43:56+00:00    70
35 static_updated_at 2024-01-24T23:50:18+00:00    70

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
