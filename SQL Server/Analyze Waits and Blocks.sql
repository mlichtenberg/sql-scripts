-- Waits
SELECT tx.[text] AS [Executing SQL], wt.session_id, wt.wait_duration_ms, wt.wait_type, 
       wt.resource_address, wt.blocking_session_id, wt.resource_description
FROM sys.dm_os_waiting_tasks AS wt INNER JOIN sys.dm_exec_connections AS ec
        ON wt.session_id = ec.session_id
CROSS APPLY
       (SELECT * FROM sys.dm_exec_sql_text(ec.most_recent_sql_handle)) AS tx
WHERE wt.session_id > 50 AND wt.wait_duration_ms > 0

-- Blocking
SELECT
              Blocked.Session_ID AS Blocked_Session_ID
       , Blocked_SQL.text AS Blocked_SQL
       , waits.wait_type AS Blocked_Resource
       , Blocking.Session_ID AS Blocking_Session_ID
       , Blocking_SQL.text AS Blocking_SQL
        , GETDATE()
FROM sys.dm_exec_connections AS Blocking INNER JOIN sys.dm_exec_requests AS Blocked
       ON Blocked.Blocking_Session_ID = Blocking.Session_ID
CROSS APPLY
       (
              SELECT * FROM sys.dm_exec_sql_text(Blocking.most_recent_sql_handle)
       ) AS Blocking_SQL
CROSS APPLY
       (
              SELECT * FROM sys.dm_exec_sql_text(Blocked.sql_handle)
       ) AS Blocked_SQL
INNER JOIN sys.dm_os_waiting_tasks AS waits 
       ON waits.Session_ID = Blocked.Session_ID

