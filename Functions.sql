-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Dodawanie/usuwanie pracownikow

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Wyświetlanie informacji na temat poszczególnych wierszy we wszystkich tabelach (imie/nazwisko/stanowisko/ staż pracy/ zarobki/do kiedy umowa/ dni urlopu/ ilość dni na l4/ czy wykorzystano urlop 14dniowy)

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Wyświetlanie pracowników należących do poszczególnych zespołów

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Wyświetlanie wszystkich pracowników podglegających danemu kierownikowi

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Sprawdzenie ilości pracy zdalnej pobranych od początku roku

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Wyliczenie średniej liczby dni pracy zdalnej z dokładnością do .00 ( w skali miesiąca)

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Przyznawanie podwyżek pracownikom

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Zmiana pensji pojedyńczemu pracownikowi

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

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Zapewnienie aby po zmianie stanowiska pensja jest większa/równa minimalnym widełkom.

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Obliczenie średniej ilości pracy zdalnej

GO

CREATE OR ALTER FUNCTION AverageRemoteWork(
	@employee INT
) 
RETURNS DECIMAL(5,0)
AS
 BEGIN
 	DECLARE @worked_days INT, @worked_remote_days INT, @remote_days_percentage DECIMAL(5,2)
	SET @worked_days = 0
	------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE Kursor CURSOR FOR (SELECT hire_date, end_date FROM Contracts WHERE employee_id = @employee)
	DECLARE @start_date datetime, @end_date datetime
	DECLARE @working_days INT = 0

	OPEN Kursor
	FETCH NEXT FROM Kursor INTO @start_date, @end_date
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF (@end_date IS NULL) 
			BEGIN
				SET @end_date = GETDATE()
			END
		FETCH NEXT FROM Kursor INTO @start_date, @end_date
		
		SET @working_days = (SELECT(DATEDIFF(dd, @start_date, @end_date) + 1)-(DATEDIFF(wk, @start_date, @end_date) * 2)-(CASE WHEN DATENAME(dw, @start_date) = 'Sunday' THEN 1 ELSE 0 END)-(CASE WHEN DATENAME(dw, @end_date) = 'Saturday' THEN 1 ELSE 0 END))
		SET @worked_days = (@worked_days + @working_days)
	END

	CLOSE Kursor
	DEALLOCATE Kursor	
	------------------------------------------------------------------------------------------------------------------------------------------------------
	SET @worked_remote_days = (SELECT SUM(remote_work_used) FROM Job_history WHERE employee_id = @employee)
	SET @remote_days_percentage = CAST(@worked_days AS DECIMAL (9,2))/CAST(@worked_remote_days AS DECIMAL (9,2)) * 100
	RETURN @remote_days_percentage
 END
GO

SELECT DISTINCT employee_id, dbo.AverageRemoteWork(employee_id) as remote_days_percentage FROM Employees 
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

