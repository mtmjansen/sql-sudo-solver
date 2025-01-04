USE Sudoku
GO

ALTER PROCEDURE Start_Puzzle --
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


