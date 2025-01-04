USE Sudoku
GO

ALTER PROCEDURE Show_Status 
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
