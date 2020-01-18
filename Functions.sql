USE HR_Bendig_Pecyna_Szubert_Michalak;
GO

---- Wyświetlenie pracowników, należących do poszczególnych zespołów
SELECT team_name, Employees.first_name, Employees.last_name FROM Teams LEFT JOIN Employees ON Employees.team_id = Teams.team_id

-----Policzenie ilu pracowników należy do danego zespołu
SELECT Teams.team_name, COUNT(Employees.employee_id) FROM Teams LEFT JOIN Employees ON Employees.team_id = Teams.team_id GROUP BY Teams.team_name

----Wyświetlenie jakimi zespołami zarządza dany manager
SELECT Employees.first_name, Employees.last_name, Teams.team_name FROM Teams RIGHT JOIN Employees ON Teams.manager_id = Employees.employee_id WHERE team_name IS NOT NULL

----Wyświetlenie pracowników podlegających pod danego managera
SELECT  manager.first_name AS 'manager_imie' ,manager.last_name AS 'manager_nazwisko', employee.first_name AS 'Pracownik_imie', employee.last_name AS 'Pracownik_nazwisko' FROM Employees AS employee JOIN Teams ON Teams.team_id = employee.team_id JOIN Employees AS manager ON Teams.manager_id = manager.employee_id ORDER BY manager.employee_id

----Sprawdzenie ile dni pracy zdalnej wykorzystał dany pracownik
SELECT Employees.employee_id, Employees.first_name, Employees.last_name, SUM(Remote_work.nr_days) AS 'Laczna_ilosc_dni' FROM Employees JOIN Remote_work ON Employees.employee_id = Remote_work.employee_id GROUP BY Employees.employee_id, Employees.first_name, Employees.last_name

----Wyświetlenie wszystkich pracowników zatrudnionych w danym miesiącu
SELECT YEAR(Contracts.hire_date) AS 'year', MONTH(Contracts.hire_date) AS 'month', Employees.first_name, Employees.last_name FROM Contracts JOIN Employees ON Contracts.employee_id = Employees.employee_id GROUP BY YEAR(Contracts.hire_date), MONTH(Contracts.hire_date), Employees.first_name, Employees.last_name

---- Wyświetlenie pracowników, którzy zarabiają pensję minimalną dla swjoego stanowiska
SELECT Employees.first_name, Employees.last_name, Contracts.salary, Positions.min_salary FROM Employees JOIN Contracts ON Contracts.employee_id = Employees.employee_id JOIN Positions ON Positions.position_id = Contracts.position_id WHERE Contracts.salary != Positions.min_salary;

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Wpisanie z automatu pracownikowi 20-u dni urlopu lub odpowiednio mniej w przypadku rozpoczecia pracy w srodku roku, poprawki do 26-u dni manualnie po otrzymaniu swiadectwa pracy.

USE HR_Bendig_Pecyna_Szubert_Michalak;
GO

CREATE TRIGGER UpdateVacationDays ON Job_history AFTER UPDATE AS BEGIN
DECLARE @employeeId INT;
DECLARE @experience INT;
DECLARE @vacationDays INT;
DECLARE @actualContractId INT;
DECLARE @hireTime INT;

SET @employeeId = (SELECT employee_id FROM inserted);
SET @experience = (SELECT work_experience FROM Job_history WHERE Job_history.employee_id = @employeeId)
SET @actualContractId = (SELECT TOP 1 contract_id FROM Contracts WHERE Contracts.employee_id = @employeeId ORDER BY end_date DESC)
IF (@experience < 120) SET @vacationDays = 20 ELSE SET @vacationDays = 26

SET @hireTime = (SELECT DATEDIFF(MONTH, end_date, hire_date) FROM Contracts WHERE contract_id = @actualContractId);
IF (@hireTime < 12) SET @vacationDays = CEILING((12-@hireTime)/12*@vacationDays);

UPDATE Contracts SET vacation_days = @vacationDays WHERE Contracts.contract_id = @actualContractId

END;

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Sprawdzenie ile urlopu pozostalo

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Zapewnienie ze po dodaniu nowego pracownika zostanie wpisany 3miesięczny okres próbny

GO

CREATE TRIGGER ThreeMonthsTrialContract ON Employees AFTER INSERT AS BEGIN
DECLARE @vacation INT;
DECLARE @lastId INT;

SET @lastId = (SELECT employee_id FROM inserted);

