USE Sudoku
GO

ALTER PROCEDURE Reduce_LookAlikes
AS
BEGIN
	SET NOCOUNT ON

	DECLARE --
		@groupType INT = 0 	-- 1 = row, 2 = column, 3 = section

	WHILE @groupType < 4
	BEGIN
		SET @groupType = @groupType + 1;
	
		WITH cte_options
		AS (
			SELECT --
				o.i,
				g = CASE @groupType
					WHEN 1
						THEN o.r
					WHEN 2
						THEN o.c
					WHEN 3
						THEN o.s
					END,
				o.v
			FROM dbo.Options o
			),
		cte_looks
		AS (
			SELECT l.i,
				g = CASE @groupType
					WHEN 1
						THEN l.r
					WHEN 2
						THEN l.c
					WHEN 3
						THEN l.s
					END,
				l.look
			FROM dbo.Looks l
			),
		cte_count_todo
		AS (
			SELECT -- count the todo cells 
				o.g,
				#todo = count(DISTINCT o.i)
			FROM cte_options o
			GROUP BY o.g
			),
		cte_look_alikes
		AS (
			SELECT -- find the cells with (some of) the same values
				l.look,
				l.#v,
				lookalike = a.i,
				a.g
			FROM dbo.Combos l
			INNER JOIN cte_looks a -- look-a-likes
				ON l.look LIKE a.look
			),
		cte_reducers
		AS (
			SELECT -- cells with enough look-alikes but less than cells to be determined
				la.g,
				la.look
			FROM cte_look_alikes la
			INNER JOIN cte_count_todo td --
				ON td.g = la.g
			GROUP BY --
				la.g,
				la.look
			HAVING count(*) = max(la.#v)
				AND count(*) < max(td.#todo)
			)
		DELETE d -- reduce options in the cells that also contain different options
		FROM cte_reducers r
		-- what values could be reduced
		CROSS APPLY string_split(r.look, '-') o
		INNER JOIN options d -- all options within the group with the same value
			ON CASE @groupType
				WHEN 1
					THEN d.r
				WHEN 2
					THEN d.c
				WHEN 3
					THEN d.s
				END = r.g
			AND d.v = CAST(o.value AS TINYINT)
		LEFT JOIN cte_looks l -- attach their look
			ON l.g = r.g
			AND l.i = d.i
		WHERE r.look NOT LIKE l.look -- reduce from cells that also contain different options
			AND o.[value] <> '_'
	END
END
