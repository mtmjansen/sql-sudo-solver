USE Sudoku
GO

ALTER PROCEDURE Reduce_Options
AS
BEGIN
	; WITH cells_with_one_option AS (
		SELECT i
		FROM Options
		GROUP BY i
		HAVING count(*) = 1
	)
	INSERT INTO Puzzle
	SELECT o.*
	FROM Options o
	INNER JOIN cells_with_one_option cte
	ON cte.i = o.i

	EXEC Update_Options

	; WITH rows_with_value_on_single_column AS (
		select r,v
		from options
		group by r,v
		having count(*) = 1
	)
	INSERT INTO Puzzle
	SELECT o.*
	FROM Options o
	INNER JOIN rows_with_value_on_single_column cte
	ON cte.r = o.r
	AND cte.v = o.v

	EXEC Update_Options

	; WITH columns_with_value_on_single_row AS (
		select c,v
		from options
		group by c,v
		having count(*) = 1
	)
	INSERT INTO Puzzle
	SELECT o.*
	FROM Options o
	INNER JOIN columns_with_value_on_single_row cte
	ON cte.c = o.c
	AND cte.v = o.v

	EXEC Update_Options

	; WITH sections_with_value_on_single_cell AS (
		select s,v
		from options
		group by s,v
		having count(*) = 1
	)
	INSERT INTO Puzzle
	SELECT o.*
	FROM Options o
	INNER JOIN sections_with_value_on_single_cell cte
	ON cte.s = o.s
	AND cte.v = o.v

	EXEC Update_Options

	; WITH sections_with_value_on_single_row AS (
		select s, v, r = max(r)
		from options
		group by s,v
		having count(distinct r) = 1
		union select s = max(s), v, r
		from options
		group by r,v
		having count(distinct s) = 1
	)
	DELETE o
	FROM Options o
	RIGHT JOIN sections_with_value_on_single_row cte
	ON cte.v = o.v
	AND (
		cte.r = o.r AND cte.s <> o.s OR
		cte.r <> o.r AND cte.s = o.s 
	)

	; WITH sections_with_value_on_single_column AS (
		select s, v, c = max(c)
		from options
		group by s,v
		having count(distinct c) = 1
		union select s = max(s), v, c
		from options
		group by c,v
		having count(distinct s) = 1
	)
	DELETE o
	FROM Options o
	RIGHT JOIN sections_with_value_on_single_column cte
	ON cte.v = o.v
	AND (
		cte.c = o.c AND cte.s <> o.s OR
		cte.c <> o.c AND cte.s = o.s 
	)

	EXEC Reduce_LookAlikes
END
GO
