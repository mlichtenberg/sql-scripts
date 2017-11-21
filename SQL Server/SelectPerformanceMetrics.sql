DROP PROCEDURE SelectPerformanceMetrics
GO

CREATE PROCEDURE SelectPerformanceMetrics

@LastRestart DATETIME

AS
BEGIN

/*******************************************************************************************************

					SQL SERVER 2005 - Tell me your secrets!

********************************************************************************************************

	Description: Report on the current performance health status of a SQL Server 2005 server using non-instrusive methods.

	Purpose: Identify areas where the database server as a whole can be improved, using data collected 
			 by SQL Server itself. Many of these items apply to the database server as a whole, rather 
			 than specific queries. 

	Author: Ian Stirk (Ian_Stirk@yahoo.com).

	Date: June 2007.

	Notes: This collection of SQL inspects various DMVs, this information can be used to highlight
		   what areas of the SQL Server sever can be improved. The following items are reported on:
  
				1. Causes of the server waits
				2. Databases using the most IO
				3. Count of missing indexes, by database
				4. Most important missing indexes
				5. Unused Indexes
				6. Most costly indexes (high maintenance)
				7. Most used indexes
				8. Most fragmented indexes
				9. Most costly queries, by average IO
				10. Most costly queries, by average CPU
				11. Most costly CLR queries, by average CLR time
				12. Most executed queries
				13. Queries suffering most from blocking
				14. Queries with the lowest plan reuse

********************************************************************************************************

PRE-REQUISITE
1. Best to have as much DMV data as possible (When last rebooted? Want daily? weekly, monthly, quarterly results).
2. Output HSR to Grid? Text? File? Table? Reporting Services? If set results to text, get the actual sprocs in output.
3. Decide if want to put results in a database? Later analysis, historical comparisons, impact of month-end, quarter etc. 
4. Decide if want to run the defrag code, can be expensive.
5. Decide if want to iterate over all databases for a specific aspect (e.g. average IO).


FOLLOW-UP (After running this routine's SQL)
1. Investigative work, use dba_SearchDB/dba_SearchDBServer for analysis.
2. Demonstrate/measure the improvement: Find underlying queries, apply change, run stats IO ON, see execuation plan.
3. SQL Server Best Practices Analyzer.


INTRUSIVE INSPECTION (Follow-up and corollary to this work)
1. Trace typical workload (day, monthend? etc)
2. Reduce recorded queries to query signatures (Ben-Gan's method)
3. Calculate the total duration for similar query patterns
4. Tune the most important query patterns in DTA, then apply recommended indexes/stats.

*********************************************************************************************************/

SET NOCOUNT ON

DECLARE @Date DATETIME
SET @Date = CONVERT(DATETIME, CONVERT(NVARCHAR(20), GETDATE(), 111))

-- Do not lock anything, and do not get held up by any locks. 
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

INSERT Diag00
SELECT @Date, @LastRestart


--SELECT 'Identify what is causing the waits.' AS [Step01];
/************************************************************************************/
/* STEP01.																			*/
/* Purpose: Identify what is causing the waits.										*/
/* Notes: 1.																		*/
/************************************************************************************/
INSERT Diag01Waits
SELECT TOP 20
	[Wait type] = wait_type,
	[Wait time (s)] = wait_time_ms / 1000,
	[% waiting] = CONVERT(DECIMAL(12,2), wait_time_ms * 100.0 / SUM(wait_time_ms) OVER()),
	@Date
FROM sys.dm_os_wait_stats
WHERE wait_type NOT LIKE '%SLEEP%' 
ORDER BY wait_time_ms DESC;


--SELECT 'Identify what databases are reading the most logical pages.' AS [Step02a];
/************************************************************************************/
/* STEP02a.																			*/
/* Purpose: Identify what databases are reading the most logical pages.				*/
/* Notes : 1. This should highlight the databases to target for best improvement.	*/
/*		   2. Watch out for tempDB, a high value is suggestive.						*/	
/************************************************************************************/
-- Total reads by DB
INSERT Diag02aMostPageReads
SELECT [Total Reads] = SUM(total_logical_reads)
		,[Execution count] = SUM(qs.execution_count)
		,DatabaseName = DB_NAME(qt.dbid),
		@Date
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
GROUP BY DB_NAME(qt.dbid)
ORDER BY [Total Reads] DESC;


