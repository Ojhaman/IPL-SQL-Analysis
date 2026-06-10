-- Creating Database
CREATE DATABASE ipl_project;
USE ipl_project;

-- Importing Dataset using the import widget

-- Checking for import
SHOW TABLES;
SELECT * FROM deliveries LIMIT 10;

-- Data Cleaning
-- 1) Check Structure
DESC deliveries;
ALTER TABLE deliveries RENAME COLUMN `over` TO over_no; -- OVER is a keyword
-- 2) Check for NULL values (all at once) & then handle NULLS
SELECT COUNT(*) AS total_rows,
COUNT(match_no) AS match_no_not_null,
COUNT(striker) AS striker_not_null,
COUNT(bowler) AS bowler_not_null,
COUNT(extras) AS extras_not_null
FROM deliveries;  -- If count < total_rows then NULL exists
-- 3) Check duplicates
SELECT match_no, over_no, striker, COUNT(*)
FROM deliveries
GROUP BY match_no, over_no, striker
HAVING COUNT(*) > 1;
-- 4) Viewing diplicates
SELECT * FROM deliveries
WHERE (match_no, innings, over_no, striker) IN 
	(SELECT match_no, innings, over_no, striker FROM deliveries GROUP BY match_no, innings, over_no, striker
    HAVING COUNT(*) > 1
);
-- 5) Removing duplicates
CREATE TABLE clean_data AS
SELECT *
FROM(
	SELECT *, ROW_NUMBER() OVER(PARTITION BY match_no, innings, over_no, striker ORDER BY match_no) AS row_num
    FROM deliveries
    ) AS t 
    WHERE row_num = 1;
DROP TABLE deliveries;
RENAME TABLE clean_data TO deliveries;

-- Standardising of data
SELECT DISTINCT venue FROM deliveries;
SELECT DISTINCT striker, COUNT(*) FROM deliveries GROUP BY striker ORDER BY COUNT(*);
SELECT COUNT(*) FROM deliveries;

SELECT `date` , STR_TO_DATE(`date`, '%M %e, %Y') AS `Date` FROM deliveries;
SET SQL_SAFE_UPDATES =0;
UPDATE deliveries SET `date` = STR_TO_DATE(`date`, '%M %e, %Y');
SELECT `Date` FROM deliveries;

ALTER TABLE deliveries
MODIFY COLUMN `date` DATE;


-- Exploratory Data Analysis
-- 1) Total matches
SELECT COUNT(DISTINCT match_no) AS total_matches
FROM deliveries;
-- 2) Total runs
SELECT COUNT(runs_of_bat + extras) AS total_runs
FROM deliveries;
-- 3) Total wickets
SELECT COUNT(wicket_type) 
FROM deliveries
WHERE wicket_type IS NOT NULL;
-- 4) Matches per venue
SELECT venue, COUNT(DISTINCT match_no) AS matches
FROM deliveries
GROUP BY venue
ORDER BY matches DESC;
-- 5) Top batsman
SELECT striker, SUM(runs_of_bat) AS runs_scored
FROM deliveries
GROUP BY striker
ORDER BY runs_scored DESC
LIMIT 10;
-- 6) Striker rate
SELECT striker, (SUM(runs_of_bat)*100)/COUNT(*) AS strike_rate
FROM deliveries
GROUP BY striker
HAVING COUNT(*) > 50
ORDER BY strike_rate DESC;
-- 7) Boundaries
SELECT striker, SUM( CASE WHEN runs_of_bat = 4 THEN 1 ELSE 0 END) AS fours, SUM( CASE WHEN runs_of_bat = 6 THEN 1 ELSE 0 END) AS sixes
FROM deliveries
GROUP BY striker
ORDER BY fours DESC;
-- 8) Top bowler
SELECT bowler, COUNT(*) AS wickets
FROM deliveries
WHERE wicket_type IS NOT NULL
GROUP BY bowler
ORDER BY wickets DESC;
-- 9) Economy
SELECT bowler, (SUM(runs_of_bat + extras) *6/COUNT(*)) AS economy
FROM deliveries
GROUP BY bowler
HAVING COUNT(*) > 30
ORDER BY economy DESC;
-- 10) Powerplay analysis
SELECT bowler, SUM(runs_of_bat + extras)*6/COUNT(*) AS economy_powerplay
FROM deliveries
WHERE over_no <= 6
GROUP BY bowler
ORDER BY economy_powerplay DESC;
-- 11) Death over analysis
SELECT bowler, SUM(runs_of_bat + extras)*6/COUNT(*) AS economy_death
FROM deliveries
WHERE over_no BETWEEN 16 AND 20
GROUP BY bowler
ORDER BY economy_death DESC;
-- 12) Batting team analysis
SELECT batting_team, SUM(runs_of_bat + extras) AS total_runs
FROM deliveries
GROUP BY batting_team
ORDER BY total_runs DESC;

SELECT bowling_team, SUM(runs_of_bat + extras) AS runs_conceded
FROM deliveries
GROUP BY bowling_team
ORDER BY runs_conceded DESC;
-- 13) Phase analysis
SELECT *,
CASE
	WHEN over_no BETWEEN 1 AND 6 THEN 'Powerplay'
    WHEN over_no BETWEEN 7 AND 15 THEN 'Middle'
    ELSE 'Death'
END AS Phase
FROM deliveries;
-- 14) Phase comparison
SELECT 'Powerplay' AS Phase, SUM(runs_of_bat) AS runs
FROM deliveries
WHERE over_no BETWEEN 1 AND 6
UNION
SELECT 'Death', SUM(runs_of_bat)
FROM deliveries
WHERE over_no BETWEEN 16 AND 20;


-- Window Functions
-- 1) Player ranking
SELECT striker, SUM(runs_of_bat) AS runs, RANK() OVER( ORDER BY SUM(runs_of_bat) DESC ) AS `rank`
FROM deliveries
GROUP BY striker;
-- 2) Running score
SELECT match_no, over_no, SUM(runs_of_bat) OVER ( PARTITION BY match_no ORDER BY over_no) AS running_score
FROM deliveries;


-- CTEs
WITH player_runs AS (
	SELECT striker, SUM(runs_of_bat) AS runs
    FROM deliveries
    GROUP BY striker
)
SELECT *
FROM player_runs
WHERE runs> 20
ORDER BY runs;


-- Subquery
SELECT striker, SUM(runs_of_bat) AS runs
FROM deliveries
GROUP BY striker
HAVING runs > (
	SELECT AVG(total_runs)
    FROM (
		SELECT SUM(runs_of_bat) AS total_runs
        FROM deliveries
        GROUP BY striker
	) t
);


-- Temp table
CREATE TEMPORARY TABLE players 
SELECT striker, SUM(runs_of_bat) AS runs
FROM deliveries
GROUP BY striker;


-- Stored Procedure
DELIMITER %%
CREATE PROCEDURE top_batsmen()
BEGIN 
	SELECT striker, SUM(runs_of_bat) AS runs
    FROM deliveries
    GROUP BY striker
    ORDER BY runs DESC
    LIMIT 10;
END %%

DELIMITER ;

CALL top_batsmen();


-- Trigger
CREATE TRIGGER check_runs
BEFORE INSERT ON deliveries
FOR EACH ROW
SET NEW.runs_of_bat = IF(NEW.runs_of_bat <0, 0, NEW.runs_of_bat);

