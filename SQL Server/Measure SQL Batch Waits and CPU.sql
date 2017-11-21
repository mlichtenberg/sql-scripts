dbcc dropcleanbuffers
dbcc freeproccache

exec begin_waitstats

DECLARE @NameBankID int
SET @NameBankID = 5048295

-- Get the detail for the specified NameBankID
SELECT	d.NameBankID, 
		d.NameConfirmed,
		d.TitleID, 
		t.MARCBibID, t.ShortTitle, t.PublicationDetails, t.TL2Author, 
		d.BPH, 
		d.TL2, 
		d.Abbreviation,
		'http://www.biodiversitylibrary.org/title/' + CONVERT(nvarchar(20), d.TitleID) AS TitleURL,
		d.ItemID, 
		i.BarCode, i.MARCItemID, i.CallNumber, i.Volume AS VolumeInfo,
		'http://www.biodiversitylibrary.org/item/' + CONVERT(nvarchar(20), d.ItemID) AS ItemURL,
		d.PageID, 
		p.[Year], p.Volume, p.Issue,
		d.PagePrefix, 
		d.PageNumber,
		'http://www.biodiversitylibrary.org/page/' + CONVERT(nvarchar(20), d.PageID) AS PageURL,
		CASE WHEN p.ExternalURL IS NOT NULL THEN '' ELSE 'http://images.mobot.org/viewer/viewerthumbnail.asp?cat=' + d.WebVirtualDirectory + '&client=' + t.MarcBibID + '/' + i.BarCode + '/jp2&image=' + p.FileNamePrefix + '.jp2' END AS ThumbnailURL,
		'http://images.biodiversitylibrary.org/adore-djatoka/viewer.jsp?cat=' + d.WebVirtualDirectory + '&client=' + t.MarcBibID + '/' + i.BarCode + '/jp2&image=' + p.FileNamePrefix + '.jp2&imageURL=' + ISNULL(p.ExternalURL, '') + '&imageDetailURL=' + ISNULL(p.AltExternalURL, '') AS ImageURL,
		d.PageTypeName
FROM	PageNameDetail d INNER JOIN Page p
			ON d.PageID = p.PageID
		INNER JOIN Item i
			ON d.ItemID = i.ItemID
		INNER JOIN Title t
			ON d.TitleID = t.TitleID
WHERE	d.NameBankID = @NameBankID
ORDER BY
		t.SortTitle, d.ItemID, p.[Year], p.Volume, d.PageNumber

exec end_waitstats

PAGEIOLATCH_SH		7328	44344	62	1900-01-01 00:00:45.117
PAGEIOLATCH_EX		882		10672	16	1900-01-01 00:00:45.117
IO_COMPLETION		3558	7984	0	1900-01-01 00:00:45.117
ASYNC_NETWORK_IO	6537	2640	15	1900-01-01 00:00:45.117
WRITELOG			7		31		0	1900-01-01 00:00:45.117

--------------------------------

dbcc dropcleanbuffers
dbcc freeproccache

exec begin_waitstats

DECLARE @NameBankID int
DECLARE @Abbreviation int
DECLARE @BPH int
DECLARE @TL2 int

SET @NameBankID = 5048295
SELECT @Abbreviation = TitleIdentifierID FROM TitleIdentifier WHERE IdentifierName = 'Abbreviation'
SELECT @BPH = TitleIdentifierID FROM TitleIdentifier WHERE IdentifierName = 'BPH'
SELECT @TL2 = TitleIdentifierID FROM TitleIdentifier WHERE IdentifierName = 'TL2'

-- Get the detail for the specified NameBankID
SELECT	pn.NameBankID, pn.NameConfirmed,
		t.TitleID, t.MARCBibID, t.ShortTitle, t.PublicationDetails, t.TL2Author, 
		bph.IdentifierValue AS BPH, tl2.IdentifierValue AS TL2, 
		abbrev.IdentifierValue AS Abbreviation,
		'http://www.biodiversitylibrary.org/title/' + CONVERT(nvarchar(20), t.TitleID) AS TitleURL,
		i.ItemID, i.BarCode, i.MARCItemID, i.CallNumber, i.Volume AS VolumeInfo,
		'http://www.biodiversitylibrary.org/item/' + CONVERT(nvarchar(20), i.ItemID) AS ItemURL,
		p.PageID, p.[Year], p.Volume, p.Issue,
		ip.PagePrefix, ip.PageNumber,
		'http://www.biodiversitylibrary.org/page/' + CONVERT(nvarchar(20), p.PageID) AS PageURL,
		CASE WHEN p.ExternalURL IS NOT NULL THEN '' ELSE 'http://images.mobot.org/viewer/viewerthumbnail.asp?cat=' + v.WebVirtualDirectory + '&client=' + t.MarcBibID + '/' + i.BarCode + '/jp2&image=' + p.FileNamePrefix + '.jp2' END AS ThumbnailURL,
		'http://images.biodiversitylibrary.org/adore-djatoka/viewer.jsp?cat=' + v.WebVirtualDirectory + '&client=' + t.MarcBibID + '/' + i.BarCode + '/jp2&image=' + p.FileNamePrefix + '.jp2&imageURL=' + ISNULL(p.ExternalURL, '') + '&imageDetailURL=' + ISNULL(p.AltExternalURL, '') AS ImageURL,
		pt.PageTypeName
