Evolution of the pg_stat_statements VIEW 

| 18 | 17 | 16 | 15 | 14 | 13 | 12 | 11 | Column | Type | Description |
|:----:|:----:|:----:|:----:|:----:|:----:|:----:|:----:|--------|-----------|-----------|
| X | X | X | X | X | X | X | X | userid | oid | pg_authid.oid OID de l'utilisateur qui a exécuté l'ordre SQL |
| X | X | X | X | X | X | X | X | dbid | oid | pg_database.oid OID de la base de données dans laquelle l'ordre SQL a été exécuté |
| X | X | X | X | X | X | X | X | toplevel | bool | True si la requête a été exécutée comme instruction de haut niveau (toujours true si pg_stat_statements.track est configuré à top) |
| X | X | X | X | X | X | X | X | queryid | bigint | Code de hachage interne, calculé à partir de l'arbre d'analyse de la requête. |
| X | X | X | X | X | X | X | X | query | text | Texte d'une requête représentative |
| X | X | X | X | X | X | X | X | plans  | bigint | Nombre d'optimisations de la requête (si pg_stat_statements.track_planning est activé, sinon zéro) |
| X | X | X | X | X | X | X | X | total_plan_time  |double precision  | Durée totale passée à optimiser la requête, en millisecondes (si pg_stat_statements.track_planning est activé, sinon zéro) |
| X | X | X | X | X | X | X | X | min_plan_time  | double precision | Durée minimale passée à optimiser la requête, en millisecondes. Ce champ vaudra zéro si pg_stat_statements.track_planning est désactivé ou si le compteur a été réinitialisé en utilisant la fonction pg_stat_statements_reset avec le paramètre minmax_only initialisé à true et que la requête n'a pas été exécutée depuis. |
| X | X | X | X | X | X | X | X | max_plan_time  | double precision | Durée maximale passée à optimiser la requête, en millisecondes. Ce champ vaudra zéro si pg_stat_statements.track_planning est désactivé ou si le compteur a été réinitialisé en utilisant la fonction pg_stat_statements_reset avec le paramètre minmax_only initialisé à true et que la requête n'a pas été exécutée depuis. |
| X | X | X | X | X | X | X | X | mean_plan_time  | double precision | Durée moyenne passée à optimiser la requête, en millisecondes (si pg_stat_statements.track_planning est activé, sinon zéro) |
| X | X | X | X | X | X | X | X | stddev_plan_time  | double precision | Déviation standard de la durée passée à optimiser la requête, en millisecondes (si pg_stat_statements.track_planning est activé, sinon zéro) |
| X | X | X | X | X | X | X | X | calls | bigint | Nombre d'exécutions de la requête |
| X | X | X | X | X | X | X | X | total_exec_time  |double precision | Durée totale passée à exécuter la requête, en millisecondes |
| X | X | X | X | X | X | X | X | min_exec_time  | double precision | Durée minimale passée à exécuter la requête, en millisecondes. Ce champ vaudra zéro jusqu'à ce que cette requête soit exécutée pour la première fois après la réinitialisation réalisée par la fonction pg_stat_statements_reset avec le paramètre minmax_only initialisé à true |
| X | X | X | X | X | X | X | X | max_exec_time  | double precision | Durée maximale passée à exécuter la requête, en millisecondes. Ce champ vaudra zéro jusqu'à ce que cette requête soit exécutée pour la première fois après la réinitialisation réalisée par la fonction pg_stat_statements_reset avec le paramètre minmax_only initialisé à true |
| X | X | X | X | X | X | X | X | mean_exec_time  | double precision | Durée moyenne passée à exécuter la requête, en millisecondes |
| X | X | X | X | X | X | X | X | stddev_exec_time  | double precision |  |
| X | X | X | X | X | X | X | X | rows  | bigint |  |
| X | X | X | X | X | X | X | X | shared_blks_hit  | bigint |  |
| X | X | X | X | X | X | X | X | shared_blks_read  | bigint |  |
| X | X | X | X | X | X | X | X | shared_blks_written  | bigint |  |
| X | X | X | X | X | X | X | X | local_blks_hit  | bigint |  |
| X | X | X | X | X | X | X | X | local_blks_read   | bigint |  |
| X | X | X | X | X | X | X | X | local_blks_dirtied   | bigint |  |
| X | X | X | X | X | X | X | X | local_blks_written   | bigint |  |
| X | X | X | X | X | X | X | X | temp_blks_read   | bigint |  |
| X | X | X | X | X | X | X | X | temp_blks_written   | bigint |  |
| X | X | X | X | X | X | X | X | shared_blk_read_time   | double precision |  |
| X | X | X | X | X | X | X | X | shared_blk_write_time   | double precision |  |
| X | X | X | X | X | X | X | X | local_blk_read_time   | double precision |  |
| X | X | X | X | X | X | X | X | local_blk_write_time   | double precision |  |
| X | X | X | X | X | X | X | X | wal_records   | bigint |  |
| X | X | X | X | X | X | X | X | wal_fpi   | bigint |  |
| X | X | X | X | X | X | X | X | wal_bytes   | bigint |  |
| X | X | X | X | X | X | X | X | wal_buffers_full   | numeric |  |
| X | X | X | X | X | X | X | X | jit_functions   | bigint |  |
| X | X | X | X | X | X | X | X | jit_generation_time   | double precision |  |
| X | X | X | X | X | X | X | X | jit_inlining_count   | bigint |  |
| X | X | X | X | X | X | X | X | jit_inlining_time   | double precision |  |
| X | X | X | X | X | X | X | X | jit_optimization_count   | bigint |  |
| X | X | X | X | X | X | X | X | jit_optimization_time   | double precision |  |
| X | X | X | X | X | X | X | X | jit_emission_count   | bigint |  |
| X | X | X | X | X | X | X | X | jit_emission_time   | double precision |  |
| X | X | X | X | X | X | X | X | jit_deform_time    | double precision |  |
| X | X | X | X | X | X | X | X | parallel_workers_to_launch   | bigint | Nombre de workers de parallélisation planifiés |
| X | X | X | X | X | X | X | X | parallel_workers_launched   | bigint | Nombre de workers de parallélisation réellement lancés  |
| X | X | X | X | X | X | X | X | stats_since   | timestamp with time zone | Moment à partir duquel les statistiques ont commencé à être récupérées pour cette requête |
| X | X | X | X | X | X | X | X | minmax_stats_since   | timestamp with time zone | Moment à partir duquel les statistiques min/max ont commencé à être récupérées pour cette requête (champs min_plan_time, max_plan_time, min_exec_time et max_exec_time) |

