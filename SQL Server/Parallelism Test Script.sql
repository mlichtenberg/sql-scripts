-- With parallelism enabled, this complete script took 5 minutes 14 seconds to run
-- Queries that never used parallel plans were unchanged with parallelism disabled.
dbcc freeproccache
dbcc dropcleanbuffers

set nocount on

select getdate() as 'current time'
exec TitleSelectByNameLike 'hymenoptera'
select getdate() as 'current time'
	exec PageNameSelectByNameLike 'hymenoptera'  -- uses parallelism; slightly slower with parallelism disabled
select getdate() as 'current time'
exec PageSelectWithoutPageNames
select getdate() as 'current time'
exec PageSummarySelectByItemID 1000
select getdate() as 'current time'
exec TitleSelectSearchName 'hymenoptera', 1
select getdate() as 'current time'
exec InstitutionSelectWithPublishedItems
select getdate() as 'current time'
exec ItemSelectWithoutPageNames
select getdate() as 'current time'
exec LocationSelectValidByInstitution
select getdate() as 'current time'
	exec PageNameCountUniqueConfirmed  -- uses parallelism; much faster with parallelism disabled
select getdate() as 'current time'
exec PageNameSearchForTitles 'hymenoptera'
select getdate() as 'current time'
exec PageNameSelectByConfirmedName 'hymenoptera'
select getdate() as 'current time'
exec PageSelectByItemID 1000
select getdate() as 'current time'
exec TitleSelectByTagTextInstitutionAndLanguage 'plants', '', ''
select getdate() as 'current time'
exec ItemSelectByTitleID 1000
select getdate() as 'current time'
exec PageNameSearch 'hymenoptera', 10405
select getdate() as 'current time'
exec TitleSelectAllWithCreator
select getdate() as 'current time'
exec PageMetadataSelectByItemID 1000
select getdate() as 'current time'