--SELECT 'Identify what databases are writing the most logical pages.' AS [Step02b];
/************************************************************************************/
/* STEP02b.																			*/
/* Purpose: Identify what databases are writing the most logical pages.				*/
/* Notes : 1. This should highlight the databases to target for best improvement.	*/
/*		   2. Watch out for tempDB, a high value is suggestive.						*/	
/************************************************************************************/
-- Total Writes by DB
INSERT Diag02bMostPageWrites
SELECT  [Total Writes] = SUM(total_logical_writes)
		,[Execution count] = SUM(qs.execution_count)
		,DatabaseName = DB_NAME(qt.dbid),
		@Date
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
GROUP BY DB_NAME(qt.dbid)
ORDER BY [Total Writes] DESC;


--SELECT 'Count of missing indexes, by databases.' AS [Step03];
/************************************************************************** ******************/
/* STEP03.																			*/
/* Purpose: Identify the number of missing (or incomplete indexes), across ALL databases.	 */
/* Notes : 1. This should highlight the databases to target for best improvement.			 */
/*********************************************************************************************/
INSERT Diag03MissingIndexCount
SELECT 
	DatabaseName = DB_NAME(database_id)
	,[Number Indexes Missing] = count(*),
	@Date
FROM sys.dm_db_missing_index_details
GROUP BY DB_NAME(database_id)
ORDER BY 2 DESC;


--SELECT 'Identify the missing indexes (TOP 10), across ALL databases.' AS [Step04];
/****************************************************************************************************/
/* STEP04.																			*/
/* Purpose: Identify the missing (or incomplete indexes) (TOP 20), for ALL databases.				*/
/* Notes : 1. Could combine above with number of reads/writes a DB has since reboot, but this takes */
/*		   into account how often index could have been used, and estimates a 'realcost'			*/
/****************************************************************************************************/
INSERT Diag04MissingIndexDetail
SELECT	[Total Cost]  = ROUND(avg_total_user_cost * avg_user_impact * (user_seeks + user_scans),0) 
		, avg_user_impact -- Query cost would reduce by this amount, on average.
		, DatabaseName = db_name(database_id)
		, TableName = statement
		, [EqualityUsage] = equality_columns 
		, [InequalityUsage] = inequality_columns
		, [Include Columns] = included_columns
		,@Date
FROM		sys.dm_db_missing_index_groups g 
INNER JOIN	sys.dm_db_missing_index_group_stats s ON s.group_handle = g.index_group_handle 
INNER JOIN	sys.dm_db_missing_index_details d ON d.index_handle = g.index_handle
ORDER BY [Total Cost] DESC;


--SELECT 'Identify which indexes are not being used, across ALL databases.' AS [Step05];
/*******************************************************************************************************/
/* STEP05.																			*/
/* Purpose: Identify which indexes are not being used, for a given database.							*/
/* Notes: 1. These will have a deterimental impact on any updates/deletions.							*/
/*		  Remove if possible (can see the updates in user_updates and system_updates fields)			*/
/*		  2. Systems means DBCC commands, DDL commands, or update statistics - so can typically ignore.	*/
/*		  3. The template below uses the sp_MSForEachDB, this is because joining on sys.databases		*/
/*			gives incorrect results (due to sys.indexes taking into account the current database only).	*/ 	
/********************************************************************************************************/
-- Create required table structure only.
-- Note: this SQL must be the same as in the Database loop given in following step.
SELECT TOP 1
		DatabaseName = DB_NAME()
		,TableName = OBJECT_NAME(s.[object_id])
		,IndexName = i.name
		,user_updates	
		,system_updates	
INTO #TempUnusedIndexes
FROM   sys.dm_db_index_usage_stats s 
INNER JOIN sys.indexes i ON  s.[object_id] = i.[object_id] 
    AND s.index_id = i.index_id 
