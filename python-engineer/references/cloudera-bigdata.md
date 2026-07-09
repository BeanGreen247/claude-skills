# Cloudera / Hadoop big-data stack specialization

Deep-dive for building and running workloads on a Cloudera Data Platform
(CDP)/CDH-style cluster, and for building custom Python tooling around
it. This is the "big data mastery" half of the Cloudera specialization —
for *managing the cluster itself* via its admin API, see
[versioned-api-clients.md](versioned-api-clients.md).

As with the Cloudera Manager API guidance: this teaches durable
methodology and idiom, not a snapshot of exact current version numbers,
config defaults, or CLI flag names for a specific CDP/CDH release —
confirm those against the target cluster's actual installed version and
its official docs before relying on them.

## Spark / PySpark

- **Session setup**: one `SparkSession` per job, configured via
  `spark-submit` args / `SparkConf`, not hardcoded in application code —
  keep cluster-specific tuning (executor memory/cores, dynamic
  allocation) out of the Python source so the same job runs unmodified
  across dev/staging/prod cluster sizes.
- **DataFrame API over RDDs** for virtually all new code — the Catalyst
  optimizer and Tungsten execution engine only apply their optimizations
  to the DataFrame/SQL API, not raw RDD transformations. Drop to RDDs
  only for genuinely low-level control Catalyst can't express.
- **Avoid Python UDFs when a native/SQL expression exists** — a regular
  (non-vectorized) PySpark UDF forces row-by-row serialization between
  the JVM and a Python worker process, which is often the single biggest
  performance cliff in a PySpark job. Prefer built-in `pyspark.sql.functions`;
  if a UDF is unavoidable, use a **pandas UDF** (`@pandas_udf`, vectorized
  via Arrow) instead of a plain UDF.
- **Partitioning and shuffles**: understand where a job shuffles
  (`groupBy`, `join`, `repartition`, wide transformations) and size
  `spark.sql.shuffle.partitions` deliberately rather than leaving the
  200-partition default on both tiny and huge jobs. Watch for data skew
  (a few massively oversized partitions) as the usual cause of "one task
  never finishes" — salting keys or using `skewJoin` hints are the fix.
- **Caching**: `.cache()`/`.persist()` a DataFrame only when it's reused
  across multiple actions — caching something used once just burns
  executor memory for nothing. Unpersist when done with it in
  long-running jobs/notebooks.
- **File formats**: Parquet (columnar, predicate pushdown, schema
  evolution support) is the default choice for anything analytical;
  ORC is the traditional Hive-native alternative and still common on
  older CDH estates. Avoid CSV/JSON as the storage format for anything
  beyond small interchange files — no columnar pruning, no compression
  efficiency, fragile schema inference.
- **Resource tuning on YARN**: executor memory + `spark.yarn.executor.memoryOverhead`
  sized to avoid YARN killing containers for exceeding physical memory;
  executor count/cores balanced against the queue's YARN capacity, not
  maxed out against the whole cluster. Dynamic allocation
  (`spark.dynamicAllocation.enabled`) is usually right for shared
  multi-tenant clusters so a job doesn't hold idle executors.
- **Testing**: keep transformation logic in plain functions that take/return
  DataFrames so they're unit-testable with `pytest` + a local
  `SparkSession` (`master="local[*]"`), rather than testing only by
  submitting to a real cluster.

## Hive and Impala

- **Hive**: the batch SQL engine, backed by MapReduce/Tez/Spark execution
  engines depending on cluster config — good for large, less
  latency-sensitive batch/ETL SQL. Use `pyhive` or `impyla`
  (`impyla` also speaks Hive) or a JDBC/ODBC bridge to query from
  Python; for orchestrated pipeline SQL, prefer submitting via the
  cluster's job orchestration (Oozie/Airflow) over ad-hoc scripted
  connections where the project already has that infrastructure.
- **Impala**: MPP SQL engine for low-latency interactive queries over
  the same Hive Metastore-registered tables — same data, different
  engine, chosen for latency not throughput. `impyla` is the standard
  Python client. Impala requires `COMPUTE STATS` on tables after
  significant data changes for its cost-based optimizer to make good
  join-order decisions — a very common cause of "Impala is slow" that
  has nothing to do with the query itself.
- **Shared Metastore**: Hive and Impala (and often Spark SQL) typically
  share the Hive Metastore (HMS) as the table catalog on a Cloudera
  cluster — schema changes made through one engine are visible to the
  others, but each engine has its own query planner/optimizer, so
  performance characteristics differ even against identical tables.
- **Partitioning**: partition large Hive/Impala tables on low-cardinality,
  frequently-filtered columns (date is the classic case) — unpartitioned
  full-table scans on multi-terabyte tables are the most common
  first-week mistake.

## HDFS