FROM	PageName pn	INNER JOIN Page p
			ON pn.PageID = p.PageID
		INNER JOIN IndicatedPage ip
			ON p.PageID = ip.PageID
		INNER JOIN Item i
			ON p.ItemID = i.ItemID
		INNER JOIN Title t
			ON i.PrimaryTitleID = t.TitleID
		INNER JOIN Vault v
			ON i.VaultID = v.VaultID
		LEFT JOIN Page_PageType ppt
			ON p.PageID = ppt.PageID
		LEFT JOIN PageType pt
			ON ppt.PageTypeID = pt.PageTypeID
		LEFT JOIN Title_TitleIdentifier	abbrev
			ON t.TitleID = abbrev.TitleID AND abbrev.TitleIdentifierID = @Abbreviation
		LEFT JOIN Title_TitleIdentifier bph
			ON t.TitleID = bph.TitleID AND bph.TitleIdentifierID = @BPH
		LEFT JOIN Title_TitleIdentifier tl2 
			ON t.TitleID = tl2.TitleID AND tl2.TitleIdentifierID = @TL2
WHERE	pn.NameBankID = @NameBankID
ORDER BY
		t.SortTitle, i.ItemID, p.[Year], p.Volume, ip.PageNumber

exec end_waitstats

--------------------------------



drop proc [dbo].[begin_waitstats] 
go
CREATE proc [dbo].[begin_waitstats]
as

set nocount on
if exists (select 1 
               from sys.objects 
               where object_id = object_id ( N'[dbo].[my_waitstats]') and 
               OBJECTPROPERTY(object_id, N'IsUserTable') = 1)
begin
	drop table [dbo].[my_waitstats]
	drop table [dbo].[my_otherstats]     
	create table [dbo].[my_waitstats] 
			([wait_type] nvarchar(60) not null,
			[waiting_tasks_count] bigint not null, 
			[wait_time_ms] bigint not null,
			[signal_wait_time_ms] bigint not null,
			now datetime not null default getdate())
	create table [dbo].[my_otherstats] 
		(spid smallint not null,
		cpu_time bigint,
		total_scheduled_time int,
		 total_elapsed_time int,
		reads bigint,
		writes bigint,
		logical_reads bigint)
end

declare @i int, @myspid smallint, @now datetime

begin
    select @now = getdate()
    select @myspid = @@SPID

    insert into [dbo].[my_waitstats] (
        [wait_type], [waiting_tasks_count], [wait_time_ms],  [signal_wait_time_ms], now)	
    select	[wait_type], 
			[waiting_tasks_count],
			[wait_time_ms], 
			[signal_wait_time_ms], 
			@now
    from sys.dm_os_wait_stats

	insert into [dbo].[my_otherstats]
	select session_id,cpu_time, total_scheduled_time, total_elapsed_time, reads,writes, logical_reads 
	from sys.dm_exec_sessions 
	where session_id=@myspid

end
;

--------------------------------

drop proc [dbo].[end_waitstats]
go
CREATE proc [dbo].[end_waitstats]
as

set nocount on

if not exists (select 1 from sys.objects 
               where object_id = object_id ( N'[dbo].[my_waitstats]') and 
               OBJECTPROPERTY(object_id, N'IsUserTable') = 1)
begin
	raiserror ('end_waitstats without begin..',16,1) with nowait	
end

declare @i int, @myspid smallint, @now datetime
begin
    select @now = getdate()
    select @myspid = @@SPID

    select	s.[wait_type], 
			s.[waiting_tasks_count]-m.[waiting_tasks_count] waits,
            s.[wait_time_ms]-m.[wait_time_ms] wait_time, 
            s.[signal_wait_time_ms]-m.[signal_wait_time_ms] signal_wait_time, 
            @now-m.now elapsed_time
    from sys.dm_os_wait_stats s, [dbo].[my_waitstats] m
	where s.[wait_type]=m.[wait_type] and s.[wait_time_ms]-m.[wait_time_ms] > 0
	and	s.[wait_type] not in (
        'CLR_SEMAPHORE',
        'LAZYWRITER_SLEEP',
        'RESOURCE_QUEUE',
        'SLEEP_TASK',
        'SLEEP_SYSTEMTASK',
        'SQLTRACE_BUFFER_FLUSH', 'WAITFOR')
	
	select s.session_id, s.cpu_time-m.cpu_time cpu_time, s.total_scheduled_time-m.total_scheduled_time tot_sched_time, 
		s.total_elapsed_time-m.total_elapsed_time elapsed_time,
		s.reads-m.reads PIO, s.writes-m.writes writes , s.logical_reads-s.logical_reads LIO
	from sys.dm_exec_sessions s, [dbo].[my_otherstats] m 
	where s.session_id=@myspid 
end
;


