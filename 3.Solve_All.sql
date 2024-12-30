-- Test_all
USE Sudoku
GO

DECLARE --
	@total int,
	@rowNr int = 1,
	@puzzleId int

SELECT 
	rowNr = ROW_NUMBER() OVER (ORDER BY puzzleId),
	puzzleId
INTO #Work
FROM [dbo].[Puzzles]

SET @total = @@ROWCOUNT

WHILE NOT @rowNr > @total
BEGIN
	SELECT @puzzleId = puzzleId
	FROM #WORK
	WHERE rowNr = @rowNr

	EXEC Start_Puzzle @puzzleId

	EXEC Solve_Puzzle

	SET @rowNr = @rowNr + 1
END