- **Access from Python**: `hdfs`/`hdfs3`/`pyarrow.fs.HadoopFileSystem`
  for direct file-level access; WebHDFS REST API (via `requests` or the
  `hdfs` package's client) when you want HTTP-based access without the
  native libhdfs dependency — useful for lightweight tooling that
  shouldn't need a full Hadoop client install.
- **Small-files problem**: HDFS is optimized for large blocks (default
  128MB); a directory full of many small files degrades NameNode memory
  and read performance. Batch/compact small files (e.g. via a Spark
  `coalesce`/`repartition` write) rather than writing one file per
  record.
- **Permissions**: HDFS has a Unix-like permission model plus, on
  Kerberized clusters, real authentication — don't assume an
  unauthenticated/anonymous HDFS client will work against a production
  Cloudera cluster; see Kerberos note below.

## YARN

- **Resource model**: containers requested with memory + vCores against
  a queue; queue capacity/scheduler config (Capacity Scheduler or Fair
  Scheduler) determines how jobs share the cluster. When a job hangs in
  `ACCEPTED` state, that's almost always queue capacity/priority, not
  the job itself.
- **Programmatic interaction**: the YARN ResourceManager REST API
  (`/ws/v1/cluster/apps`, etc.) is how custom tooling queries running
  jobs, kills a stuck application, or checks queue utilization — same
  versioned-REST-API wrapping pattern as
  [versioned-api-clients.md](versioned-api-clients.md) applies directly
  here.

## Kafka

- **Client libraries**: `confluent-kafka-python` (librdkafka-backed, the
  performance-preferred choice) or `kafka-python` (pure Python, simpler
  to install, historically slower/less maintained) — prefer
  `confluent-kafka-python` for anything throughput-sensitive.
- **Consumer groups**: understand partition assignment and offset commit
  semantics (`enable.auto.commit` vs manual commit) before writing a
  consumer — auto-commit-before-processing is a common cause of silent
  data loss on consumer crash; commit after successful processing for
  at-least-once semantics.
- **Schema management**: use Avro/Protobuf with a Schema Registry
  (`confluent-kafka-python`'s `AvroSerializer` or similar) for anything
  beyond a toy pipeline — raw untyped JSON on a Kafka topic becomes an
  unversioned schema nightmare at scale.

## HBase

- **Access from Python**: `happybase` (Thrift-based, simple, widely used
  though the underlying HBase Thrift1 gateway is legacy in newer
  releases) or the REST gateway via `requests` for lighter-weight/
  cross-language access. Check what the target cluster actually exposes
  (Thrift server, REST gateway) before picking a client.
- **Row key design is the single highest-leverage HBase decision** —
  HBase only really supports efficient range scans on the row key;
  design it around the actual read pattern (and watch for
  monotonically-increasing keys like timestamps causing region
  hotspotting — salt/hash-prefix the key if writes are heavily skewed to
  one region).

## Orchestration: Oozie and Airflow

- **Oozie**: XML-workflow-based, tightly integrated with the
  Hadoop/Cloudera ecosystem, still common on older CDH estates. Python
  involvement is usually indirect (generating/templating the workflow
  XML, or calling the Oozie REST API to submit/monitor jobs).
- **Airflow**: the modern default for new pipeline orchestration,
  including on Cloudera-adjacent stacks — DAGs are plain Python, and
  there are first-class operators/hooks for Spark, Hive, HDFS, and
  Kafka. Prefer Airflow over new Oozie workflows for anything greenfield;
  don't migrate an entire working Oozie estate without a specific reason
  and the user's buy-in.

## Kerberos and security

- Cloudera clusters are very commonly Kerberized. Python clients
  connecting to HDFS/Hive/Impala/HBase/YARN need a valid Kerberos
  ticket (`kinit` beforehand, or `python-gssapi`/`requests-kerberos` for
  SPNEGO-authenticated HTTP endpoints like WebHDFS or the YARN/Cloudera
  Manager REST APIs). A client that "can't connect" or gets silent
  auth failures against a Cloudera cluster is very often a Kerberos
  ticket/keytab issue before it's a code issue — check that first.
- Never embed keytabs or Kerberos credentials in source control; read
  keytab paths from config/environment and handle ticket renewal
  (`kinit -R` on a timer, or a scheduled renewal job) for long-running
  processes rather than assuming a single `kinit` lasts forever.

## Putting it together: a typical custom Cloudera tool

A real "custom web tool for env management" on this stack is usually a
composite of pieces already covered:

1. A typed client wrapping the Cloudera Manager API for cluster/service
   status and admin actions (`versioned-api-clients.md`).
2. Direct engine clients (`impyla`, `pyhive`, `happybase`, WebHDFS) for
   data-plane queries the dashboard needs to show (row counts, job
   status, recent partitions).
3. A thin FastAPI/Flask layer (`frameworks.md`) presenting both as one
   dashboard/API, with Kerberos-aware auth end to end.
4. Background polling (APScheduler/Celery) for anything that queries a
   YARN/Oozie/Airflow job's async status rather than blocking a request
   on it.