WHERE  s.database_id = DB_ID()
    AND OBJECTPROPERTY(s.[object_id], 'IsMsShipped') = 0
	AND	user_seeks = 0
	AND user_scans = 0 
	AND user_lookups = 0
	-- Below may not be needed, they tend to reflect creation of stats, backups etc...
--	AND	system_seeks = 0
--	AND system_scans = 0
--	AND system_lookups = 0
	AND s.[object_id] = -999  -- Dummy value, just to get table structure.
;

-- Loop around all the databases on the server.
EXEC sp_MSForEachDB	'USE [?]; 
-- Table already exists.
INSERT INTO #TempUnusedIndexes 
SELECT	DatabaseName = DB_NAME()
		,TableName = OBJECT_NAME(s.[object_id])
		,IndexName = i.name
		,user_updates	
		,system_updates	
		-- Useful fields below:
		--, *
FROM   sys.dm_db_index_usage_stats s 
INNER JOIN sys.indexes i ON  s.[object_id] = i.[object_id] 
    AND s.index_id = i.index_id 
WHERE  s.database_id = DB_ID()
    AND OBJECTPROPERTY(s.[object_id], ''IsMsShipped'') = 0
	AND	user_seeks = 0
	AND user_scans = 0 
	AND user_lookups = 0
    AND i.name IS NOT NULL	-- I.e. Ignore HEAP indexes.
	-- Below may not be needed, they tend to reflect creation of stats, backups etc...
--	AND	system_seeks = 0
--	AND system_scans = 0
--	AND system_lookups = 0
ORDER BY user_updates DESC
;
'

-- Select records.
INSERT Diag05UnusedIndexes
SELECT *, @Date
FROM #TempUnusedIndexes 
ORDER BY [user_updates]  DESC
-- Tidy up.
DROP TABLE #TempUnusedIndexes


--SELECT 'Identify which indexes are the most high maintenance (TOP 10), across ALL databases.' AS [Step06];
/********************************************************************************************************/
/* STEP06.																			*/
/* Purpose: Identify which indexes are the most high maintenance (TOP 10), for a given database.		*/
/* Notes: 1. These indexes are updated the most, may want to review if the are necessary.				*/
/*        2. Another version shows writes per read.								  						*/
/*		  3. Systems means DBCC commands, DDL commands, or update statistics - so can typically ignore. */
/*		  4. The template below uses the sp_MSForEachDB, this is because joining on sys.databases		*/
/*			gives incorrect results (due to sys.indexes taking into account the current database only).	*/ 	
/********************************************************************************************************/
-- Create required table structure only.
-- Note: this SQL must be the same as in the Database loop given in following step.
SELECT TOP 1
		[Maintenance cost]  = (user_updates + system_updates)
		,[Retrieval usage] = (user_seeks + user_scans + user_lookups)
		,DatabaseName = DB_NAME()
		,TableName = OBJECT_NAME(s.[object_id])
		,IndexName = i.name
		-- Useful fields below:
--		,user_updates  
--		,system_updates
--		,user_seeks 
--		,user_scans 
--		,user_lookups 
--		,system_seeks 
--		,system_scans 
--		,system_lookups 
INTO #TempMaintenanceCost
FROM   sys.dm_db_index_usage_stats s 
INNER JOIN sys.indexes i ON  s.[object_id] = i.[object_id] 
    AND s.index_id = i.index_id
WHERE s.database_id = DB_ID() 
    AND OBJECTPROPERTY(s.[object_id], 'IsMsShipped') = 0
	AND (user_updates + system_updates) > 0 -- Only report on active rows.
	AND s.[object_id] = -999  -- Dummy value, just to get table structure.
;

-- Loop around all the databases on the server.
EXEC sp_MSForEachDB	'USE [?]; 
-- Table already exists.
INSERT INTO #TempMaintenanceCost 
SELECT	[Maintenance cost]  = (user_updates + system_updates)
		,[Retrieval usage] = (user_seeks + user_scans + user_lookups)
		,DatabaseName = DB_NAME()
		,TableName = OBJECT_NAME(s.[object_id])
		,IndexName = i.name
		-- Useful fields below:
