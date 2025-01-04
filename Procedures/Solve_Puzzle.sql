-- language detection hint for Linguist
DECLARE @Linguist varchar(10) = 'T-SQL'

USE Sudoku
GO

ALTER PROCEDURE Solve_Puzzle --
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
