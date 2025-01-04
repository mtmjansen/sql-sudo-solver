-- language detection hint for Linguist
DECLARE @Linguist varchar(10) = 'T-SQL'

USE [Sudoku]
GO

EXEC Start_Puzzle 

EXEC Solve_Puzzle
