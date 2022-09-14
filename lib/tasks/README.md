# migrate_solr.rake

Used for migrating to a new version of solr while the previous version is still being used by the application.

There must be a separate local_env.yml in the conf folder with the configuration for the second solr instance, which will be selected using the LOCAL_ENV_FILE environment variable.

Usage:

1. Generate listing of ids of currently indexed objects
```
$ LOCAL_ENV_FILE=local_env.yml bundle exec rake migrate_solr:list_ids -- -o /tmp

Stored id list to file: /tmp/id_list_2022-06-21T19_55_08Z.txt
```
The file is timestamped as a record of when the list was generated, so that the timestamp can be used later with the `-a` option to retrieve all ids updated since the original list was generated. The `-a` option can accept the timestamp as it is formatted in the filename (with underscores or with colons).

2. Index items to new solr version, by providing the list of ids to index from the previous command
```
$ LOCAL_ENV_FILE=local_env_solr8.yml bundle exec rake migrate_solr:reindex -- -i /tmp/id_list_2022-06-21T19_55_08Z.txt

[2022-06-21T20:32:58Z] starting reindexing to http://solr8:8983/solr/blacklight-core
[2022-06-21T20:32:58Z] starting indexing of objects from list file /tmp/id_list_2022-06-21T19_55_08Z.txt

Time: 00:00:16 |                                         ᗧ| 100% (51 / 51 Δ3.19)
Indexing complete 16.742681s
```
Note: if the indexing task is interrupted, running the command again will resume from where it left off. There is a progress log sidecar file, stored at path `/tmp/id_list_2022-06-21T19_55_08Z.txt-progress.log`

To restart from scratch, you would need to delete this progress.log file. There is also a `-c` option which clears the index, but this is mainly for testing, as indexing the same item twice will simply update the solr record.

3. Generate a list of ids for objects updated since the first list was produced, then index these objects
```
$ LOCAL_ENV_FILE=local_env.yml bundle exec rake migrate_solr:list_ids -- -o /tmp -a 2022-06-21T19_55_08Z

Stored id list to file: /tmp/id_list_2022-06-22T12_43_15Z.txt

$ LOCAL_ENV_FILE=local_env_solr8.yml bundle exec rake migrate_solr:reindex -- -i /tmp/id_list_2022-06-22T12_43_15Z.txt
```

