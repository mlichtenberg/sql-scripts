SELECT  objtype AS [Cache Store Type]
       ,COUNT_BIG(*) AS [Total Plans]
       ,SUM(CAST(size_in_bytes AS DECIMAL(14,2))) / 1048576 AS [Total MBs]
       ,AVG(usecounts) AS [Avg Use Count]
       ,SUM(CASE WHEN usecounts = 1 THEN 1
                 ELSE 0
            END) AS [Total Plans - USE Count 1]
       ,SUM(CAST(( CASE WHEN usecounts = 1 THEN size_in_bytes
                        ELSE 0
                   END ) AS DECIMAL(14,2))) / 1048576 AS [Total MBs - USE Count 1]
FROM    sys.dm_exec_cached_plans
GROUP BY objtype
ORDER BY [Total MBs - USE Count 1] DESC

 DECLARE @AdHocSizeInMB DECIMAL(14,2)
   ,@TotalSizeInMB DECIMAL(14,2)

 SELECT  @AdHocSizeInMB = SUM(CAST(( CASE WHEN usecounts = 1
                                              AND LOWER(objtype) = 'adhoc'
                                         THEN size_in_bytes
                                         ELSE 0
                                    END ) AS DECIMAL(14,2))) / 1048576
       ,@TotalSizeInMB = SUM(CAST (size_in_bytes AS DECIMAL(14,2))) / 1048576
FROM    sys.dm_exec_cached_plans 

 SELECT  @AdHocSizeInMB AS [Total MBs - USE Count 1]
       ,@TotalSizeInMB AS [Total MBs - entire cache]
       ,CAST(( @AdHocSizeInMB / @TotalSizeInMB ) * 100 AS DECIMAL(14,2)) AS [% of cache occupied by adhoc plans only used once]

IF @AdHocSizeInMB > 200
    OR ( ( @AdHocSizeInMB / @TotalSizeInMB ) * 100 ) > 25  -- 200MB or > 25%
    SELECT  'Switch on Optimize for Ad hoc Workloads as it will make a significant difference' AS [Recommendation]
ELSE 
    SELECT  'Setting Optimize for Ad hoc Workloads will make little difference' AS [Recommendation]
GO 

/*
-- BHL Values 9/16/2015 (Optimize for Ad hoc Workloads not set)

Cache Store Type	Total Plans	Total MBs	Avg Use Count	Total Plans - USE Count 1	Total MBs - USE Count 1
Adhoc				14155		3213.664062	1				12941						2701.945312
Proc				1017		370.101562	63516			120							31.921875
Prepared			119			17.812500	537				25							3.273437
Trigger				21			4.367187	52				4							0.531250
Check				58			2.500000	151				8							0.281250
View				196			20.929687	110				0							0.000000
UsrTab				20			0.851562	301				0							0.000000

Total MBs - USE Count 1	Total MBs - entire cache	% of cache occupied by adhoc plans only used once
2701.95					3630.41						74.43

Recommendation
Switch on Optimize for Ad hoc Workloads as it will make a significant difference
*/

