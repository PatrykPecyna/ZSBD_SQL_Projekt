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