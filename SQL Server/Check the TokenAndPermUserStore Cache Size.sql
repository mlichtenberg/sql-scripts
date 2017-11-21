-- The TokenAndPermUserStore is a cache of tokens and permissions
-- related to the currently-cached query plans.  If this cache 
-- grows too large, performance may be affected.  Most noticable
-- symptom is that the system slows down and timeouts occur.
-- Overall CPU usage will generally appear normal, but less work
-- will get done.  Most likely there will be an increase in 
-- SOS_SCHEDULER_YIELD wait types.
-- 
-- In general, if the results of this query are:
--
--		Under 10MB -> should be ok
--		Between 10MB and 50MB -> investigate
--		Over 50MB -> problem
--
-- For more information, look for Do You Have Hidden Cache Problems,
-- by Andrew J. Kelly, in SQL Server Magazine, March 2010.
--
SELECT	SUM(single_pages_kb + multi_pages_kb) AS "CurrentSizeOfTokenCache(kb)"
FROM	sys.dm_os_memory_clerks
WHERE	[name] = 'TokenAndPermUserStore'