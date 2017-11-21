-- http://dev.mysql.com/doc/refman/5.1/en/date-and-time-functions.html#function_from-unixtime
SELECT created, FROM_UNIXTIME(node.created,'%Y %D %M %h:%i:%s %x') AS datecreated FROM node