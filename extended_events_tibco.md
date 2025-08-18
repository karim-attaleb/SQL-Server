CREATE EVENT SESSION [TibcoQueryCapture_Username] ON DATABASE
ADD EVENT sqlserver.sql_statement_completed(
    SET collect_statement=(1)
    ACTION(
        sqlserver.client_app_name,
        sqlserver.client_hostname,
        sqlserver.database_name,
        sqlserver.session_id,
        sqlserver.sql_text,
        sqlserver.username,
        sqlserver.plan_handle,
        sqlserver.query_hash,
        sqlserver.query_plan_hash
    )
    WHERE (
        [sqlserver].[username] = N'YOUR_TIBCO_USERNAME'
        AND [duration] > 100000  -- 100ms in microseconds
    )
),
ADD EVENT sqlserver.sql_batch_completed(
    SET collect_batch_text=(1)
    ACTION(
        sqlserver.client_app_name,
        sqlserver.client_hostname,
        sqlserver.database_name,
        sqlserver.session_id,
        sqlserver.sql_text,
        sqlserver.username,
        sqlserver.plan_handle,
        sqlserver.query_hash,
        sqlserver.query_plan_hash
    )
    WHERE (
        [sqlserver].[username] = N'YOUR_TIBCO_USERNAME'
        AND [duration] > 100000
    )
),
ADD EVENT sqlserver.rpc_completed(
    ACTION(
        sqlserver.client_app_name,
        sqlserver.client_hostname,
        sqlserver.database_name,
        sqlserver.session_id,
        sqlserver.sql_text,
        sqlserver.username,
        sqlserver.plan_handle,
        sqlserver.query_hash,
        sqlserver.query_plan_hash
    )
    WHERE (
        [sqlserver].[username] = N'YOUR_TIBCO_USERNAME'
        AND [duration] > 100000
    )
)
ADD TARGET package0.event_file(
    SET filename='TibcoQueryCapture_Username.xel',
        max_file_size=(50),  -- 50MB per file
        max_rollover_files=(10)  -- Keep 10 files (500MB total)
)
WITH (
    MAX_MEMORY=64 MB,  -- Within Azure SQL DB limits
    EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY=30 SECONDS,
    MAX_EVENT_SIZE=0 KB,
    MEMORY_PARTITION_MODE=NONE,
    TRACK_CAUSALITY=ON,
    STARTUP_STATE=ON
);
GO

ALTER EVENT SESSION [TibcoQueryCapture_Username] ON DATABASE STATE = START;
GO

SELECT 
    s.name AS session_name,
    s.create_time,
    s.total_buffer_size / 1024.0 / 1024.0 AS buffer_size_mb,
    s.dropped_event_count,
    s.dropped_buffer_count
FROM sys.dm_xe_database_sessions s
WHERE s.name = 'TibcoQueryCapture_Username';
GO

/*
SELECT DISTINCT 
    s.login_name,
    s.original_login_name,
    DB_NAME(s.database_id) AS database_name,
    s.program_name,
    s.host_name,
    s.client_interface_name,
    COUNT(*) AS session_count
FROM sys.dm_exec_sessions s
WHERE s.database_id = DB_ID()  -- Current database
    AND s.is_user_process = 1
    AND s.login_name NOT LIKE '%##%'  -- Exclude system accounts
GROUP BY s.login_name, s.original_login_name, s.database_id, s.program_name, s.host_name, s.client_interface_name
ORDER BY session_count DESC;
*/
