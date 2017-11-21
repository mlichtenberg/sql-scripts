-- Get process list
create table #tmpProc
(
spid int not null,
ecid int not null,
[status] varchar(50) not null,
loginname varchar(50) not null,
hostname varchar(50) not null,
blk int not null,
dbname varchar(50) null,
cmd varchar(100) not null,
request_id int not null
)

insert into #tmpProc exec sp_who

--***********************************************************
-- Insert queries to analyze processes here

select dbname, count(*) from #tmpProc group by dbname order by 2 desc
--***********************************************************

-- Clean up
drop table #tmpProc
