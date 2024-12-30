USE [master]
GO

/****** Object:  Database [Sudoku] ******/
CREATE DATABASE [Sudoku]
GO

ALTER DATABASE [Sudoku] SET READ_ONLY
GO

ALTER DATABASE [Sudoku] SET COMPATIBILITY_LEVEL = 160
GO

USE [Sudoku]
GO

/****** Object:  Table [dbo].[Numbers] ******/
CREATE TABLE [dbo].[Numbers](
	[nr] [bigint] NOT NULL
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[Options] ******/
CREATE TABLE [dbo].[Options](
	[i] [tinyint] NULL,
	[r] [tinyint] NULL,
	[c] [tinyint] NULL,
	[s] [tinyint] NULL,
	[v] [bigint] NULL
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[Model] ******/
CREATE TABLE [dbo].[Model](
	[i] [tinyint] NULL,
	[r] [tinyint] NULL,
	[c] [tinyint] NULL,
	[s] [tinyint] NULL
) ON [PRIMARY]
GO

/****** Object:  View [dbo].[Looks] ******/
CREATE VIEW [dbo].[Looks] AS
-- format a look that can be used with LIKE
SELECT --
	m.i,
	m.r,
	m.c,
	m.s,
	look = string_agg(isnull(cast(o.v as char(1)), '_'),'-') WITHIN GROUP ( ORDER BY n.nr ),
	#v = count(o.v)
FROM Numbers n
INNER JOIN Model m --
ON m.i IS NOT NULL -- all combinations
LEFT JOIN Options o --
ON o.i = m.i
AND o.v = n.nr
WHERE n.nr BETWEEN 1 AND 9
GROUP BY --
	m.i,
	m.r,
	m.c,
	m.s
HAVING count(o.v) BETWEEN 1 AND 8
GO

/****** Object:  Table [dbo].[Combos] ******/
CREATE TABLE [dbo].[Combos](
	[#v] [tinyint] NOT NULL,
	[look] [char](20) NOT NULL
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[Puzzle] ******/
CREATE TABLE [dbo].[Puzzle](
	[i] [tinyint] NULL,
	[r] [tinyint] NULL,
	[c] [tinyint] NULL,
	[s] [tinyint] NULL,
	[v] [int] NOT NULL
) ON [PRIMARY]
GO

/****** Object:  Table [dbo].[Puzzles] ******/
CREATE TABLE [dbo].[Puzzles](
	[puzzleId] [int] IDENTITY(1,1) NOT NULL,
	[puzzle] [char](81) NOT NULL,
	[comment] [nvarchar](50) NULL,
	[page] [int] NULL,
	[stars] [int] NULL,
 CONSTRAINT [PK_PuzzlesNew] PRIMARY KEY CLUSTERED 
(
	[puzzleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

SET ANSI_PADDING ON
GO

/****** Object:  Index [UX_Puzzles_Puzzle] ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_Puzzles_Puzzle] ON [dbo].[Puzzles]
(
	[puzzle] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

/****** Object:  StoredProcedure [dbo].[Init_Sudoku] ******/
CREATE PROCEDURE [dbo].[Init_Sudoku]
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

/****** Object:  StoredProcedure [dbo].[Reduce_LookAlikes] ******/
CREATE PROCEDURE [dbo].[Reduce_LookAlikes]
AS
BEGIN
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
GO

/****** Object:  StoredProcedure [dbo].[Reduce_LookAlikes_InColumns] ******/
CREATE PROCEDURE [dbo].[Reduce_LookAlikes_InColumns]
AS
BEGIN
	WITH cte_count_todo
	AS (
		SELECT -- count the todo cells 
			o.c, -- InColumns
			#todo = count(DISTINCT o.i)
		FROM Options o
		GROUP BY o.c -- InColumns
		),
	cte_look_alikes
	AS (
		SELECT -- find the cells with (some of) the same values
			l.*,
			lookalike = a.i,
			a.c
		FROM Combos l
		INNER JOIN Looks a -- look-a-likes
			ON l.look LIKE a.look
		),
	cte_reducers
	AS (
		SELECT -- cells with enough look-alikes but less than cells to be determined
			la.c,
			la.look
		FROM cte_look_alikes la
		INNER JOIN cte_count_todo td --
			ON td.c = la.c  -- InColumns
		GROUP BY --
			la.c,
			la.look
		HAVING count(*) = max(la.#v)
		   AND count(*) < max(td.#todo)
		)
	DELETE d -- reduce options in the cells that also contain different options
	FROM cte_reducers r
	-- what values could be reduced
	CROSS APPLY string_split( r.look, '-') o
	INNER JOIN options d -- all options within the group with the same value
		ON d.c = r.c -- InColumns
		AND d.v = CAST(o.value AS tinyint)
	LEFT JOIN looks l -- attach their look
		ON l.c = r.c -- InColumns
		AND l.i = d.i
	WHERE r.look NOT LIKE l.look -- reduce from cells that also contain different options
	AND o.[value] <> '_'
END
GO

/****** Object:  StoredProcedure [dbo].[Reduce_LookAlikes_InRows] ******/
CREATE PROCEDURE [dbo].[Reduce_LookAlikes_InRows]
AS
BEGIN
	WITH cte_count_todo
	AS (
		SELECT -- count the todo cells 
			o.r, -- InRows
			#todo = count(DISTINCT o.i)
		FROM Options o
		GROUP BY o.r -- InRows
		),
	cte_look_alikes
	AS (
		SELECT -- find the cells with (some of) the same values
			l.*,
			lookalike = a.i
		FROM Looks l
		INNER JOIN Looks a -- look-a-likes
			ON l.r = a.r  -- InRows
			AND l.look LIKE a.look
		),
	cte_reducers
	AS (
		SELECT -- cells with enough look-alikes but less than cells to be determined
			la.i,
			la.r,
			la.c,
			la.s,
			la.look
		FROM cte_look_alikes la
		INNER JOIN cte_count_todo td --
			ON td.r = la.r  -- InRows
		GROUP BY --
			la.i,
			la.r,
			la.c,
			la.s,
			la.look
		HAVING count(*) = max(la.#v)
		   AND count(*) < max(td.#todo)
		)
	DELETE d -- reduce options in the cells that also contain different options
	FROM cte_reducers r
	INNER JOIN options o -- what values could be reduced
		ON o.i = r.i
	INNER JOIN options d -- all options within the group with the same value
		ON d.r = r.r -- InRows
		AND d.v = o.v
	LEFT JOIN looks l -- attach their look
		ON l.r = r.r -- InRows
		AND l.i = d.i
	WHERE r.look NOT LIKE l.look -- reduce from cells that also contain different options
END
GO

/****** Object:  StoredProcedure [dbo].[Reduce_LookAlikes_InSections] ******/
CREATE PROCEDURE [dbo].[Reduce_LookAlikes_InSections]
AS
BEGIN
	WITH cte_count_todo
	AS (
		SELECT -- count the todo cells 
			o.s, -- InSections
			#todo = count(DISTINCT o.i)
		FROM Options o
		GROUP BY o.s -- InSections
		),
	cte_look_alikes
	AS (
		SELECT -- find the cells with (some of) the same values
			l.*,
			lookalike = a.i
		FROM Looks l
		INNER JOIN Looks a -- look-a-likes
			ON l.s = a.s  -- InSections
			AND l.look LIKE a.look
		),
	cte_reducers
	AS (
		SELECT -- cells with enough look-alikes but less than cells to be determined
			la.i,
			la.r,
			la.c,
			la.s,
			la.look
		FROM cte_look_alikes la
		INNER JOIN cte_count_todo td --
			ON td.s = la.s  -- InSections
		GROUP BY --
			la.i,
			la.r,
			la.c,
			la.s,
			la.look
		HAVING count(*) = max(la.#v)
		   AND count(*) < max(td.#todo)
		)
	DELETE d -- reduce options in the cells that also contain different options
	FROM cte_reducers r
	INNER JOIN options o -- what values could be reduced
		ON o.i = r.i
	INNER JOIN options d -- all options within the group with the same value
		ON d.s = r.s -- InSections
		AND d.v = o.v
	LEFT JOIN looks l -- attach their look
		ON l.s = r.s -- InSections
		AND l.i = d.i
	WHERE r.look NOT LIKE l.look -- reduce from cells that also contain different options
END
GO

/****** Object:  StoredProcedure [dbo].[Reduce_Options] ******/
CREATE PROCEDURE [dbo].[Reduce_Options]
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

/****** Object:  StoredProcedure [dbo].[Reset_Options] ******/
CREATE PROCEDURE [dbo].[Reset_Options] AS
BEGIN
	SET NOCOUNT ON

	TRUNCATE TABLE Options

	INSERT INTO Options
	SELECT 
		m.*,
		v = nr
	FROM Model m
	FULL JOIN Numbers n
	ON nr between 1 AND 9
	WHERE m.i IS NOT NULL
END
GO

/****** Object:  StoredProcedure [dbo].[Save_Puzzle] ******/
CREATE PROCEDURE [dbo].[Save_Puzzle] 
	@PuzzleString varchar(110)
AS
BEGIN
	SET NOCOUNT ON

	IF(@PuzzleString IS NULL)
	BEGIN
		PRINT 'Validation failed. NULL not allowed.'

		RETURN
	END

	DECLARE --
		@TAB char(1) = char(9),
		@LF  char(1) = char(10),
		@CR  char(1) = char(13),
		@SPC char(1) = ' ',
		@NO  char(1) = '.',
		@validate varchar(110),
		@puzzleId int

	SET @PuzzleString = replace(@PuzzleString, @TAB, '')
	SET @PuzzleString = replace(@PuzzleString, @LF , '')
	SET @PuzzleString = replace(@PuzzleString, @CR , '')
	SET @PuzzleString = replace(@PuzzleString, @SPC, '')
	SET @PuzzleString = replace(@PuzzleString, '0', @NO)

	IF(len(@PuzzleString) <> 81)
	BEGIN
		PRINT 'Validation failed. Expected length 81 cells, after whitespace striping.'

		RETURN
	END

	SET @validate = @PuzzleString
	SET @validate = replace(@validate, '1', '')
	SET @validate = replace(@validate, '2', '')
	SET @validate = replace(@validate, '3', '')
	SET @validate = replace(@validate, '4', '')
	SET @validate = replace(@validate, '5', '')
	SET @validate = replace(@validate, '6', '')
	SET @validate = replace(@validate, '7', '')
	SET @validate = replace(@validate, '8', '')
	SET @validate = replace(@validate, '9', '')
	SET @validate = replace(@validate, @NO, '')

	IF(len(@validate) > 0)
	BEGIN
		PRINT concat('Validation failed. Found unexpected character ', left(@validate,1), '(', ascii(left(@validate,1)), ').')

		RETURN
	END

	INSERT INTO Puzzles (
			puzzle
	) VALUES (
		@PuzzleString
	)

	SET @puzzleId = SCOPE_IDENTITY()

	EXEC Start_Puzzle @puzzleId
END

GO

/****** Object:  StoredProcedure [dbo].[Script_Puzzles] ******/
CREATE PROCEDURE [dbo].[Script_Puzzles] AS
BEGIN
	SELECT 
		script = concat(
			'INSERT INTO dbo.Puzzles ([puzzle], [comment], [page], [stars]) VALUES (''',
			[puzzle], 
			''', ''',
			[comment],
			''', ',
			[page],
			', ',
			[stars],
			')'
		)
	FROM dbo.Puzzles
END
GO

/****** Object:  StoredProcedure [dbo].[Show_Status] ******/
CREATE PROCEDURE [dbo].[Show_Status] 
	@WithPuzzle bit = 0
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @NO char(1) = '.'

	IF @WithPuzzle = 1
	BEGIN
		WITH cte_columns AS (
			SELECT 
				r = n.nr,
				[1] = CASE c WHEN 1 THEN cast(v AS CHAR) END,
				[2] = CASE c WHEN 2 THEN cast(v AS CHAR) END,
				[3] = CASE c WHEN 3 THEN cast(v AS CHAR) END,
				[4] = CASE c WHEN 4 THEN cast(v AS CHAR) END,
				[5] = CASE c WHEN 5 THEN cast(v AS CHAR) END,
				[6] = CASE c WHEN 6 THEN cast(v AS CHAR) END,
				[7] = CASE c WHEN 7 THEN cast(v AS CHAR) END,
				[8] = CASE c WHEN 8 THEN cast(v AS CHAR) END,
				[9] = CASE c WHEN 9 THEN cast(v AS CHAR) END
			FROM Numbers n
			LEFT JOIN Puzzle p --
			ON p.r = n.nr
			WHERE nr BETWEEN 1 AND 9
		)
		SELECT 
			[1] = isnull(max([1]), @NO),
			[2] = isnull(max([2]), @NO),
			[3] = isnull(max([3]), @NO),
			[4] = isnull(max([4]), @NO),
			[5] = isnull(max([5]), @NO),
			[6] = isnull(max([6]), @NO),
			[7] = isnull(max([7]), @NO),
			[8] = isnull(max([8]), @NO),
			[9] = isnull(max([9]), @NO)
		FROM cte_columns c
		GROUP BY r
		ORDER BY r
	END
	
	DECLARE --
		@Iteration binary(4) = ISNULL(CONTEXT_INFO(), 0x0),
		@OptionsLeft int,
		@CellSolved int

	SELECT @OptionsLeft = count(*) FROM Options
	SELECT @CellSolved = count(*) FROM Puzzle

	SELECT --
		[Iteration] = CAST(@Iteration AS int),
		[#CellsSolved] = @CellSolved,
		[Target] = 81,
		[%CellsSolved] = cast(100.0 * @CellSolved / 81.0 as decimal (9,1)),
		[#OptionsLeft ] = @OptionsLeft,
		[Total] = 728,
		[%OptionsLeft] = cast(100.0 * @OptionsLeft / 729.0 as decimal (9,1))

		SET @Iteration = @Iteration + 1
		SET CONTEXT_INFO @Iteration
END
GO

/****** Object:  StoredProcedure [dbo].[Solve_Puzzle] ******/
CREATE PROCEDURE [dbo].[Solve_Puzzle] --
AS
BEGIN
	SET NOCOUNT ON

	DECLARE --
		@OptionsBefore int = 729,
		@OptionsAfter int = 1,
		@CellSolved int = 0

	WHILE @OptionsBefore > @OptionsAfter AND @OptionsAfter > 0
	BEGIN
		SELECT @OptionsBefore = count(*) FROM [dbo].[Options]

		EXEC [dbo].[Reduce_Options]

		SELECT @OptionsAfter = count(*) FROM [dbo].[Options]

		IF(@OptionsBefore <> @OptionsAfter)
		BEGIN
			EXEC [dbo].[Show_Status] 1
		END
	END

	IF @OptionsAfter > 0
	BEGIN
		THROW 50000, 'I give up!', 0
	END

	SELECT @CellSolved = count(*) FROM Puzzle
	IF @CellSolved < 81
	BEGIN
		THROW 50000, 'I failed! :-(', 0
	END 
END
GO

/****** Object:  StoredProcedure [dbo].[Start_Puzzle] ******/
CREATE PROCEDURE [dbo].[Start_Puzzle] --
	@PuzzleId int = 0 -- last
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @NO char(1) = '.'

	IF(@PuzzleId = 0)
	BEGIN
		SELECT @PuzzleId = max(puzzleId) FROM [dbo].[Puzzles]
	END

	PRINT concat('Starting puzzle ', @PuzzleId)

	EXEC [dbo].[Reset_Options]

	TRUNCATE TABLE [dbo].[Puzzle]

	INSERT INTO Puzzle
	SELECT --
		m.[i],
		m.[r],
		m.[c],
		m.[s],
		v = substring(p.puzzle, m.i, 1)
	FROM Model m
	INNER JOIN [dbo].[Puzzles] p 
	ON substring(p.puzzle, m.i, 1) <> @NO
	WHERE p.puzzleId = @PuzzleId

	EXEC [dbo].[Update_Options]

	SET CONTEXT_INFO 0x0

	EXEC [dbo].[Show_Status] 1
END
GO

/****** Object:  StoredProcedure [dbo].[Update_Options] ******/
CREATE PROCEDURE [dbo].[Update_Options]
AS
BEGIN
	SET NOCOUNT ON

	DELETE o
	FROM Options o
	RIGHT JOIN Puzzle p
	ON p.i = o.i -- all options for this cell
	OR (p.r = o.r AND p.v = o.v) -- options in the row with same value
	OR (p.c = o.c AND p.v = o.v) -- options in the column with same value
	OR (p.s = o.s AND p.v = o.v) -- options in the section with same value
	WHERE p.i IS NOT NULL
END
GO

USE [master]
GO

ALTER DATABASE [Sudoku] SET READ_WRITE 
GO

USE [Sudoku]
GO

EXEC Init_Sudoku
GO