-- http://social.msdn.microsoft.com/Forums/en-US/sqldatabaseengine/thread/e2ddf26f-f86c-4368-b4a7-17b2b7c64aa5/
--
-- If you are seeing lots of SOS_SCHEDULER_YIELD in your Wait States, that is a 
-- very stong indicator of CPU pressure. 
--
-- Use the following query to check SQL Server Schedulers to see if they are 
-- waiting on CPU.
-- 
-- If you see the runnable tasks count above zero, that is cause for concern, 
-- and if you see it in double digits for any length of time, that is cause for 
-- extreme concern! 
SELECT scheduler_id, current_tasks_count, runnable_tasks_count
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255 