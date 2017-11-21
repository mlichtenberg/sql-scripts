/*
http://blogs.msdn.com/grahamk/archive/2009/02/03/compilation-bottlenecks-error-8628-severity-17-state-0-part-1.aspx
http://blogs.msdn.com/grahamk/archive/2009/02/11/compilation-bottlenecks-error-8628-severity-17-state-0-part-2.aspx

http://weblogs.asp.net/omarzabir/archive/2007/10/19/a-significant-part-of-sql-server-process-memory-has-been-paged-out-this-may-result-in-performance-degradation.aspx
http://blogs.msdn.com/psssql/archive/2007/05/31/the-sql-server-working-set-message.aspx



Check Event Log on SERV11 for the following:

A significant part of sql server process memory has been paged out. This 
may result in a performance degradation. Duration: 0 seconds. Working 
set (KB): 1538396, committed (KB): 3217432, memory utilization: 47%%.
*/

-- View plan cache
select usecounts, cacheobjtype, objtype, bucketid, text 
from sys.dm_exec_cached_plans cp cross apply 
sys.dm_exec_sql_text(cp.plan_handle) 
where cacheobjtype = 'Compiled Plan' 
order by objtype 

-- Look for high granted and used memory... to view query plan, click on xml, 
-- save as .sqlplan, and open in SSMS
select text, query_plan, requested_memory_kb, granted_memory_kb, used_memory_kb 
from sys.dm_exec_query_memory_grants MG
CROSS APPLY sys.dm_exec_sql_text(sql_handle)  t
CROSS APPLY sys.dm_exec_query_plan(MG.plan_handle) 


----------------------------------------------------------------
-- Determine memory conditions on the server (run when working set is paged out)
SELECT CONVERT (varchar(30), GETDATE(), 121) as runtime,
DATEADD (ms, -1 * ((sys.cpu_ticks / sys.cpu_ticks_in_ms) - a.[Record Time]), GETDATE()) AS Notification_time,  
 a.* , sys.ms_ticks AS [Current Time]
 FROM 
 (SELECT x.value('(//Record/ResourceMonitor/Notification)[1]', 'varchar(30)') AS [Notification_type], 
 x.value('(//Record/MemoryRecord/MemoryUtilization)[1]', 'bigint') AS [MemoryUtilization %], 
 x.value('(//Record/MemoryRecord/TotalPhysicalMemory)[1]', 'bigint') AS [TotalPhysicalMemory_KB], 
 x.value('(//Record/MemoryRecord/AvailablePhysicalMemory)[1]', 'bigint') AS [AvailablePhysicalMemory_KB], 
 x.value('(//Record/MemoryRecord/TotalPageFile)[1]', 'bigint') AS [TotalPageFile_KB], 
 x.value('(//Record/MemoryRecord/AvailablePageFile)[1]', 'bigint') AS [AvailablePageFile_KB], 
 x.value('(//Record/MemoryRecord/TotalVirtualAddressSpace)[1]', 'bigint') AS [TotalVirtualAddressSpace_KB], 
 x.value('(//Record/MemoryRecord/AvailableVirtualAddressSpace)[1]', 'bigint') AS [AvailableVirtualAddressSpace_KB], 
 x.value('(//Record/MemoryNode/@id)[1]', 'bigint') AS [Node Id], 
 x.value('(//Record/MemoryNode/ReservedMemory)[1]', 'bigint') AS [SQL_ReservedMemory_KB], 
 x.value('(//Record/MemoryNode/CommittedMemory)[1]', 'bigint') AS [SQL_CommittedMemory_KB], 
 x.value('(//Record/@id)[1]', 'bigint') AS [Record Id], 
 x.value('(//Record/@type)[1]', 'varchar(30)') AS [Type], 
 x.value('(//Record/ResourceMonitor/Indicators)[1]', 'bigint') AS [Indicators], 
 x.value('(//Record/@time)[1]', 'bigint') AS [Record Time]
 FROM (SELECT CAST (record as xml) FROM sys.dm_os_ring_buffers 
 WHERE ring_buffer_type = 'RING_BUFFER_RESOURCE_MONITOR') AS R(x)) a 
CROSS JOIN sys.dm_os_sys_info sys
ORDER BY a.[Record Time] ASC

----------------------------------------------------------------

select * from master.dbo.sysperfinfo where counter_name like '%server memory%'

----------------------------------------------------------------

-- http://support.microsoft.com/kb/907877/en-us
dbcc memorystatus

