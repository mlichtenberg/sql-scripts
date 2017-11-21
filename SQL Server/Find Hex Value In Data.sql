-- USE THIS SCRIPT TO LOCATE A HEX VALUE SOMEWHERE IN A YOUR DATA.
-- WORKS ON SQL 2005.  DON'T KNOW ABOUT 2008 OR 2012.

-- BASED ON http://social.msdn.microsoft.com/forums/en-us/transactsql/thread/F16F4F69-8408-4EEE-80D7-415E5B1D14CD

set nocount on

--Script parameters
declare @Hex as VARCHAR(50)
declare @Value as VARCHAR(50)
declare @SearchStrings char(1)
declare @SearchNumbers char(1)
declare @SearchDates char(1)
declare @SearchTable varchar(500)

----------------------------------------------------------------------------------------------------
--Script: ValueSearcher
--blindman, 9/19/2005
--Searches columns in user tables for a specified value.
--Returns the location where the value is found, and the number of records containing that value.
--Enter the value to be found in the Script parameter settings section below.
--Column types and comparison methods can be defined using the @Search parameters.
----------------------------------------------------------------------------------------------------
--Script parameter settings
set @Hex = 0x3A -- Enter the hex value to locate
set @Value = Char(Ascii(@Hex))
set @SearchStrings = 'L' --E=Exact string search, L=Search using Like operator, N=Do not search.
set @SearchNumbers = 'N' --Y=Search for numbers, N=Do not search.
set @SearchDates = 'N' --E=Exact datetime search, D=Search whole date parts only, N=Do not search.
set @SearchTable = 'Segment' -- Give a table name to search a specific table... leave blank to search all
----------------------------------------------------------------------------------------------------

--Processing variables
create table #Results (TableName sysname, ColumnName sysname, RecordCount bigint)
declare @SQLString varchar(4000)

--check validity of parameters
if IsNumeric(@Value) = 0 set @SearchNumbers = 'N'
if IsDate(@Value) = 0 set @SearchDates = 'N'

--Create SQL statements to search the database
declare SQLCursor cursor for
 --exact string columns
--------------------------->--------------------------->--------------------------->--------------------------->--------------------------->------------------v
 select 'insert into #Results (TableName, ColumnName, RecordCount) select ''' + sysobjects.name + ''', ''' + syscolumns.name + ''', count(*) from ' + '['+SCHEMA_NAME(sys.tables.schema_id)+'].['+sys.tables.name+']' + ' where ' + syscolumns.name + ' = ''' + @Value + ''' having count(*) > 0'
 from sysobjects
  inner join syscolumns on sysobjects.id = syscolumns.id
  inner join systypes on syscolumns.xtype = systypes.xtype
  inner join sys.tables on sysobjects.id = object_id
 where sysobjects.type = 'U'
  and systypes.name in ('char', 'nchar', 'nvarchar', 'sysname', 'uniqueidentifer', 'varchar')
  and @SearchStrings = 'E'
  and (sysobjects.name = @SearchTable or @SearchTable = '')
 UNION
 --like string columns
 select 'insert into #Results (TableName, ColumnName, RecordCount) select ''' + sysobjects.name + ''', ''' + syscolumns.name + ''', count(*) from ' + '['+SCHEMA_NAME(sys.tables.schema_id)+'].['+sys.tables.name+']' + ' where ' + syscolumns.name + ' like ''%' + @Value + '%'' having count(*) > 0'
 from sysobjects
  inner join syscolumns on sysobjects.id = syscolumns.id
  inner join systypes on syscolumns.xtype = systypes.xtype
  inner join sys.tables on sysobjects.id = object_id
 where sysobjects.type = 'U'
  and systypes.name in ('char', 'nchar', 'nvarchar', 'sysname', 'uniqueidentifer', 'varchar')
  and @SearchStrings = 'L'
  and (sysobjects.name = @SearchTable or @SearchTable = '')
 UNION
 --numeric columns
 select 'insert into #Results (TableName, ColumnName, RecordCount) select ''' + sysobjects.name + ''', ''' + syscolumns.name + ''', count(*) from ' + '['+SCHEMA_NAME(sys.tables.schema_id)+'].['+sys.tables.name+']' + ' where ' + syscolumns.name + ' = ' + @Value + ' having count(*) > 0'
 from sysobjects
  inner join syscolumns on sysobjects.id = syscolumns.id
  inner join systypes on syscolumns.xtype = systypes.xtype
  inner join sys.tables on sysobjects.id = object_id
 where sysobjects.type = 'U'
  and systypes.name in ('bigint', 'decimal', 'float', 'int', 'money', 'numeric', 'real', 'smallint', 'smallmoney', 'tinyint')
  and @SearchNumbers = 'Y'
  and (sysobjects.name = @SearchTable or @SearchTable = '')
 UNION
 --Exact datetime columns
 select 'insert into #Results (TableName, ColumnName, RecordCount) select ''' + sysobjects.name + ''', ''' + syscolumns.name + ''', count(*) from ' + '['+SCHEMA_NAME(sys.tables.schema_id)+'].['+sys.tables.name+']' + ' where ' + syscolumns.name + ' = ''' + @Value + ''' having count(*) > 0'
 from sysobjects
  inner join syscolumns on sysobjects.id = syscolumns.id
  inner join systypes on syscolumns.xtype = systypes.xtype
  inner join sys.tables on sysobjects.id = object_id
 where sysobjects.type = 'U'
  and systypes.name in ('datetime', 'smalldatetime')
  and @SearchDates = 'E'
  and (sysobjects.name = @SearchTable or @SearchTable = '')
 UNION
 --dateonly datetime columns
 select 'insert into #Results (TableName, ColumnName, RecordCount) select ''' + sysobjects.name + ''', ''' + syscolumns.name + ''', count(*) from ' + '['+SCHEMA_NAME(sys.tables.schema_id)+'].['+sys.tables.name+']' + ' where convert(char(10), ' + syscolumns.name + ', 120) = convert(char(10), convert(datetime, ''' + @Value + '''), 120) having count(*) > 0'
 from sysobjects
  inner join syscolumns on sysobjects.id = syscolumns.id
  inner join systypes on syscolumns.xtype = systypes.xtype
  inner join sys.tables on sysobjects.id = object_id
 where sysobjects.type = 'U'
  and systypes.name in ('datetime', 'smalldatetime')
  and @SearchDates = 'D'
  and (sysobjects.name = @SearchTable or @SearchTable = '')

--Run the SQL Statements
Open SQLCursor
Fetch next from SQLCursor into @SQLString
while @@FETCH_STATUS = 0
 begin
  exec (@SQLString)
  fetch next from SQLCursor into @SQLString
 end
Close SQLCursor
Deallocate SQLCursor

--Display the summarized results
select TableName, 
 ColumnName,
 RecordCount
from #Results
order by TableName,
 ColumnName


-- Get SQL Statements to display the affected rows
declare SQLCursor cursor for
	SELECT 'select * from ' + TableName + ' where ' + ColumnName + ' like ''%' + @Value + '%'''
	FROM #Results

--Run the SQL Statements
Open SQLCursor
Fetch next from SQLCursor into @SQLString
while @@FETCH_STATUS = 0
 begin
  exec (@SQLString)
  fetch next from SQLCursor into @SQLString
 end
Close SQLCursor
Deallocate SQLCursor


--Clean up
drop table #Results


