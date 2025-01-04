-- language detection hint for Linguist
DECLARE @Linguist varchar(10) = 'T-SQL'

USE Sudoku
GO

ALTER PROCEDURE Reset_Options AS
BEGIN
	SET NOCOUNT ON

	TRUNCATE TABLE Options

	INSERT INTO Options
	SELECT 
		m.*,
		v = nr
	FROM Model m
	INNER JOIN Numbers n
	ON nr between 1 AND 9
END
GO
