-- language detection hint for Linguist
DECLARE @Linguist varchar(10) = 'T-SQL'

USE Sudoku
GO

DECLARE @Puzzle varchar(110) 

SET @Puzzle = '
008070050
020008700
040050903
003100000
400506008
000004600
209060010
007900060
080010500
'

EXEC Save_Puzzle @Puzzle
GO