/*  BASELINE OUTPUT

Memory Manager                  KB 
------------------------------ --------------------
VM Reserved                    8184312
VM Committed                   3423008
AWE Allocated                  0
Reserved Memory                1024
Reserved Memory In Use         0

(5 row(s) affected)

Memory node Id = 0              KB 
------------------------------ --------------------
VM Reserved                    8178552
VM Committed                   3417336
AWE Allocated                  0
MultiPage Allocator            20000
SinglePage Allocator           109512

(5 row(s) affected)

MEMORYCLERK_SQLGENERAL (Total)                                    KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            3312
 MultiPage Allocator                                             4864

(7 row(s) affected)

MEMORYCLERK_SQLBUFFERPOOL (Total)                                 KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     8097792
 VM Committed                                                    3337376
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            0
 MultiPage Allocator                                             32

(7 row(s) affected)

MEMORYCLERK_SQLQUERYEXEC (Total)                                  KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            16
 MultiPage Allocator                                             0

(7 row(s) affected)

MEMORYCLERK_SQLOPTIMIZER (Total)                                  KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            3144
 MultiPage Allocator                                             96

(7 row(s) affected)

MEMORYCLERK_SQLUTILITIES (Total)                                  KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     120
 VM Committed                                                    120
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            208
 MultiPage Allocator                                             0

(7 row(s) affected)

MEMORYCLERK_SQLSTORENG (Total)                                    KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     51136
 VM Committed                                                    51136
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            3560
 MultiPage Allocator                                             1072

(7 row(s) affected)

MEMORYCLERK_SQLCONNECTIONPOOL (Total)                             KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            1944
 MultiPage Allocator                                             0

(7 row(s) affected)

MEMORYCLERK_SQLCLR (Total)                                        KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

MEMORYCLERK_SQLSERVICEBROKER (Total)                              KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            144
 MultiPage Allocator                                             320

(7 row(s) affected)

MEMORYCLERK_SQLHTTP (Total)                                       KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

MEMORYCLERK_SNI (Total)                                           KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            240
 MultiPage Allocator                                             16

(7 row(s) affected)

MEMORYCLERK_FULLTEXT (Total)                                      KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            16
 MultiPage Allocator                                             0

(7 row(s) affected)

MEMORYCLERK_SQLXP (Total)                                         KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            16
 MultiPage Allocator                                             0

(7 row(s) affected)

MEMORYCLERK_HOST (Total)                                          KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            168
 MultiPage Allocator                                             144

(7 row(s) affected)

MEMORYCLERK_SOSNODE (Total)                                       KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            7888
 MultiPage Allocator                                             12432

(7 row(s) affected)

MEMORYCLERK_SQLSERVICEBROKERTRANSPORT (Total)                     KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            48
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_OBJCP (Total)                                          KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            32288
 MultiPage Allocator                                             368

(7 row(s) affected)

CACHESTORE_SQLCP (Total)                                          KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            30656
 MultiPage Allocator                                             256

(7 row(s) affected)

CACHESTORE_PHDR (Total)                                           KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            5648
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_XPROC (Total)                                          KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            16
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_TEMPTABLES (Total)                                     KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            16
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_NOTIF (Total)                                          KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            16
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_VIEWDEFINITIONS (Total)                                KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            240
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_XMLDBTYPE (Total)                                      KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_XMLDBELEMENT (Total)                                   KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_XMLDBATTRIBUTE (Total)                                 KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_STACKFRAMES (Total)                                    KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            0
 MultiPage Allocator                                             8

(7 row(s) affected)

CACHESTORE_BROKERTBLACS (Total)                                   KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            112
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_BROKERKEK (Total)                                      KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_BROKERDSH (Total)                                      KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_BROKERUSERCERTLOOKUP (Total)                           KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_BROKERRSB (Total)                                      KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_BROKERREADONLY (Total)                                 KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            32
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_BROKERTO (Total)                                       KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_EVENTS (Total)                                         KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            16
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_SYSTEMROWSET (Total)                                   KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            1216
 MultiPage Allocator                                             0

(7 row(s) affected)

USERSTORE_SCHEMAMGR (Total)                                       KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            6112
 MultiPage Allocator                                             0

(7 row(s) affected)

USERSTORE_DBMETADATA (Total)                                      KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            2600
 MultiPage Allocator                                             0

(7 row(s) affected)

USERSTORE_TOKENPERM (Total)                                       KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            3040
 MultiPage Allocator                                             0

(7 row(s) affected)

USERSTORE_OBJPERM (Total)                                         KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            1048
 MultiPage Allocator                                             0

(7 row(s) affected)

USERSTORE_SXC (Total)                                             KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            304
 MultiPage Allocator                                             0

(7 row(s) affected)

OBJECTSTORE_LBSS (Total)                                          KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            32
 MultiPage Allocator                                             160

(7 row(s) affected)

OBJECTSTORE_SNI_PACKET (Total)                                    KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            2776
 MultiPage Allocator                                             48

(7 row(s) affected)

OBJECTSTORE_SERVICE_BROKER (Total)                                KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            272
 MultiPage Allocator                                             0

(7 row(s) affected)

OBJECTSTORE_LOCK_MANAGER (Total)                                  KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     8192
 VM Committed                                                    8192
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            2248
 MultiPage Allocator                                             0

(7 row(s) affected)

Buffer Distribution            Buffers
------------------------------ -----------
Stolen                         2596
Free                           502
Cached                         11093
Database (clean)               392658
Database (dirty)               1766
I/O                            0
Latched                        13

(7 row(s) affected)

Buffer Counts                  Buffers
------------------------------ --------------------
Committed                      408628
Target                         408628
Hashed                         394437
Stolen Potential               463882
External Reservation           0
Min Free                       200
Visible                        408628
Available Paging File          332055

(8 row(s) affected)

Procedure Cache                Value
------------------------------ -----------
TotalProcs                     417
TotalPages                     8654
InUsePages                     10

(3 row(s) affected)

 
Global Memory Objects          Buffers
------------------------------ --------------------
Resource                       426
Locks                          284
XDES                           69
SETLS                          2
SE Dataset Allocators          4
SubpDesc Allocators            2
SE SchemaManager               763
SQLCache                       216
Replication                    2
ServerGlobal                   51
XP Global                      2
SortTables                     2

(12 row(s) affected)

 
Query Memory Objects           Value
------------------------------ -----------
Grants                         0
Waiting                        0
Available (Buffers)            294265
Maximum (Buffers)              294265
Limit                          294265
Next Request                   0
Waiting For                    0
Cost                           0
Timeout                        0
Wait Time                      0
Last Target                    307065

(11 row(s) affected)

Small Query Memory Objects     Value
------------------------------ -----------
Grants                         0
Waiting                        0
Available (Buffers)            12800
Maximum (Buffers)              12800
Limit                          12800

(5 row(s) affected)

Optimization Queue             Value
------------------------------ --------------------
Overall Memory                 2683183104
Target Memory                  2485354496
Last Notification              1
Timeout                        6
Early Termination Factor       5

(5 row(s) affected)

Small Gateway                  Value
------------------------------ --------------------
Configured Units               8
Available Units                8
Acquires                       0
Waiters                        0
Threshold Factor               380000
Threshold                      380000

(6 row(s) affected)

Medium Gateway                 Value
------------------------------ --------------------
Configured Units               2
Available Units                2
Acquires                       0
Waiters                        0
Threshold Factor               12

(5 row(s) affected)

Big Gateway                    Value
------------------------------ --------------------
Configured Units               1
Available Units                1
Acquires                       0
Waiters                        0
Threshold Factor               8

(5 row(s) affected)

MEMORYBROKER_FOR_CACHE           Value
-------------------------------- --------------------
Allocations                      11083
Rate                             159
Target Allocations               312049
Future Allocations               0
Last Notification                1

(5 row(s) affected)

MEMORYBROKER_FOR_STEAL           Value
-------------------------------- --------------------
Allocations                      2592
Rate                             -11
Target Allocations               303388
Future Allocations               0
Last Notification                1

(5 row(s) affected)

MEMORYBROKER_FOR_RESERVE         Value
-------------------------------- --------------------
Allocations                      0
Rate                             -404
Target Allocations               327537
Future Allocations               73566
Last Notification                1

(5 row(s) affected)

DBCC execution completed. If DBCC printed error messages, contact your system administrator.
*/


