-- language detection hint for Linguist
DECLARE @Linguist varchar(10) = 'T-SQL'

USE Sudoku
GO

ALTER PROCEDURE Update_Options
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
