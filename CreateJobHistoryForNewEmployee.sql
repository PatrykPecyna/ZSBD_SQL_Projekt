USE HR_Bendig_Pecyna_Szubert_Michalak;
GO

CREATE TRIGGER CreateJobHistoryForNewEmployee ON Employees AFTER INSERT AS BEGIN
DECLARE @employeeId INT;
SET @employeeId = (SELECT employee_id FROM inserted);

INSERT INTO Job_history(employee_id, vacation_used, remote_work_used, sick_days_used, work_experience) VALUES (@employeeId, 0, 0, 0, 0)

END;
GO