--**************************************************************


/*  OUTPUT 8:00AM 2009-06-05

Memory Manager                  KB 
------------------------------ --------------------
VM Reserved                    8190128
VM Committed                   4181456
AWE Allocated                  0
Reserved Memory                1024
Reserved Memory In Use         0

(5 row(s) affected)

Memory node Id = 0              KB 
------------------------------ --------------------
VM Reserved                    8184368
VM Committed                   4175784
AWE Allocated                  0
MultiPage Allocator            25360
SinglePage Allocator           525656

(5 row(s) affected)

MEMORYCLERK_SQLGENERAL (Total)                                    KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            4344
 MultiPage Allocator                                             4864

(7 row(s) affected)

MEMORYCLERK_SQLBUFFERPOOL (Total)                                 KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     8097792
 VM Committed                                                    4090008
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            0
 MultiPage Allocator                                             32

(7 row(s) affected)

MEMORYCLERK_SQLQUERYEXEC (Total)                                  KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            3208
 MultiPage Allocator                                             3072

(7 row(s) affected)

MEMORYCLERK_SQLOPTIMIZER (Total)                                  KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            10152
 MultiPage Allocator                                             264

(7 row(s) affected)

MEMORYCLERK_SQLUTILITIES (Total)                                  KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     240
 VM Committed                                                    240
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            208
 MultiPage Allocator                                             0

(7 row(s) affected)

MEMORYCLERK_SQLSTORENG (Total)                                    KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     51136
 VM Committed                                                    51136
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            3808
 MultiPage Allocator                                             1072

(7 row(s) affected)

MEMORYCLERK_SQLCONNECTIONPOOL (Total)                             KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            2304
 MultiPage Allocator                                             0

(7 row(s) affected)

MEMORYCLERK_SQLCLR (Total)                                        KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

MEMORYCLERK_SQLSERVICEBROKER (Total)                              KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            144
 MultiPage Allocator                                             320

(7 row(s) affected)

MEMORYCLERK_SQLHTTP (Total)                                       KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

MEMORYCLERK_SNI (Total)                                           KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            240
 MultiPage Allocator                                             16

(7 row(s) affected)

MEMORYCLERK_FULLTEXT (Total)                                      KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            16
 MultiPage Allocator                                             0

(7 row(s) affected)

MEMORYCLERK_SQLXP (Total)                                         KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            16
 MultiPage Allocator                                             0

(7 row(s) affected)

MEMORYCLERK_BHF (Total)                                           KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            120
 MultiPage Allocator                                             0

(7 row(s) affected)

MEMORYCLERK_SQLQERESERVATIONS (Total)                             KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            763600
 MultiPage Allocator                                             0

(7 row(s) affected)

MEMORYCLERK_HOST (Total)                                          KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            168
 MultiPage Allocator                                             144

(7 row(s) affected)

MEMORYCLERK_SOSNODE (Total)                                       KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            10696
 MultiPage Allocator                                             12432

(7 row(s) affected)

MEMORYCLERK_SQLSERVICEBROKERTRANSPORT (Total)                     KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            48
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_OBJCP (Total)                                          KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            63336
 MultiPage Allocator                                             1040

(7 row(s) affected)

CACHESTORE_SQLCP (Total)                                          KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            393344
 MultiPage Allocator                                             1592

(7 row(s) affected)

CACHESTORE_PHDR (Total)                                           KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            10280
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_XPROC (Total)                                          KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            24
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_TEMPTABLES (Total)                                     KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            24
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_NOTIF (Total)                                          KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            16
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_VIEWDEFINITIONS (Total)                                KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            240
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_XMLDBTYPE (Total)                                      KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_XMLDBELEMENT (Total)                                   KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_XMLDBATTRIBUTE (Total)                                 KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_STACKFRAMES (Total)                                    KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            0
 MultiPage Allocator                                             8

(7 row(s) affected)

CACHESTORE_BROKERTBLACS (Total)                                   KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            112
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_BROKERKEK (Total)                                      KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_BROKERDSH (Total)                                      KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_BROKERUSERCERTLOOKUP (Total)                           KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_BROKERRSB (Total)                                      KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_BROKERREADONLY (Total)                                 KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            32
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_BROKERTO (Total)                                       KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            8
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_EVENTS (Total)                                         KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            16
 MultiPage Allocator                                             0

(7 row(s) affected)

CACHESTORE_SYSTEMROWSET (Total)                                   KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            1496
 MultiPage Allocator                                             0

(7 row(s) affected)

USERSTORE_SCHEMAMGR (Total)                                       KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            6424
 MultiPage Allocator                                             0

(7 row(s) affected)

USERSTORE_DBMETADATA (Total)                                      KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            3424
 MultiPage Allocator                                             0

(7 row(s) affected)

USERSTORE_TOKENPERM (Total)                                       KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            3440
 MultiPage Allocator                                             0

(7 row(s) affected)

USERSTORE_OBJPERM (Total)                                         KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            1040
 MultiPage Allocator                                             0

(7 row(s) affected)

USERSTORE_SXC (Total)                                             KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            1024
 MultiPage Allocator                                             0

(7 row(s) affected)

OBJECTSTORE_LBSS (Total)                                          KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            32
 MultiPage Allocator                                             272

(7 row(s) affected)

OBJECTSTORE_SNI_PACKET (Total)                                    KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            3312
 MultiPage Allocator                                             48

(7 row(s) affected)

OBJECTSTORE_SERVICE_BROKER (Total)                                KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     0
 VM Committed                                                    0
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            272
 MultiPage Allocator                                             0

(7 row(s) affected)

OBJECTSTORE_LOCK_MANAGER (Total)                                  KB 
---------------------------------------------------------------- --------------------
 VM Reserved                                                     8192
 VM Committed                                                    8192
 AWE Allocated                                                   0
 SM Reserved                                                     0
 SM Commited                                                     0
 SinglePage Allocator                                            2184
 MultiPage Allocator                                             0

(7 row(s) affected)

Buffer Distribution            Buffers
------------------------------ -----------
Stolen                         8120
Free                           172
Cached                         60953
Database (clean)               432590
Database (dirty)               835
I/O                            0
Latched                        37

(7 row(s) affected)

Buffer Counts                  Buffers
------------------------------ --------------------
Committed                      502707
Target                         502707
Hashed                         433157
Stolen Potential               316410
External Reservation           91785
Min Free                       174
Visible                        502707
Available Paging File          217078

(8 row(s) affected)

Procedure Cache                Value
------------------------------ -----------
TotalProcs                     2367
TotalPages                     58677
InUsePages                     737

(3 row(s) affected)

 
Global Memory Objects          Buffers
------------------------------ --------------------
Resource                       426
Locks                          276
XDES                           84
SETLS                          2
SE Dataset Allocators          4
SubpDesc Allocators            2
SE SchemaManager               802
SQLCache                       345
Replication                    2
ServerGlobal                   51
XP Global                      2
SortTables                     2

(12 row(s) affected)

 
Query Memory Objects           Value
------------------------------ -----------
Grants                         12
Waiting                        0
Available (Buffers)            269510
Maximum (Buffers)              364960
Limit                          364960
Next Request                   0
Waiting For                    0
Cost                           0
Timeout                        0
Wait Time                      0
Last Target                    377760

(11 row(s) affected)

Small Query Memory Objects     Value
------------------------------ -----------
Grants                         0
Waiting                        0
Available (Buffers)            12800
Maximum (Buffers)              12800
Limit                          12800

(5 row(s) affected)

Optimization Queue             Value
------------------------------ --------------------
Overall Memory                 3300950016
Target Memory                  2630959104
Last Notification              1
Timeout                        6
Early Termination Factor       5

(5 row(s) affected)

Small Gateway                  Value
------------------------------ --------------------
Configured Units               8
Available Units                2
Acquires                       6
Waiters                        0
Threshold Factor               380000
Threshold                      380000

(6 row(s) affected)

Medium Gateway                 Value
------------------------------ --------------------
Configured Units               2
Available Units                2
Acquires                       0
Waiters                        0
Threshold Factor               12
Threshold                      36541098

(6 row(s) affected)

Big Gateway                    Value
------------------------------ --------------------
Configured Units               1
Available Units                1
Acquires                       0
Waiters                        0
Threshold Factor               8

(5 row(s) affected)

MEMORYBROKER_FOR_CACHE           Value
-------------------------------- --------------------
Allocations                      60873
Rate                             333
Target Allocations               377950
Future Allocations               0
Last Notification                1

(5 row(s) affected)

MEMORYBROKER_FOR_STEAL           Value
-------------------------------- --------------------
Allocations                      4483
Rate                             -65
Target Allocations               321162
Future Allocations               0
Last Notification                1

(5 row(s) affected)

MEMORYBROKER_FOR_RESERVE         Value
-------------------------------- --------------------
Allocations                      94974
Rate                             229
Target Allocations               402948
Future Allocations               91240
Last Notification                1

(5 row(s) affected)

DBCC execution completed. If DBCC printed error messages, contact your system administrator.

*/


