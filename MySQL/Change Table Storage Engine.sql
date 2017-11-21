ALTER TABLE tab ENGINE=MyISAM 


select concat('alter table ',table_schema,'.',table_name,' engine=MyISAM;') 
from information_schema.tables 
where engine = 'InnoDB' 
-- where engine = 'MyISAM'