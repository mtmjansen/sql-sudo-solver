USE Sudoku
GO

ALTER PROCEDURE Script_Puzzles AS
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
