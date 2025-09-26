Evolution de la vue pg_stat_statements

Modifications par version :

18 Ajout de wal_buffers_full, parallel_workers_to_launch et parallel_workers_launched

17 Ajout de stats_since et minmax_stats_since

16 blk_read_time et blk_write_time remplacés par shared_blk\_\*\_time et local_blk\_\*\_time
16 Ajout de jit_deform_time

15 Ajourt= de jit\_\*

14 Ajout d'un indicateur toplevel (bool)

13 les champs total_time, min_time, max_time et stddev_time sont retirés et déclinés en \*\_exec_time et \*\_plan_time
13 Ajout du compte de plans, de mesures wal\_\*, temp_blk_read_time et temp_blk_write_time

12 Pas de changement entre les versions 10,11 et 12

#Tableau récapitulatif

| 18 | 17 | 16 | 15 | 14 | 13 | 12 | Column | Type | Description |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|--------|-----------|-----------|
| 18 | 17 | 16 | 15 | 14 | 13 | 12 |  userid | oid | pg_authid.oid OID de l'utilisateur qui a exécuté l'ordre SQL |
| 18 | 17 | 16 | 15 | 14 | 13 | 12 |  dbid | oid | pg_database.oid OID de la base de données dans laquelle l'ordre SQL a été exécuté |
| 18 | 17 | 16 | 15 | 14 |    |    |  toplevel | bool | True si la requête a été exécutée comme instruction de haut niveau (toujours true si pg_stat_statements.track est configuré à top) |
| 18 | 17 | 16 | 15 | 14 | 13 | 12 |  queryid | bigint | Code de hachage interne, calculé à partir de l'arbre d'analyse de la requête. |
| 18 | 17 | 16 | 15 | 14 | 13 | 12 |  query | text | Texte d'une requête représentative |
| 18 | 17 | 16 | 15 | 14 | 13 |    |  plans  | bigint | Nombre d'optimisations de la requête (si pg_stat_statements.track_planning est activé, sinon zéro) |
| 18 | 17 | 16 | 15 | 14 | 13 |    |  total_plan_time  |double precision  | Durée totale passée à optimiser la requête, en millisecondes (si pg_stat_statements.track_planning est activé, sinon zéro) |
| 18 | 17 | 16 | 15 | 14 | 13 |    |  min_plan_time  | double precision | Durée minimale passée à optimiser la requête, en millisecondes. Ce champ vaudra zéro si pg_stat_statements.track_planning est désactivé ou si le compteur a été réinitialisé en utilisant la fonction pg_stat_statements_reset avec le paramètre minmax_only initialisé à true et que la requête n'a pas été exécutée depuis. |
| 18 | 17 | 16 | 15 | 14 | 13 |    |  max_plan_time  | double precision | Durée maximale passée à optimiser la requête, en millisecondes. Ce champ vaudra zéro si pg_stat_statements.track_planning est désactivé ou si le compteur a été réinitialisé en utilisant la fonction pg_stat_statements_reset avec le paramètre minmax_only initialisé à true et que la requête n'a pas été exécutée depuis. |
| 18 | 17 | 16 | 15 | 14 | 13 |    |  mean_plan_time  | double precision | Durée moyenne passée à optimiser la requête, en millisecondes (si pg_stat_statements.track_planning est activé, sinon zéro) |
| 18 | 17 | 16 | 15 | 14 | 13 |    |  stddev_plan_time  | double precision | Déviation standard de la durée passée à optimiser la requête, en millisecondes (si pg_stat_statements.track_planning est activé, sinon zéro) |
| 18 | 17 | 16 | 15 | 14 | 13 | 12 | calls | bigint | Nombre d'exécutions de la requête |
|    |    |    |    |    |    | 12 | total_time  |double precision | Durée d'exécution de l'instruction SQL, en millisecondes |
|    |    |    |    |    |    | 12 | min_time  | double precision | Durée minimum d'exécution de l'instruction SQL, en millisecondes |
|    |    |    |    |    |    | 12 | max_time  | double precision | Durée maximum d'exécution de l'instruction SQL, en millisecondes |
|    |    |    |    |    |    | 12 | mean_time  | double precision | Durée moyenne d'exécution de l'instruction SQL, en millisecondes |
|    |    |    |    |    |    | 12 | stddev_time  | double precision | Déviation standard de la durée d'exécution de l'instruction SQL, en millisecondes |
| 18 | 17 | 16 | 15 | 14 | 13 |    |  total_exec_time  |double precision | Durée totale passée à exécuter la requête, en millisecondes |
| 18 | 17 | 16 | 15 | 14 | 13 |    |  min_exec_time  | double precision | Durée minimale passée à exécuter la requête, en millisecondes. Ce champ vaudra zéro jusqu'à ce que cette requête soit exécutée pour la première fois après la réinitialisation réalisée par la fonction pg_stat_statements_reset avec le paramètre minmax_only initialisé à true |
| 18 | 17 | 16 | 15 | 14 | 13 |    |  max_exec_time  | double precision | Durée maximale passée à exécuter la requête, en millisecondes. Ce champ vaudra zéro jusqu'à ce que cette requête soit exécutée pour la première fois après la réinitialisation réalisée par la fonction pg_stat_statements_reset avec le paramètre minmax_only initialisé à true |
| 18 | 17 | 16 | 15 | 14 | 13 |    | mean_exec_time  | double precision | Déviation standard de la durée passée à exécuter la requête, en millisecondes |
| 18 | 17 | 16 | 15 | 14 | 13 |    | stddev_exec_time  | double precision | Nombre total de lignes récupérées ou affectées par la requête |
| 18 | 17 | 16 | 15 | 14 | 13 | 12 | rows  | bigint | Nombre total de lignes récupérées ou affectées par la requête  |
| 18 | 17 | 16 | 15 | 14 | 13 | 12 | shared_blks_hit  | bigint | Nombre total de blocs lus dans le cache partagé par la requête |
| 18 | 17 | 16 | 15 | 14 | 13 | 12 | shared_blks_read  | bigint | Nombre total de blocs lus hors cache partagé par la requête |
| 18 | 17 | 16 | 15 | 14 | 13 | 12 | shared_blks_dirtied  | bigint | Nombre total de blocs modifiés dans le cache partagé par la requête |
| 18 | 17 | 16 | 15 | 14 | 13 | 12 | shared_blks_written  | bigint | Nombre total de blocs du cache partagé écrit sur disque par la requête |
| 18 | 17 | 16 | 15 | 14 | 13 | 12 | local_blks_hit  | bigint | Nombre total de blocs lus dans le cache local par la requête |
| 18 | 17 | 16 | 15 | 14 | 13 | 12 | local_blks_read   | bigint | Nombre total de blocs lus hors du cache local par la requête |
| 18 | 17 | 16 | 15 | 14 | 13 | 12 | local_blks_dirtied   | bigint | Nombre total de blocs modifiés dans le cache local par la requête |
| 18 | 17 | 16 | 15 | 14 | 13 | 12 | local_blks_written   | bigint | Nombre total de blocs du cache local écrit sur disque par la requête |
| 18 | 17 | 16 | 15 | 14 | 13 | 12 | temp_blks_read   | bigint | Nombre total de blocs lus dans les fichiers temporaires par la requête |
| 18 | 17 | 16 | 15 | 14 | 13 | 12 | temp_blks_written   | bigint | Nombre total de blocs écrits dans les fichiers temporaires par la requête |
| 18 | 17 | 16 |    |    |    |    | shared_blk_read_time   | double precision | Durée totale de lecture des blocs des fichiers de données (hors cache) par la requête, en millisecondes (si track_io_timing est activé, sinon zéro) |
| 18 | 17 | 16 |    |    |    |    | shared_blk_write_time   | double precision | Durée totale de l'écriture des blocs des fichiers de données (hors cache) par la requête, en millisecondes (si track_io_timing est activé, sinon zéro) |
|    |    |    | 15 | 14 | 13 | 12 | blk_read_time   | double precision | Durée totale de lecture des blocs des fichiers de données (hors cache) par la requête, en millisecondes (si track_io_timing est activé, sinon zéro) |
|    |    |    | 15 | 14 | 13 | 12 | blk_write_time  | double precision | Durée totale de l'écriture des blocs des fichiers de données (hors cache) par la requête, en millisecondes (si track_io_timing est activé, sinon zéro) |
| 18 | 17 | 16 |    |    |    |    | local_blk_read_time   | double precision | Durée totale totale de lecture de blocs locaux, en millisecondes (si track_io_timing est activé, sinon zéro) |
| 18 | 17 | 16 |    |    |    |    | local_blk_write_time   | double precision | Durée toale totale d'écriture de blocs locaux, en millisecondes (si track_io_timing est activé, sinon zéro) |
| 18 | 17 | 16 | 15 | 14 | 13 |    | temp_blk_read_time    | double precision | Durée totale des lectures des blocs de fichiers temporaires en millisecondes (si track_io_timing est activé, sinon zéro) |
| 18 | 17 | 16 | 15 | 14 | 13 |    | temp_blk_write_time    | double precision | Durée totale des écritures des blocs de fichiers temporaires en millisecondes (si track_io_timing est activé, sinon zéro) |
| 18 | 17 | 16 | 15 | 14 | 13 |    | wal_records   | bigint | Nombre total d'enregistrements générés dans les WAL par la requête |
| 18 | 17 | 16 | 15 | 14 | 13 |    | wal_fpi   | bigint | Nombre total d'images complètes de blocs (full page images) générés dans les WAL par la requête |
| 18 | 17 | 16 | 15 | 14 | 13 |    | wal_bytes   | bigint | Nombre total d'octets générés dans les WAL par la requête |
| 18 |    |    |    |    |    |    | wal_buffers_full   | numeric | Nombre de fois que les buffers WAL étaient complets |
| 18 | 17 | 16 | 15 |    |    |    | jit_functions   | bigint | Nombre total de fonctions compilées par JIT pour cette requête |
| 18 | 17 | 16 | 15 |    |    |    | jit_generation_time   | double precision | Durée totale passée par la requête sur la génération de code JIT, en millisecondes |
| 18 | 17 | 16 | 15 |    |    |    | jit_inlining_count   | bigint | Nombre de fois où les fonctions ont été incluses |
| 18 | 17 | 16 | 15 |    |    |    | jit_inlining_time   | double precision | Durée totale passée par la requête sur l'inclusion de fonctions, en millisecondes |
| 18 | 17 | 16 | 15 |    |    |    | jit_optimization_count   | bigint | Nombre de fois où la requête a été optimisée |
| 18 | 17 | 16 | 15 |    |    |    | jit_optimization_time   | double precision | Durée totale passée sur l'optimisation de la requête, en millisecondes |
| 18 | 17 | 16 | 15 |    |    |    | jit_emission_count   | bigint | Nombre de fois où du code a été émis |
| 18 | 17 | 16 | 15 |    |    |    | jit_emission_time   | double precision | Durée totale passée par la requête sur de l'émission de code, en millisecondes |
| 18 | 17 | 16 |    |    |    |    | jit_deform_time    | double precision | Nombre total de fonctions deform de lignes pour le code compilé par JIT pour la requête |
| 18 |    |    |    |    |    |    | parallel_workers_to_launch   | bigint | Nombre de workers de parallélisation planifiés |
| 18 |    |    |    |    |    |    | parallel_workers_launched   | bigint | Nombre de workers de parallélisation réellement lancés  |
| 18 | 17 |    |    |    |    |    | stats_since | timestamp with time zone | Moment à partir duquel les statistiques ont commencé à être récupérées pour cette requête |
| 18 | 17 |    |    |    |    |    | minmax_stats_since | timestamp with time zone | Moment à partir duquel les statistiques min/max ont commencé à être récupérées pour cette requête (champs min_plan_time, max_plan_time, min_exec_time et max_exec_time) |
