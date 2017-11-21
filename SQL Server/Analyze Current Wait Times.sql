IF NOT EXISTS(SELECT id FROM tempdb.dbo.sysobjects WHERE [name] like '#waits%')
BEGIN
	-- Get starting statistics
	CREATE TABLE #Waits(
		WaitType nvarchar(60) NOT NULL,
		WaitTime bigint NULL,
		[%Waiting] decimal(12, 2) NULL,
		MonitorDate datetime NOT NULL
	)

	INSERT INTO #Waits
	SELECT 
		wait_type,
		wait_time_ms / 1000,
		CONVERT(DECIMAL(12,2), wait_time_ms * 100.0 / SUM(wait_time_ms) OVER()),
		GETDATE()
	FROM sys.dm_os_wait_stats
	WHERE wait_type NOT LIKE '%SLEEP%'
END

-- Get the current stats and the percent change since the initial capture
SELECT	NEW.WaitType, 
		NEW.WaitTime AS NewWaitTime,
		NEW.[%Waiting] AS [New%Waiting],
		OLD.WaitTime AS OldWaitTime,
		OLD.[%Waiting] AS [Old%Waiting],
		NEW.WaitTime - OLD.WaitTime AS Change
INTO	#tmpStats
FROM	(
		SELECT	WaitType = wait_type,
				WaitTime = wait_time_ms / 1000,
				[%Waiting] = CONVERT(DECIMAL(12,2), wait_time_ms * 100.0 / SUM(wait_time_ms) OVER())
		FROM	sys.dm_os_wait_stats
		WHERE	wait_type NOT LIKE '%SLEEP%'
		) NEW
		INNER JOIN 
		(
		SELECT	WaitType, WaitTime, [%Waiting] FROM #Waits
		) OLD
			ON NEW.WaitType = OLD.WaitType

DECLARE @totalchange DECIMAL(10, 2)
SELECT @totalchange = SUM(change) FROM #tmpStats

SELECT	*,
		CASE WHEN @TotalChange > 0 
		THEN CONVERT(DECIMAL(10, 2), CONVERT(DECIMAL(10,2), change) / @totalchange * 100)
		ELSE 0 
		END AS [%WaitingSinceStart]
FROM	#tmpStats
ORDER BY [%WaitingSinceStart] DESC

DROP TABLE #tmpStats

-- DROP TABLE #Waits
