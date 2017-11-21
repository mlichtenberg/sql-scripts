DECLARE curExtProp CURSOR
READ_ONLY
FOR SELECT objtype, objname, [name] FROM fn_listextendedproperty(null, 'schema', 'dbo', 'table', default, null, null)

DECLARE @objtype varchar(40)
DECLARE @objname varchar(40)
DECLARE @name varchar(40)

OPEN curExtProp

FETCH NEXT FROM curExtProp INTO @objtype, @objname, @name
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		PRINT 'Dropping extended property "' + @name + '" from ' + @objtype + ' "' + @objname + '"'
		exec sp_dropextendedproperty @name, 'schema', 'dbo', @objtype, @objname, null, null
	END
	FETCH NEXT FROM curExtProp INTO @objtype, @objname, @name
END

CLOSE curExtProp
DEALLOCATE curExtProp
GO

