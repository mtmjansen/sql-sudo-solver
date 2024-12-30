USE [Sudoku]
GO

ALTER PROCEDURE Init_Sudoku
AS
BEGIN
	SET NOCOUNT ON

	-- Numbers
	TRUNCATE TABLE [dbo].[Numbers]

	INSERT INTO [dbo].[Numbers]
	SELECT TOP 100 --
		nr = row_number() over (order by object_id)
	FROM sys.objects

	-- Model
	TRUNCATE TABLE [dbo].[Model];

	WITH cells AS (
		SELECT --
			i = cast(nr as tinyint),
			r = cast(1 + (nr-1)/9 as tinyint),
			c = cast(1 + (nr-1) % 9 as tinyint)
		FROM Numbers
		WHERE nr < 82
	)
	INSERT INTO dbo.[Model]
	SELECT --
		i,
		r,
		c,
		s = cast((r-1)/3*3 + (c+2)/3 as tinyint)
	FROM cells

	-- Combos
	TRUNCATE TABLE [dbo].[Combos];

	WITH cte_combos
	AS (
		SELECT --
			#v = 1,
			highest = n.nr,
			look = stuff('_-_-_-_-_-_-_-_-_', n.nr * 2 - 1, 1, cast(n.nr AS CHAR(1)))
		FROM Numbers n
		WHERE n.nr BETWEEN 1 AND 9
	
		UNION ALL
	
		SELECT --
			#v = c.#v + 1,
			highest = n.nr,
			look = stuff(c.look, n.nr * 2 - 1, 1, cast(n.nr AS CHAR(1)))
		FROM cte_combos c
		INNER JOIN Numbers n --
		ON n.nr > c.highest
		WHERE n.nr BETWEEN 1 AND 9
			AND c.#v < 7
	)
	INSERT INTO [dbo].[Combos]
	SELECT --
		#v,
		look
	FROM cte_combos
	WHERE #v > 1
	ORDER BY --
		#v,
		look DESC
END
GO