--		,user_updates  
--		,system_updates
--		,user_seeks 
--		,user_scans 
--		,user_lookups 
--		,system_seeks 
--		,system_scans 
--		,system_lookups 
		-- Useful fields below:
--		,*
FROM   sys.dm_db_index_usage_stats s 
INNER JOIN sys.indexes i ON  s.[object_id] = i.[object_id] 
    AND s.index_id = i.index_id
WHERE s.database_id = DB_ID() 
    AND i.name IS NOT NULL	-- I.e. Ignore HEAP indexes.
    AND OBJECTPROPERTY(s.[object_id], ''IsMsShipped'') = 0
	AND (user_updates + system_updates) > 0 -- Only report on active rows.
ORDER BY [Maintenance cost]  DESC
;
'

-- Select records.
INSERT Diag06HighMaintIndexes
SELECT *, @Date
FROM #TempMaintenanceCost 
ORDER BY [Maintenance cost]  DESC
-- Tidy up.
DROP TABLE #TempMaintenanceCost


--SELECT 'Identify which indexes are the most often used (TOP 10), across ALL databases.' AS [Step07];
/********************************************************************************************************/
/* STEP07.																			*/
/* Purpose: Identify which indexes are the most used (TOP 10), for a given database.		     		*/
/* Notes: 1. These indexes are updated the most, may want to review if the are necessary.		   		*/
/*		  2. Systems means DBCC commands, DDL commands, or update statistics - so can typically ignore. */
/*		  3. Ensure Statistics are up-to-date for these.						 						*/
/*		  4. The template below uses the sp_MSForEachDB, this is because joining on sys.databases		*/
/*			gives incorrect results (due to sys.indexes taking into account the current database only).	*/ 	
/********************************************************************************************************/

-- Create required table structure only.
-- Note: this SQL must be the same as in the Database loop given in following step.
SELECT TOP 1
		[Usage] = (user_seeks + user_scans + user_lookups)
		,DatabaseName = DB_NAME()
		,TableName = OBJECT_NAME(s.[object_id])
		,IndexName = i.name
		-- Useful fields below:
--		,user_updates  
--		,system_updates
--		,user_seeks 
--		,user_scans 
--		,user_lookups 
--		,system_seeks 
--		,system_scans 
--		,system_lookups 
		-- Useful fields below:
		--, *
INTO #TempUsage
FROM   sys.dm_db_index_usage_stats s 
INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id] 
    AND s.index_id = i.index_id 
WHERE   s.database_id = DB_ID() 
    AND OBJECTPROPERTY(s.[object_id], 'IsMsShipped') = 0
	AND (user_seeks + user_scans + user_lookups) > 0 -- Only report on active rows.
	AND s.[object_id] = -999  -- Dummy value, just to get table structure.
;

-- Loop around all the databases on the server.
EXEC sp_MSForEachDB	'USE [?]; 
-- Table already exists.
INSERT INTO #TempUsage 
SELECT
		[Usage] = (user_seeks + user_scans + user_lookups)
		,DatabaseName = DB_NAME()
		,TableName = OBJECT_NAME(s.[object_id])
		,IndexName = i.name
		-- Useful fields below:
--		,user_updates  
--		,system_updates
--		,user_seeks 
--		,user_scans 
--		,user_lookups 
--		,system_seeks 
--		,system_scans 
--		,system_lookups 
		-- Useful fields below:
		--, *
FROM   sys.dm_db_index_usage_stats s 
INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id] 
    AND s.index_id = i.index_id 
WHERE   s.database_id = DB_ID() 
    AND i.name IS NOT NULL	-- I.e. Ignore HEAP indexes.
    AND OBJECTPROPERTY(s.[object_id], ''IsMsShipped'') = 0
	AND (user_seeks + user_scans + user_lookups) > 0 -- Only report on active rows.
ORDER BY [Usage]  DESC
;
'

-- Select records.
INSERT Diag07MostUsedIndexes
SELECT *, @Date
FROM #TempUsage 
ORDER BY [Usage] DESC
-- Tidy up.
DROP TABLE #TempUsage