IF ((SELECT Job_history.work_experience FROM Job_history WHERE Job_history.employee_id = @lastId) >= 10) 
	SET @vacation = 26 
ELSE
	SET @vacation = 20

IF ((SELECT COUNT(contract_id) FROM Contracts WHERE employee_id = @lastId) = 0)
	BEGIN
	INSERT INTO Contracts(employee_id, hire_date, end_date, vacation_days) VALUES (@lastId, GETDATE(), DATEADD(MONTH, 3, GETDATE()), @vacation)
	END;
END;

GO
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Zapewnienie aby po zmianie stanowiska pensja jest większa/równa minimalnym widełkom.

CREATE TRIGGER MinSalary ON Contracts AFTER INSERT AS BEGIN
DECLARE @employeeId INT;
DECLARE @salary money;
DECLARE @position INT;
DECLARE @contract_id INT;
DECLARE @min_salary money;

SET @employeeId = (SELECT employee_id FROM inserted);
SET @position = (SELECT position_id FROM inserted);
SET @salary = (SELECT salary FROM inserted);
SET @contract_id = (SELECT contract_id FROM inserted);
SET @min_salary = (SELECT min_salary FROM Positions WHERE position_id = @position);

IF (@salary IS NULL OR @salary < @min_salary)
	UPDATE Contracts SET salary = @min_salary WHERE contract_id = @contract_id;

END;


-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Obliczenie średniej ilości pracy zdalnej

GO

CREATE OR ALTER FUNCTION AverageRemoteWork(
	@employee INT,
	@month INT,
	@year INT
) 
RETURNS DECIMAL(5,0)
AS
 BEGIN
 	DECLARE @worked_days_this_month INT = 0, @remote_days_this_month INT = 0, @vacations_days_this_month INT = 0, @remote_days_percentage DECIMAL(5,2)
	DECLARE @month_start date = DATEFROMPARTS(@year, @month ,1), @month_end date = EOMONTH(DATEFROMPARTS(@year, @month ,1))
	
	------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE KursorRemoteDays CURSOR FOR (SELECT nr_days FROM Remote_work WHERE employee_id = @employee)
	DECLARE @remote_days_from_cursor INT = 0

	OPEN KursorRemoteDays
	FETCH NEXT FROM KursorRemoteDays INTO @remote_days_from_cursor
	WHILE @@FETCH_STATUS = 0
	BEGIN
		FETCH NEXT FROM KursorRemoteDays INTO @remote_days_from_cursor
		SET @remote_days_this_month = (@remote_days_this_month + @remote_days_from_cursor)
	END

	CLOSE KursorRemoteDays
	DEALLOCATE KursorRemoteDays	
	------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE KursorVacations CURSOR FOR (SELECT nr_days FROM Vacations WHERE employee_id = @employee)
	DECLARE @vacation_days_from_cursor INT = 0

	OPEN KursorVacations
	FETCH NEXT FROM KursorVacations INTO @vacation_days_from_cursor
	WHILE @@FETCH_STATUS = 0
	BEGIN
		FETCH NEXT FROM KursorVacations INTO @vacation_days_from_cursor
		SET @vacations_days_this_month = (@vacations_days_this_month + @vacation_days_from_cursor)
	END

	CLOSE KursorVacations
	DEALLOCATE KursorVacations
	------------------------------------------------------------------------------------------------------------------------------------------------------
	SET @worked_days_this_month = (SELECT(DATEDIFF(dd, @month_start, @month_end) + 1)-(DATEDIFF(wk, @month_start, @month_end) * 2)-(CASE WHEN DATENAME(dw, @month_start) = 'Sunday' THEN 1 ELSE 0 END)-(CASE WHEN DATENAME(dw, @month_end) = 'Saturday' THEN 1 ELSE 0 END))
	SET @worked_days_this_month = @worked_days_this_month - @vacations_days_this_month
	IF (@remote_days_this_month <> 0)
	BEGIN
		SET @remote_days_percentage = CAST(@remote_days_this_month AS DECIMAL (9,2))/CAST(@worked_days_this_month AS DECIMAL (9,2)) * 100
	END
	RETURN @remote_days_percentage
 END
GO

SELECT DISTINCT employee_id, dbo.AverageRemoteWork(employee_id, 1, 2019) as remote_days_percentage FROM Employees 
GO

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Możliwość przyznania podwyżki wszystkim pracownikom na raz. Podwyżka przyznawana procentowo na bazie obecnych zarobków każdego pracownika

