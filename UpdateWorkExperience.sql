USE HR_Bendig_Pecyna_Szubert_Michalak;
GO

CREATE TRIGGER UpdateWorkExperience ON Contracts AFTER INSERT AS BEGIN
DECLARE @employeeId INT;
DECLARE @experience_old INT;
DECLARE @experience_add INT;

SET @employeeId = (SELECT employee_id FROM inserted);
SET @experience_add = (SELECT DATEDIFF(MONTH, end_date, hire_date) FROM Contracts WHERE Contracts.employee_id = @employeeId);
SET @experience_old = (SELECT work_experience FROM Job_history WHERE Job_history.employee_id = @employeeId);

UPDATE Job_history SET work_experience = @experience_old + @experience_add WHERE Job_history.employee_id = @employeeId;

END;