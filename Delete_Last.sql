DECLARE @Puzzle int = 0 -- last

SELECT @Puzzle = max(puzzleId) FROM [dbo].[Puzzles]

SELECT 
	'DELETED', *
FROM puzzles 
WHERE puzzleId = @Puzzle

DELETE puzzles 
WHERE puzzleId = @Puzzle
