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

USE HR_Bendig_Pecyna_Szubert_Michalak;
GO

CREATE TRIGGER ThreeMonthsTrialContract ON Employees AFTER INSERT AS BEGIN
DECLARE @vacation INT;
DECLARE @lastId INT;

SET @lastId = (SELECT employee_id FROM inserted);

IF ((SELECT Job_history.work_experience FROM Job_history WHERE Job_history.employee_id = @lastId) >= 10) 
	SET @vacation = 26 
ELSE
	SET @vacation = 20

INSERT INTO Contracts(employee_id, hire_date, end_date, vacation_days) VALUES (@lastId, GETDATE(), DATEADD(MONTH, 3, GETDATE()), @vacation)

END;

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Zapewnienie aby po zmianie stanowiska pensja jest większa/równa minimalnym widełkom.



-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Obliczenie średniej ilości pracy zdalnej

USE HR_Bendig_Pecyna_Szubert_Michalak;
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

USE HR_Bendig_Pecyna_Szubert_Michalak;
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
		UPDATE Employees SET salary += salary * @rise_percentage WHERE employee_id = @employee 
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

USE HR_Bendig_Pecyna_Szubert_Michalak;
GO

CREATE OR ALTER PROCEDURE RiseToOneWorker(
	@employee INT,
	@rise INT
) 
AS
 BEGIN
	DECLARE @rise_percentage DECIMAL(5,2) = @rise * 0.01
	UPDATE Employees SET salary += salary * @rise_percentage WHERE employee_id = @employee 	
 END
GO

EXEC RiseToOneWorker 1, 20
SELECT * FROM Employees
GO 

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Wyliczenie dni urlopu pracownikowi pracującemu niepełny rok.

USE HR_Bendig_Pecyna_Szubert_Michalak;
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