GO

CREATE OR ALTER PROCEDURE RiseToAllWorkers(
	@rise INT
) 
AS
 BEGIN
	DECLARE Kursor CURSOR FOR (SELECT employee_id FROM Employees)
	DECLARE @employee INT
	DECLARE @rise_percentage DECIMAL(5,2) = @rise * 0.01

	OPEN Kursor
	FETCH NEXT FROM Kursor INTO @employee
	WHILE @@FETCH_STATUS = 0
	BEGIN
		UPDATE Contracts SET salary += salary * @rise_percentage WHERE employee_id = @employee AND contract_id = (SELECT TOP 1 contract_id FROM Contracts WHERE employee_id = @employee ORDER BY end_date DESC)
		FETCH NEXT FROM Kursor INTO @employee
	END

	CLOSE Kursor
	DEALLOCATE Kursor	
 END
GO

EXEC RiseToAllWorkers 20
SELECT * FROM Employees
GO 

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Możliwość przyznania podwyżki pojedyńczemu pracownikowi. Można wpisać interesująca wysokość podwyżki

GO

CREATE OR ALTER PROCEDURE RiseToOneWorker(
	@employee INT,
	@rise INT
) 
AS
 BEGIN
	DECLARE @rise_percentage DECIMAL(5,2) = @rise * 0.01
		UPDATE Contracts SET salary += salary * @rise_percentage WHERE employee_id = @employee AND contract_id = (SELECT TOP 1 contract_id FROM Contracts WHERE employee_id = @employee ORDER BY end_date DESC)
 END
GO

EXEC RiseToOneWorker 1, 20
SELECT * FROM Employees
GO 

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Wyliczenie dni urlopu pracownikowi pracującemu niepełny rok.

GO

CREATE OR ALTER FUNCTION CalculateVacationDays(
	@employee INT
) 
RETURNS INT
AS	
 BEGIN
	DECLARE @actual_contract_hire_date datetime, @vacation_days INT, @vacation_days_left INT, @days_passed_from_hire INT;
	SET @actual_contract_hire_date = (SELECT TOP 1 hire_date FROM Contracts WHERE Contracts.employee_id = @employee ORDER BY end_date DESC)
	SET @vacation_days_left = (SELECT TOP 1 vacation_days FROM Contracts WHERE Contracts.employee_id = @employee ORDER BY end_date DESC) - (SELECT vacation_used FROM Job_history WHERE Job_history.employee_id = @employee)
	IF (DATEDIFF(year, @actual_contract_hire_date, GETDATE()) = 0) 
	BEGIN
		SET @days_passed_from_hire = (SELECT DATEDIFF(day, @actual_contract_hire_date, GETDATE()))
		SET @vacation_days_left = @vacation_days_left * (@days_passed_from_hire / 365)
	END
	RETURN @vacation_days_left
 END
GO

SELECT DISTINCT employee_id, dbo.CalculateVacationDays(employee_id) as 'Vacation Days Left' FROM Employees 
GO 


--------------------------------------------------------------------------------------------------------------------
---- Utworzenie job history dla nowego pracownika
GO

CREATE TRIGGER CreateJobHistoryForNewEmployee ON Employees AFTER INSERT AS BEGIN
DECLARE @employeeId INT;
SET @employeeId = (SELECT employee_id FROM inserted);

INSERT INTO Job_history(employee_id, vacation_used, remote_work_used, sick_days_used, work_experience) VALUES (@employeeId, 0, 0, 0, 0)

END;
GO

----- Aktualizacja doświadczenia przy dodaniu nowej umowy o pracę ------------------------------------------------------------------
CREATE TRIGGER UpdateWorkExperience ON Contracts AFTER INSERT AS BEGIN
DECLARE @employeeId INT;
DECLARE @experience_old INT;
DECLARE @experience_add INT;

SET @employeeId = (SELECT employee_id FROM inserted);
SET @experience_add = (SELECT DATEDIFF(MONTH, end_date, hire_date) FROM Contracts WHERE Contracts.employee_id = @employeeId);
SET @experience_old = (SELECT work_experience FROM Job_history WHERE Job_history.employee_id = @employeeId);

UPDATE Job_history SET work_experience = @experience_old + @experience_add WHERE Job_history.employee_id = @employeeId;

END;

