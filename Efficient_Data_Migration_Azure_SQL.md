
# Efficient Data Migration to Azure SQL Database

## Overview

As a SQL DBA, migrating large volumes of data to **Azure SQL Database** requires careful planning, performance tuning, and use of the right tools. This guide summarizes best practices, recommended tools, and optimization strategies for ensuring efficient and resilient data migration.

---

## ✅ Recommended Data Migration Methods

### 1. Azure Data Factory (ADF) – *Best for recurring pipelines*

- Built-in connectors for structured/unstructured sources
- Supports incremental loads
- Monitored, retryable pipelines
- Ideal for Parquet, JSON, CSV, etc.
- Supports parallel loading

### 2. BCP (Bulk Copy Program) – *Ideal for high-throughput one-time loads*

```bash
bcp MyTable in "data.csv" -n -S "server.database.windows.net" -U "user" -P "pass" -d "targetdb" -b 10000 -a 16384
```

- High performance with `-n`, `-b`, and `-a` options
- Efficient for local-to-Azure SQL migrations

### 3. SQL Server Integration Services (SSIS)

- Use Azure-SSIS Integration Runtime for cloud-native execution
- Best when complex transformation logic is required

### 4. Azure Database Migration Service (DMS)

- Handles schema and data
- Supports minimal downtime (for lift-and-shift)
- Good for comprehensive migrations from on-prem SQL Server

---

## 🚀 Performance Optimization Tips

- **Batching**: Use 50,000–100,000 rows per batch
- **Staging Tables**: Load into staging first, then merge
- **Disable Indexes**: Temporarily disable/rebuild non-clustered indexes
- **Scale DTUs/Service Tier**: Increase during migration
- **Use Partitioning**: For large tables >100GB

---

## 📦 Loading Data While Keeping Tables Online

### 1. Partition Switching *(Zero-downtime method)*

```sql
-- Create staging table with identical structure
SELECT * INTO dbo.Customers_Staging FROM dbo.Customers WHERE 1 = 0;

-- Load data into staging, then switch
ALTER TABLE dbo.Customers_Staging SWITCH TO dbo.Customers PARTITION 1;
```

### 2. Batch Inserts with `TABLOCK` Hint

```sql
INSERT INTO dbo.OnlineTable WITH (TABLOCK)
SELECT * FROM StagingTable WHERE ID BETWEEN @Start AND @End;
```

### 3. MERGE with Batches

```sql
WHILE EXISTS (SELECT 1 FROM StagingTable)
BEGIN
  BEGIN TRAN;
  MERGE INTO dbo.OnlineTable AS t
  USING (SELECT TOP 10000 * FROM StagingTable) AS s
  ON t.Key = s.Key
  WHEN NOT MATCHED THEN INSERT ...;
  DELETE TOP (10000) FROM StagingTable;
  COMMIT;
  WAITFOR DELAY '00:00:00.1';
END
```

### 4. Isolation & Transaction Management

- Use `READ_COMMITTED_SNAPSHOT` to avoid locking
- Use small batches to reduce blocking

---

## ⚙️ Resource Allocation Strategies

### 1. Scale Up Temporarily

```bash
az sql db update --resource-group YourRG --server yourserver \
--name YourDB --service-objective P2
```

### 2. Use Resource Governor (Advanced)

```sql
CREATE WORKLOAD GROUP BulkLoadGroup ...;
CREATE FUNCTION dbo.BulkLoadClassifier() RETURNS SYSNAME AS ...
ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = dbo.BulkLoadClassifier);
ALTER RESOURCE GOVERNOR RECONFIGURE;
```

### 3. Load Throttling with Batches

```sql
INSERT INTO TargetTable WITH (TABLOCK)
SELECT TOP (5000) * FROM SourceTable WHERE NOT EXISTS (...);
WAITFOR DELAY '00:00:00.1';
```

---

## 🧠 Handling Failures & Resource Limits

### What Happens on Hitting Resource Limits?

| Limit | Behavior | Action |
|-------|----------|--------|
| DTU/CPU | Throttling / Error 10928 | Scale up, reduce batch |
| Log Space | Rollback (Error 9002) | Load smaller batches |
| Memory | Abort (Error 8651) | Reduce batch size |
| Threads | Connection refused | Lower parallelism |

### Retry & Resume Techniques

```csharp
while (retryCount < 3)
{
  try { conn.Open(); break; }
  catch (SqlException ex) when (ex.Number == 40501 || ex.Number == 10928)
  { retryCount++; Thread.Sleep(1000 * retryCount * retryCount); }
}
```

---

## 🔄 BULK INSERT vs. BCP

| Feature | BULK INSERT | BCP |
|---------|-------------|-----|
| Transactional Control | Full (T-SQL) | Limited |
| Native Format Support | No | Yes |
| Parallelism | Single-threaded | Multi-threaded |
| Retry Logic | Custom | None |
| File Types | CSV, Azure Blob | Native (w/ -n) |

### Recommendation:
- **Use BCP** for native `.dat` loads from local disk
- **Use BULK INSERT** when loading from Azure Blob with control

---

## 🧬 Non-Native File Formats (CSV, Parquet)

### Option 1: Azure Data Factory (Parquet/JSON/CSV)

```json
{
  "name": "CopyParquetToSQL",
  "typeProperties": {
    "source": { "type": "ParquetSource" },
    "sink": {
      "type": "SqlSink",
      "writeBatchSize": 10000,
      "preCopyScript": "TRUNCATE TABLE staging.MyTable"
    },
    "parallelCopies": 4
  }
}
```

### Option 2: PolyBase (Fastest for Parquet)

```sql
INSERT INTO dbo.TargetTable
SELECT * FROM OPENROWSET(
  BULK 'file.parquet',
  DATA_SOURCE = 'MyBlob',
  FORMAT = 'PARQUET'
) AS data;
```

### Option 3: Spark + JDBC (Azure Databricks/Synapse)

```python
df = spark.read.parquet("path/to/file")
df.write.format("jdbc").option("url", "...").option("dbtable", "...").save()
```

---

## 📚 Additional Learning

- **Microsoft Learn**: Data integration and pipeline tutorials
- **ADF Labs**: Hands-on experience with ADF pipelines
- **Common Patterns**: Incremental loading, SCD, error handling
