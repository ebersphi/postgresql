Evolution of the pg_stat_statements VIEW 

| 17 | 16 | 15 | 14 | 13 | 12 | 11 | Column | Type | Description |
|:----:|:----:|:----:|:----:|:----:|:----:|:----:|--------|-----------|-----------|
| X | X | X | X | X | X | X | userid | oid | pg_authid.oid OID de l'utilisateur qui a exécuté l'ordre SQL |
| X | X | X | X | X | X | X | dbid | oid | pg_database.oid OID de la base de données dans laquelle l'ordre SQL a été exécuté |
| X | X | X | X | X | X | X | queryid | bigint | Code de hachage interne, calculé à partir de l'arbre d'analyse de la requête. |
