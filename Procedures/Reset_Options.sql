ALTER PROCEDURE Reset_Options AS
BEGIN
	SET NOCOUNT ON

	TRUNCATE TABLE Options

	INSERT INTO Options
	SELECT 
		m.*,
		v = nr
	FROM Model m
	FULL JOIN Numbers n
	ON nr between 1 AND 9
	WHERE m.i IS NOT NULL
END