--SELECT 'Identify which indexes are the most logically fragmented (TOP 10), across ALL databases.' AS [Step08];
/********************************************************************************************/
/* STEP08.																			*/
/* Purpose: Identify which indexes are the most fragmented (TOP 10), for a given database.  */
/* Notes: 1. Defragmentation increases IO.													*/
/********************************************************************************************/
-- Create required table structure only.
-- Note: this SQL must be the same as in the Database loop given in following step.
SELECT TOP 1 
		DatbaseName = DB_NAME()
		,TableName = OBJECT_NAME(s.[object_id])
		,IndexName = i.name
		,[Fragmentation %] = ROUND(avg_fragmentation_in_percent,2)
		-- Useful fields below:
		--, *
INTO #TempFragmentation
FROM sys.dm_db_index_physical_stats(db_id(),null, null, null, null) s
INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id] 
    AND s.index_id = i.index_id 
WHERE s.[object_id] = -999  -- Dummy value, just to get table structure.
;

-- Loop around all the databases on the server.
BEGIN TRY
	EXEC sp_MSForEachDB	'USE [?]; 
	-- Table already exists.
	INSERT INTO #TempFragmentation 
	SELECT	DatbaseName = DB_NAME()
			,TableName = OBJECT_NAME(s.[object_id])
			,IndexName = i.name
			,[Fragmentation %] = ROUND(avg_fragmentation_in_percent,2)
			-- Useful fields below:
			--, *
	FROM sys.dm_db_index_physical_stats(db_id(),null, null, null, null) s
	INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id] 
		AND s.index_id = i.index_id 
	WHERE s.database_id = DB_ID() 
		  AND i.name IS NOT NULL	-- I.e. Ignore HEAP indexes.
		AND OBJECTPROPERTY(s.[object_id], ''IsMsShipped'') = 0
		AND avg_fragmentation_in_percent >= 10
	ORDER BY [Fragmentation %] DESC
	;
	'
END TRY
BEGIN CATCH
	-- Do nothing
END CATCH

-- Select records.
INSERT Diag08MostFragmentedIndexes
SELECT *, @Date
FROM #TempFragmentation 
ORDER BY [Fragmentation %] DESC
-- Tidy up.
DROP TABLE #TempFragmentation