/*
-- Low memory conditions on server after Max Memory Setting updated

runtime                        Notification_time       Notification_type              MemoryUtilization %  TotalPhysicalMemory_KB AvailablePhysicalMemory_KB TotalPageFile_KB     AvailablePageFile_KB TotalVirtualAddressSpace_KB AvailableVirtualAddressSpace_KB Node Id              SQL_ReservedMemory_KB SQL_CommittedMemory_KB Record Id            Type                           Indicators           Record Time          Current Time
------------------------------ ----------------------- ------------------------------ -------------------- ---------------------- -------------------------- -------------------- -------------------- --------------------------- ------------------------------- -------------------- --------------------- ---------------------- -------------------- ------------------------------ -------------------- -------------------- --------------------
2009-06-23 08:48:04.250        2009-06-23 08:05:31.223 RESOURCE_MEM_STEADY            100                  4021656                56092                      6388120              1986208              8589934464                  8581537088                      0                    8154936               3335488                62420                RING_BUFFER_RESOURCE_MONITOR   0                    225912659            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.237 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                56008                      6388120              1986264              8589934464                  8581537088                      0                    8154936               3335488                62421                RING_BUFFER_RESOURCE_MONITOR   2                    225912672            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.240 RESOURCE_MEM_STEADY            100                  4021656                56020                      6388120              1986316              8589934464                  8581537088                      0                    8154936               3335400                62422                RING_BUFFER_RESOURCE_MONITOR   0                    225912674            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.280 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55984                      6388120              1986328              8589934464                  8581537088                      0                    8154936               3335392                62423                RING_BUFFER_RESOURCE_MONITOR   2                    225912713            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.280 RESOURCE_MEM_STEADY            100                  4021656                56168                      6388120              1986528              8589934464                  8581537088                      0                    8154936               3335192                62424                RING_BUFFER_RESOURCE_MONITOR   0                    225912713            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.297 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55984                      6388120              1986496              8589934464                  8581537088                      0                    8154936               3335192                62425                RING_BUFFER_RESOURCE_MONITOR   2                    225912730            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.297 RESOURCE_MEM_STEADY            100                  4021656                56040                      6388120              1986552              8589934464                  8581537088                      0                    8154936               3335136                62426                RING_BUFFER_RESOURCE_MONITOR   0                    225912730            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.297 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55972                      6388120              1986436              8589934464                  8581537088                      0                    8154936               3335136                62427                RING_BUFFER_RESOURCE_MONITOR   2                    225912732            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.297 RESOURCE_MEM_STEADY            100                  4021656                56168                      6388120              1986632              8589934464                  8581537088                      0                    8154936               3334936                62428                RING_BUFFER_RESOURCE_MONITOR   0                    225912732            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.327 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1986564              8589934464                  8581537088                      0                    8154936               3334936                62429                RING_BUFFER_RESOURCE_MONITOR   2                    225912761            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.327 RESOURCE_MEM_STEADY            100                  4021656                56152                      6388120              1986740              8589934464                  8581537088                      0                    8154936               3334736                62430                RING_BUFFER_RESOURCE_MONITOR   0                    225912761            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.357 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1986704              8589934464                  8581537088                      0                    8154936               3334736                62431                RING_BUFFER_RESOURCE_MONITOR   2                    225912791            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.357 RESOURCE_MEM_STEADY            100                  4021656                56188                      6388120              1986904              8589934464                  8581537088                      0                    8154936               3334536                62432                RING_BUFFER_RESOURCE_MONITOR   0                    225912791            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.390 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55932                      6388120              1986648              8589934464                  8581537088                      0                    8154936               3334536                62433                RING_BUFFER_RESOURCE_MONITOR   2                    225912824            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.390 RESOURCE_MEM_STEADY            100                  4021656                56032                      6388120              1986848              8589934464                  8581537088                      0                    8154936               3334336                62434                RING_BUFFER_RESOURCE_MONITOR   0                    225912825            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.390 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55976                      6388120              1986848              8589934464                  8581537088                      0                    8154936               3334336                62435                RING_BUFFER_RESOURCE_MONITOR   2                    225912825            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.393 RESOURCE_MEM_STEADY            100                  4021656                56224                      6388120              1987040              8589934464                  8581537088                      0                    8154936               3334136                62436                RING_BUFFER_RESOURCE_MONITOR   0                    225912826            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.453 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55956                      6388120              1986928              8589934464                  8581536960                      0                    8155064               3334256                62437                RING_BUFFER_RESOURCE_MONITOR   2                    225912888            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.457 RESOURCE_MEM_STEADY            100                  4021656                56100                      6388120              1987096              8589934464                  8581536896                      0                    8155128               3334088                62438                RING_BUFFER_RESOURCE_MONITOR   0                    225912892            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.653 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55952                      6388120              1987088              8589934464                  8581537088                      0                    8154936               3333936                62439                RING_BUFFER_RESOURCE_MONITOR   2                    225913087            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.657 RESOURCE_MEM_STEADY            100                  4021656                56172                      6388120              1987284              8589934464                  8581537088                      0                    8154936               3333736                62440                RING_BUFFER_RESOURCE_MONITOR   0                    225913091            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.687 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55956                      6388120              1987284              8589934464                  8581537088                      0                    8154936               3333736                62441                RING_BUFFER_RESOURCE_MONITOR   2                    225913122            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.690 RESOURCE_MEM_STEADY            100                  4021656                56132                      6388120              1987484              8589934464                  8581537088                      0                    8154936               3333536                62442                RING_BUFFER_RESOURCE_MONITOR   0                    225913125            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.697 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55936                      6388120              1987420              8589934464                  8581537088                      0                    8154936               3333536                62443                RING_BUFFER_RESOURCE_MONITOR   2                    225913132            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.700 RESOURCE_MEM_STEADY            100                  4021656                56072                      6388120              1987620              8589934464                  8581537088                      0                    8154936               3333336                62444                RING_BUFFER_RESOURCE_MONITOR   0                    225913135            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.707 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55968                      6388120              1987740              8589934464                  8581537088                      0                    8154936               3333336                62445                RING_BUFFER_RESOURCE_MONITOR   2                    225913142            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.710 RESOURCE_MEM_STEADY            100                  4021656                56100                      6388120              1987892              8589934464                  8581537088                      0                    8154936               3333136                62446                RING_BUFFER_RESOURCE_MONITOR   0                    225913145            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.730 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55984                      6388120              1987956              8589934464                  8581537088                      0                    8154936               3333136                62447                RING_BUFFER_RESOURCE_MONITOR   2                    225913163            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.730 RESOURCE_MEM_STEADY            100                  4021656                56040                      6388120              1988036              8589934464                  8581536576                      0                    8154936               3333064                62448                RING_BUFFER_RESOURCE_MONITOR   0                    225913165            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.733 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55976                      6388120              1988036              8589934464                  8581537088                      0                    8154936               3333056                62449                RING_BUFFER_RESOURCE_MONITOR   2                    225913167            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.733 RESOURCE_MEM_STEADY            100                  4021656                55996                      6388120              1988076              8589934464                  8581537088                      0                    8154936               3333016                62450                RING_BUFFER_RESOURCE_MONITOR   0                    225913169            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.737 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55960                      6388120              1988084              8589934464                  8581537088                      0                    8154936               3333008                62451                RING_BUFFER_RESOURCE_MONITOR   2                    225913172            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:31.753 RESOURCE_MEM_STEADY            100                  4021656                56020                      6388120              1988252              8589934464                  8581537088                      0                    8154936               3332864                62452                RING_BUFFER_RESOURCE_MONITOR   0                    225913186            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:32.043 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1986696              8589934464                  8581537088                      0                    8154936               3332864                62453                RING_BUFFER_RESOURCE_MONITOR   2                    225913479            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:32.070 RESOURCE_MEM_STEADY            100                  4021656                56152                      6388120              1986896              8589934464                  8581537088                      0                    8154936               3332664                62454                RING_BUFFER_RESOURCE_MONITOR   0                    225913503            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:32.107 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55984                      6388120              1986816              8589934464                  8581537088                      0                    8154936               3332664                62455                RING_BUFFER_RESOURCE_MONITOR   2                    225913542            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:32.170 RESOURCE_MEM_STEADY            100                  4021656                56184                      6388120              1987016              8589934464                  8581537088                      0                    8154936               3332464                62456                RING_BUFFER_RESOURCE_MONITOR   0                    225913605            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.313 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55928                      6388120              1988168              8589934464                  8581537088                      0                    8154936               3329272                62457                RING_BUFFER_RESOURCE_MONITOR   2                    225914747            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.317 RESOURCE_MEM_STEADY            100                  4021656                56108                      6388120              1988368              8589934464                  8581537088                      0                    8154936               3329072                62458                RING_BUFFER_RESOURCE_MONITOR   0                    225914750            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.407 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55968                      6388120              1988436              8589934464                  8581537088                      0                    8154936               3329072                62459                RING_BUFFER_RESOURCE_MONITOR   2                    225914841            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.410 RESOURCE_MEM_STEADY            100                  4021656                56168                      6388120              1988636              8589934464                  8581537088                      0                    8154936               3328872                62460                RING_BUFFER_RESOURCE_MONITOR   0                    225914845            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.443 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55968                      6388120              1988676              8589934464                  8581537088                      0                    8154936               3328872                62461                RING_BUFFER_RESOURCE_MONITOR   2                    225914877            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.443 RESOURCE_MEM_STEADY            100                  4021656                56168                      6388120              1988876              8589934464                  8581537088                      0                    8154936               3328672                62462                RING_BUFFER_RESOURCE_MONITOR   0                    225914877            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.473 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55936                      6388120              1988772              8589934464                  8581537088                      0                    8154936               3328672                62463                RING_BUFFER_RESOURCE_MONITOR   2                    225914906            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.500 RESOURCE_MEM_STEADY            100                  4021656                56028                      6388120              1988932              8589934464                  8581537088                      0                    8154936               3328472                62464                RING_BUFFER_RESOURCE_MONITOR   0                    225914935            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.503 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55964                      6388120              1988924              8589934464                  8581537088                      0                    8154936               3328472                62465                RING_BUFFER_RESOURCE_MONITOR   2                    225914936            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.503 RESOURCE_MEM_STEADY            100                  4021656                56164                      6388120              1989124              8589934464                  8581537088                      0                    8154936               3328272                62466                RING_BUFFER_RESOURCE_MONITOR   0                    225914937            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.710 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55944                      6388120              1988760              8589934464                  8581536960                      0                    8155064               3328392                62467                RING_BUFFER_RESOURCE_MONITOR   2                    225915143            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.710 RESOURCE_MEM_STEADY            100                  4021656                56064                      6388120              1988880              8589934464                  8581537088                      0                    8154936               3328272                62468                RING_BUFFER_RESOURCE_MONITOR   0                    225915143            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.710 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55980                      6388120              1988792              8589934464                  8581536960                      0                    8155064               3328392                62469                RING_BUFFER_RESOURCE_MONITOR   2                    225915144            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.713 RESOURCE_MEM_STEADY            100                  4021656                56088                      6388120              1988912              8589934464                  8581537088                      0                    8154936               3328272                62470                RING_BUFFER_RESOURCE_MONITOR   0                    225915147            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.717 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1988844              8589934464                  8581537088                      0                    8154936               3328272                62471                RING_BUFFER_RESOURCE_MONITOR   2                    225915152            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.727 RESOURCE_MEM_STEADY            100                  4021656                56016                      6388120              1988892              8589934464                  8581537088                      0                    8154936               3328272                62472                RING_BUFFER_RESOURCE_MONITOR   0                    225915161            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.727 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55916                      6388120              1988828              8589934464                  8581537088                      0                    8154936               3328272                62473                RING_BUFFER_RESOURCE_MONITOR   2                    225915161            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:33.743 RESOURCE_MEM_STEADY            100                  4021656                56184                      6388120              1989292              8589934464                  8581537088                      0                    8154936               3327872                62474                RING_BUFFER_RESOURCE_MONITOR   0                    225915176            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:34.763 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55800                      6388120              1990396              8589934464                  8581537088                      0                    8154936               3322328                62475                RING_BUFFER_RESOURCE_MONITOR   2                    225916199            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:34.767 RESOURCE_MEM_STEADY            100                  4021656                56000                      6388120              1990596              8589934464                  8581537088                      0                    8154936               3322128                62476                RING_BUFFER_RESOURCE_MONITOR   0                    225916201            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:34.853 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55980                      6388120              1990576              8589934464                  8581537088                      0                    8154936               3322128                62477                RING_BUFFER_RESOURCE_MONITOR   2                    225916287            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:34.857 RESOURCE_MEM_STEADY            100                  4021656                56180                      6388120              1990776              8589934464                  8581537088                      0                    8154936               3321928                62478                RING_BUFFER_RESOURCE_MONITOR   0                    225916292            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:34.873 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55932                      6388120              1990240              8589934464                  8581537088                      0                    8154936               3321928                62479                RING_BUFFER_RESOURCE_MONITOR   2                    225916308            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:34.883 RESOURCE_MEM_STEADY            100                  4021656                56488                      6388120              1990052              8589934464                  8581537088                      0                    8154936               3321928                62480                RING_BUFFER_RESOURCE_MONITOR   0                    225916318            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:34.903 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1989640              8589934464                  8581536768                      0                    8155256               3322200                62481                RING_BUFFER_RESOURCE_MONITOR   2                    225916338            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:34.907 RESOURCE_MEM_STEADY            100                  4021656                56144                      6388120              1989832              8589934464                  8581536768                      0                    8155256               3322000                62482                RING_BUFFER_RESOURCE_MONITOR   0                    225916341            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:34.960 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55912                      6388120              1989472              8589934464                  8581537088                      0                    8154936               3321728                62483                RING_BUFFER_RESOURCE_MONITOR   2                    225916394            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:34.963 RESOURCE_MEM_STEADY            100                  4021656                56064                      6388120              1989672              8589934464                  8581537088                      0                    8154936               3321328                62484                RING_BUFFER_RESOURCE_MONITOR   0                    225916398            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:35.010 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1989588              8589934464                  8581537088                      0                    8154936               3321328                62485                RING_BUFFER_RESOURCE_MONITOR   2                    225916443            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:35.013 RESOURCE_MEM_STEADY            100                  4021656                56080                      6388120              1989696              8589934464                  8581537088                      0                    8154936               3321128                62486                RING_BUFFER_RESOURCE_MONITOR   0                    225916447            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:35.037 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1989576              8589934464                  8581536960                      0                    8155064               3321248                62487                RING_BUFFER_RESOURCE_MONITOR   2                    225916470            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:35.037 RESOURCE_MEM_STEADY            100                  4021656                56184                      6388120              1989780              8589934464                  8581536960                      0                    8155064               3321048                62488                RING_BUFFER_RESOURCE_MONITOR   0                    225916471            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:35.047 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1989612              8589934464                  8581536768                      0                    8155256               3321200                62489                RING_BUFFER_RESOURCE_MONITOR   2                    225916481            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:35.053 RESOURCE_MEM_STEADY            100                  4021656                56288                      6388120              1989932              8589934464                  8581536896                      0                    8155128               3320880                62490                RING_BUFFER_RESOURCE_MONITOR   0                    225916486            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:35.157 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55768                      6388120              1989384              8589934464                  8581537088                      0                    8154936               3320728                62491                RING_BUFFER_RESOURCE_MONITOR   2                    225916592            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:35.163 RESOURCE_MEM_STEADY            100                  4021656                56168                      6388120              1989784              8589934464                  8581537088                      0                    8154936               3320328                62492                RING_BUFFER_RESOURCE_MONITOR   0                    225916596            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:35.317 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1989548              8589934464                  8581536960                      0                    8155064               3320448                62493                RING_BUFFER_RESOURCE_MONITOR   2                    225916751            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:35.330 RESOURCE_MEM_STEADY            100                  4021656                56188                      6388120              1989748              8589934464                  8581536960                      0                    8155064               3320248                62494                RING_BUFFER_RESOURCE_MONITOR   0                    225916763            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:36.383 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55976                      6388120              1992616              8589934464                  8581537088                      0                    8154936               3320128                62495                RING_BUFFER_RESOURCE_MONITOR   2                    225917818            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:36.383 RESOURCE_MEM_STEADY            100                  4021656                56176                      6388120              1992816              8589934464                  8581537088                      0                    8154936               3319928                62496                RING_BUFFER_RESOURCE_MONITOR   0                    225917819            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:36.400 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1992860              8589934464                  8581537088                      0                    8154936               3319928                62497                RING_BUFFER_RESOURCE_MONITOR   2                    225917833            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:36.400 RESOURCE_MEM_STEADY            100                  4021656                56188                      6388120              1993060              8589934464                  8581537088                      0                    8154936               3319728                62498                RING_BUFFER_RESOURCE_MONITOR   0                    225917834            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:36.417 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55920                      6388120              1992956              8589934464                  8581537088                      0                    8154936               3319728                62499                RING_BUFFER_RESOURCE_MONITOR   2                    225917850            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:36.417 RESOURCE_MEM_STEADY            100                  4021656                56120                      6388120              1993156              8589934464                  8581537088                      0                    8154936               3319528                62500                RING_BUFFER_RESOURCE_MONITOR   0                    225917852            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:37.560 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55984                      6388120              1995664              8589934464                  8581537088                      0                    8154936               3319528                62501                RING_BUFFER_RESOURCE_MONITOR   2                    225918994            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:37.570 RESOURCE_MEM_STEADY            100                  4021656                56012                      6388120              1995880              8589934464                  8581537088                      0                    8154936               3319328                62502                RING_BUFFER_RESOURCE_MONITOR   0                    225919003            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:38.570 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                54012                      6388120              1995204              8589934464                  8581537088                      0                    8154936               3319328                62503                RING_BUFFER_RESOURCE_MONITOR   2                    225920004            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:38.577 RESOURCE_MEM_STEADY            100                  4021656                56140                      6388120              1997460              8589934464                  8581537088                      0                    8154936               3317128                62504                RING_BUFFER_RESOURCE_MONITOR   0                    225920011            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:38.610 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1997460              8589934464                  8581537088                      0                    8154936               3317128                62505                RING_BUFFER_RESOURCE_MONITOR   2                    225920043            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:38.620 RESOURCE_MEM_STEADY            100                  4021656                56152                      6388120              1997668              8589934464                  8581537088                      0                    8154936               3316928                62506                RING_BUFFER_RESOURCE_MONITOR   0                    225920054            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:38.840 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1997560              8589934464                  8581537088                      0                    8154936               3316928                62507                RING_BUFFER_RESOURCE_MONITOR   2                    225920273            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:38.850 RESOURCE_MEM_STEADY            100                  4021656                55984                      6388120              1997576              8589934464                  8581537088                      0                    8154936               3316912                62508                RING_BUFFER_RESOURCE_MONITOR   0                    225920284            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:38.873 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1997584              8589934464                  8581537088                      0                    8154936               3316904                62509                RING_BUFFER_RESOURCE_MONITOR   2                    225920307            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:38.880 RESOURCE_MEM_STEADY            100                  4021656                56184                      6388120              1997784              8589934464                  8581537088                      0                    8154936               3316704                62510                RING_BUFFER_RESOURCE_MONITOR   0                    225920313            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:40.833 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1997804              8589934464                  8581537088                      0                    8154936               3316704                62511                RING_BUFFER_RESOURCE_MONITOR   2                    225922267            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:40.833 RESOURCE_MEM_STEADY            100                  4021656                56188                      6388120              1998000              8589934464                  8581537088                      0                    8154936               3316504                62512                RING_BUFFER_RESOURCE_MONITOR   0                    225922269            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:40.933 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1997960              8589934464                  8581537088                      0                    8154936               3316504                62513                RING_BUFFER_RESOURCE_MONITOR   2                    225922367            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:40.937 RESOURCE_MEM_STEADY            100                  4021656                56156                      6388120              1998148              8589934464                  8581537088                      0                    8154936               3316304                62514                RING_BUFFER_RESOURCE_MONITOR   0                    225922371            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:40.970 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1998104              8589934464                  8581537088                      0                    8154936               3316304                62515                RING_BUFFER_RESOURCE_MONITOR   2                    225922403            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:40.977 RESOURCE_MEM_STEADY            100                  4021656                56144                      6388120              1998292              8589934464                  8581537088                      0                    8154936               3316104                62516                RING_BUFFER_RESOURCE_MONITOR   0                    225922410            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.010 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1998252              8589934464                  8581537088                      0                    8154936               3316104                62517                RING_BUFFER_RESOURCE_MONITOR   2                    225922443            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.010 RESOURCE_MEM_STEADY            100                  4021656                56184                      6388120              1998456              8589934464                  8581537088                      0                    8154936               3315904                62518                RING_BUFFER_RESOURCE_MONITOR   0                    225922444            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.423 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55964                      6388120              1998168              8589934464                  8581537088                      0                    8154936               3315904                62519                RING_BUFFER_RESOURCE_MONITOR   2                    225922857            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.427 RESOURCE_MEM_STEADY            100                  4021656                56156                      6388120              1998360              8589934464                  8581537088                      0                    8154936               3315704                62520                RING_BUFFER_RESOURCE_MONITOR   0                    225922860            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.443 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55968                      6388120              1998376              8589934464                  8581537088                      0                    8154936               3315704                62521                RING_BUFFER_RESOURCE_MONITOR   2                    225922877            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.450 RESOURCE_MEM_STEADY            100                  4021656                56144                      6388120              1998608              8589934464                  8581537088                      0                    8154936               3315504                62522                RING_BUFFER_RESOURCE_MONITOR   0                    225922885            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.623 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55968                      6388120              1998336              8589934464                  8581537088                      0                    8154936               3315504                62523                RING_BUFFER_RESOURCE_MONITOR   2                    225923058            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.633 RESOURCE_MEM_STEADY            100                  4021656                56020                      6388120              1998464              8589934464                  8581537088                      0                    8154936               3315384                62524                RING_BUFFER_RESOURCE_MONITOR   0                    225923066            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.633 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1998472              8589934464                  8581537088                      0                    8154936               3315376                62525                RING_BUFFER_RESOURCE_MONITOR   2                    225923066            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.633 RESOURCE_MEM_STEADY            100                  4021656                56028                      6388120              1998472              8589934464                  8581537088                      0                    8154936               3315376                62526                RING_BUFFER_RESOURCE_MONITOR   0                    225923066            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.773 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1998436              8589934464                  8581537088                      0                    8154936               3315376                62527                RING_BUFFER_RESOURCE_MONITOR   2                    225923208            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.783 RESOURCE_MEM_STEADY            100                  4021656                56176                      6388120              1998640              8589934464                  8581537088                      0                    8154936               3315176                62528                RING_BUFFER_RESOURCE_MONITOR   0                    225923218            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.867 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1998056              8589934464                  8581537088                      0                    8154936               3315176                62529                RING_BUFFER_RESOURCE_MONITOR   2                    225923302            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.877 RESOURCE_MEM_STEADY            100                  4021656                56052                      6388120              1998120              8589934464                  8581536576                      0                    8154936               3315080                62530                RING_BUFFER_RESOURCE_MONITOR   0                    225923310            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.877 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1998168              8589934464                  8581537088                      0                    8154936               3315064                62531                RING_BUFFER_RESOURCE_MONITOR   2                    225923310            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.890 RESOURCE_MEM_STEADY            100                  4021656                56016                      6388120              1998284              8589934464                  8581537088                      0                    8154936               3314984                62532                RING_BUFFER_RESOURCE_MONITOR   0                    225923323            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.890 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55996                      6388120              1998300              8589934464                  8581537088                      0                    8154936               3314968                62533                RING_BUFFER_RESOURCE_MONITOR   2                    225923324            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.890 RESOURCE_MEM_STEADY            100                  4021656                56024                      6388120              1998300              8589934464                  8581537088                      0                    8154936               3314968                62534                RING_BUFFER_RESOURCE_MONITOR   0                    225923324            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.893 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1998276              8589934464                  8581537088                      0                    8154936               3314968                62535                RING_BUFFER_RESOURCE_MONITOR   2                    225923326            228465671
2009-06-23 08:48:04.250        2009-06-23 08:05:41.900 RESOURCE_MEM_STEADY            100                  4021656                56188                      6388120              1998476              8589934464                  8581537088                      0                    8154936               3314768                62536                RING_BUFFER_RESOURCE_MONITOR   0                    225923333            228465671
2009-06-23 08:48:04.250        2009-06-23 08:06:02.060 RESOURCE_MEMPHYSICAL_HIGH      100                  4021656                75544                      6388120              2009896              8589934464                  8581536960                      0                    8155064               3314896                62537                RING_BUFFER_RESOURCE_MONITOR   1                    225943493            228465671
2009-06-23 08:48:04.250        2009-06-23 08:26:51.773 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                58896                      6388120              1998736              8589934464                  8581531456                      0                    8160568               3333808                62538                RING_BUFFER_RESOURCE_MONITOR   2                    227193206            228465671
2009-06-23 08:48:04.250        2009-06-23 08:26:51.907 RESOURCE_MEM_STEADY            100                  4021656                60904                      6388120              2000912              8589934464                  8581533632                      0                    8158392               3331632                62539                RING_BUFFER_RESOURCE_MONITOR   1                    227193341            228465671
2009-06-23 08:48:04.250        2009-06-23 08:37:38.023 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55808                      6388120              2000108              8589934464                  8581533248                      0                    8158776               3332016                62540                RING_BUFFER_RESOURCE_MONITOR   2                    227839457            228465671
2009-06-23 08:48:04.250        2009-06-23 08:37:38.030 RESOURCE_MEM_STEADY            100                  4021656                56008                      6388120              1999860              8589934464                  8581532288                      0                    8159736               3332264                62541                RING_BUFFER_RESOURCE_MONITOR   0                    227839464            228465671
2009-06-23 08:48:04.250        2009-06-23 08:37:38.030 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55988                      6388120              1999796              8589934464                  8581532224                      0                    8159800               3332328                62542                RING_BUFFER_RESOURCE_MONITOR   2                    227839465            228465671
2009-06-23 08:48:04.250        2009-06-23 08:37:38.040 RESOURCE_MEM_STEADY            100                  4021656                56120                      6388120              1999868              8589934464                  8581532096                      0                    8159928               3332256                62543                RING_BUFFER_RESOURCE_MONITOR   0                    227839475            228465671
2009-06-23 08:48:04.250        2009-06-23 08:37:48.120 RESOURCE_MEMPHYSICAL_HIGH      100                  4021656                57544                      6388120              2002664              8589934464                  8581534912                      0                    8157112               3329440                62544                RING_BUFFER_RESOURCE_MONITOR   1                    227849555            228465671
2009-06-23 08:48:04.250        2009-06-23 08:44:34.623 RESOURCE_MEMPHYSICAL_LOW       100                  4021656                55980                      6388120              2000528              8589934464                  8581531776                      0                    8160248               3331376                62545                RING_BUFFER_RESOURCE_MONITOR   2                    228256057            228465671
2009-06-23 08:48:04.250        2009-06-23 08:44:34.643 RESOURCE_MEM_STEADY            100                  4021656                56424                      6388120              2000984              8589934464                  8581532032                      0                    8159992               3330920                62546                RING_BUFFER_RESOURCE_MONITOR   0                    228256078            228465671
2009-06-23 08:48:04.250        2009-06-23 08:45:35.123 RESOURCE_MEMPHYSICAL_HIGH      100                  4021656                57768                      6388120              2004136              8589934464                  8581535104                      0                    8156920               3327848                62547                RING_BUFFER_RESOURCE_MONITOR   1                    228316558            228465671

(128 row(s) affected)
*/