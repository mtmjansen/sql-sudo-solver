-- language detection hint for Linguist
DECLARE @Linguist varchar(10) = 'T-SQL'

USE Sudoku
GO

ALTER VIEW Looks AS
-- format a look that can be used with LIKE
SELECT --
	m.i,
	m.r,
	m.c,
	m.s,
	look = string_agg(isnull(cast(o.v as char(1)), '_'),'-') WITHIN GROUP ( ORDER BY n.nr ),
	#v = count(o.v)
FROM Numbers n
INNER JOIN Model m --
ON m.i IS NOT NULL -- all combinations
LEFT JOIN Options o --
ON o.i = m.i
AND o.v = n.nr
WHERE n.nr BETWEEN 1 AND 9
GROUP BY --
	m.i,
	m.r,
	m.c,
	m.s
HAVING count(o.v) BETWEEN 1 AND 8
GO