--SELECT 'Identify which (cached plan) queries are the most costly by average IO (TOP 10), across ALL databases.' AS [Step09];
/****************************************************************************************************/
/* STEP09.																			*/
/* Purpose: Identify which queries are the most costly by IO (TOP 10), across ALL databases.	    */
/* Notes: 1. This could be areas that need optimisation, maybe they crosstab with missing indexes?  */
/*		  2. Decide if average or total is more important.											*/
/****************************************************************************************************/
INSERT Diag09MostCostlyPlansIO
SELECT TOP 100
        [Average IO] = (total_logical_reads + total_logical_writes) / qs.execution_count
		,[Total IO] = (total_logical_reads + total_logical_writes)
		,[Execution count] = qs.execution_count
        ,[Individual Query] = SUBSTRING (qt.text,qs.statement_start_offset/2, 
         (CASE WHEN qs.statement_end_offset = -1 
			THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) 
		,[Parent Query] = qt.text
		,DatabaseName = DB_NAME(qt.dbid)
		,@Date
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
WHERE DB_NAME(qt.dbid) IS NOT NULL -- Filter on a given database.
ORDER BY [Average IO] DESC;


--SELECT 'Identify which (cached plan) queries are the most costly by average CPU (TOP 10), across ALL databases.' AS [Step10];
/****************************************************************************************************/
/* STEP10.																			*/
/* Purpose: Identify which queries are the most costly by CPU (TOP 10), across ALL databases.	    */
/* Notes: 1. This could be areas that need optimisation, maybe they crosstab with missing indexes?  */
/*		  2. Decide if average or total is more important.						    */
/****************************************************************************************************/
INSERT Diag10MostCostlyPlansCPU
SELECT TOP 100 
		[Average CPU used] = total_worker_time / qs.execution_count
		,[Total CPU used] = total_worker_time
		,[Execution count] = qs.execution_count
        ,[Individual Query] = SUBSTRING (qt.text,qs.statement_start_offset/2, 
         (CASE WHEN qs.statement_end_offset = -1 
			THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)
		,[Parent Query] = qt.text
		,DatabaseName = DB_NAME(qt.dbid)
		,@Date
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
WHERE DB_NAME(qt.dbid) IS NOT NULL -- Filter on a given database.
ORDER BY [Average CPU used] DESC;


--SELECT 'Identify which CLR queries, use the most average CLR time (TOP 10), across ALL databases.' AS [Step11];
/****************************************************************************************************/
/* STEP011.																			*/
/* Purpose: Identify which CLR queries, use the most avg CLR time (TOP 10), across ALL databases.   */
/* Notes: 1. Decide if average or total is more important.											*/
/****************************************************************************************************/
INSERT Diag11MostCostlyPlansCLR
SELECT TOP 100 
		[Average CLR Time] = total_clr_time / execution_count 
		,[Total CLR Time] = total_clr_time 
		,[Execution count] = qs.execution_count
        ,[Individual Query] = SUBSTRING (qt.text,qs.statement_start_offset/2, 
         (CASE WHEN qs.statement_end_offset = -1 
			THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)
		,[Parent Query] = qt.text
		,DatabaseName = DB_NAME(qt.dbid)
		,@Date
FROM sys.dm_exec_query_stats as qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
WHERE total_clr_time <> 0
AND DB_NAME(qt.dbid) IS NOT NULL -- Filter on a given database.
ORDER BY [Average CLR Time] DESC;


--SELECT 'Identify which (cached plan) queries are executed most often (TOP 10), across ALL databases.' AS [Step12];
/********************************************************************************************/
/* STEP12.																			*/
/* Purpose: Identify which queries are executed most often (TOP 10), across ALL databases.  */
/* Notes: 1. These should be optimised. Ensure Statistics are up to date.					*/
/********************************************************************************************/
INSERT Diag12MostOftenUsedPlans
SELECT TOP 100 
		[Execution count] = execution_count
        ,[Individual Query] = SUBSTRING (qt.text,qs.statement_start_offset/2, 
         (CASE WHEN qs.statement_end_offset = -1 
			THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)
		,[Parent Query] = qt.text
		,DatabaseName = DB_NAME(qt.dbid)
		,@Date
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
WHERE DB_NAME(qt.dbid) IS NOT NULL -- Filter on a given database.
ORDER BY [Execution count] DESC;


--SELECT 'Identify which (cached plan) queries suffer the most from blocking (TOP 10), across ALL databases.' AS [Step13];
/****************************************************************************************************/
/* STEP13.																			*/
/* Purpose: Identify which queries suffer the most from blocking (TOP 10), across ALL databases.    */
/* Notes: 1. This may have an impact on ALL queries.												*/
/*		  2. Decide if average or total is more important.											*/
/****************************************************************************************************/
INSERT Diag13MostBlockedPlans
SELECT TOP 100 
		[Average Time Blocked] = (total_elapsed_time - total_worker_time) / qs.execution_count
		,[Total Time Blocked] = total_elapsed_time - total_worker_time 
		,[Execution count] = qs.execution_count
        ,[Individual Query] = SUBSTRING (qt.text,qs.statement_start_offset/2, 
         (CASE WHEN qs.statement_end_offset = -1 
			THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) 
		,[Parent Query] = qt.text
		,DatabaseName = DB_NAME(qt.dbid)
		,@Date
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
WHERE DB_NAME(qt.dbid) IS NOT NULL -- Filter on a given database.
ORDER BY [Average Time Blocked] DESC;


--SELECT 'What (cached plan) queries have the lowest plan reuse (Top 10), across ALL databases.' AS [Step14];
/************************************************************************************/
/* STEP14.																			*/
/* What queries, in the current database, have the lowest plan reuse (Top 10).		*/
/* Notes: 1.                              											*/
/************************************************************************************/
INSERT Diag14LowestPlanReuse
SELECT TOP 100
        [Plan usage] = cp.usecounts
        ,[Individual Query] = SUBSTRING (qt.text,qs.statement_start_offset/2, 
         (CASE WHEN qs.statement_end_offset = -1 
			THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)
		,[Parent Query] = qt.text
		,DatabaseName = DB_NAME(qt.dbid)
        ,cp.cacheobjtype
		,@Date
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
INNER JOIN sys.dm_exec_cached_plans as cp on qs.plan_handle=cp.plan_handle
WHERE cp.plan_handle=qs.plan_handle
AND DB_NAME(qt.dbid) IS NOT NULL  -- Filter on a given database.
ORDER BY [Plan usage] ASC;


-- MIGHT BE USEFUL
/*


/* ALTERNATIVE. */
SELECT 'Identify what indexes have a high maintenance cost.' AS [Step];
/* Purpose: Identify what indexes have a high maintenance cost. */
/* Notes : 1. This version shows writes per read, another version shows total updates without reads. */
SELECT 	TOP 10
		DatabaseName = DB_NAME()
		,TableName = OBJECT_NAME(s.[object_id])
		,IndexName = i.name
		,[Writes per read (User)] = user_updates / CASE WHEN (user_seeks + user_scans + user_lookups) = 0 
															THEN 1 
													   ELSE (user_seeks + user_scans + user_lookups) 
												   END 
		,[User writes] = user_updates
		,[User reads] = user_seeks + user_scans + user_lookups
		,[System writes] = system_updates
		,[System reads] = system_seeks + system_scans + system_lookups
		-- Useful fields below:
		--, *
FROM   sys.dm_db_index_usage_stats s 
		, sys.indexes i 
WHERE   s.[object_id] = i.[object_id] 
    AND s.index_id = i.index_id 
    AND s.database_id = DB_ID()
    AND OBJECTPROPERTY(s.[object_id], 'IsMsShipped') = 0
ORDER BY [Writes per read (User)] DESC;


-- Total Reads by most expensive IO query
SELECT TOP 10 
        [Total Reads] = total_logical_reads
		,[Total Writes] = total_logical_writes
		,[Execution count] = qs.execution_count
        ,[Individual Query] = SUBSTRING (qt.text,qs.statement_start_offset/2, 
         (CASE WHEN qs.statement_end_offset = -1 
			THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) 
		,[Parent Query] = qt.text
		,DatabaseName = DB_NAME(qt.dbid)
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
ORDER BY [Total Reads] DESC;

-- Total Writes by most expensive IO query
SELECT TOP 10 
		[Total Writes] = total_logical_writes
        ,[Total Reads] = total_logical_reads
		,[Execution count] = qs.execution_count
        ,[Individual Query] = SUBSTRING (qt.text,qs.statement_start_offset/2, 
         (CASE WHEN qs.statement_end_offset = -1 
			THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)
		,[Parent Query] = qt.text
		,DatabaseName = DB_NAME(qt.dbid)
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
ORDER BY [Total Writes] DESC;




-- Most reused queries...
SELECT TOP 10 
		[Run count] = usecounts
		,[Query] = text
		,DatabaseName = DB_NAME(qt.dbid)
		,*
FROM sys.dm_exec_cached_plans cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) as qt
--AND DB_NAME(qt.dbid) = 'pnl'  -- Filter on a given database.
ORDER BY 1 DESC;

-- The below does not give the same values as previosu step, maybe related to 
-- individual qry within the parent qry? 
SELECT TOP 10 
		[Run count] = usecounts
        ,[Individual Query] = SUBSTRING (qt.text,qs.statement_start_offset/2, 
         (CASE WHEN qs.statement_end_offset = -1 
			THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)
		,[Parent Query] = qt.text
		,DatabaseName = DB_NAME(qt.dbid)
		,*
FROM sys.dm_exec_cached_plans cp
INNER JOIN sys.dm_exec_query_stats qs ON cp.plan_handle = qs.plan_handle
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) as qt
--AND DB_NAME(qt.dbid) = 'pnl'  -- Filter on a given database.
ORDER BY 1 DESC;

*/

END
GO