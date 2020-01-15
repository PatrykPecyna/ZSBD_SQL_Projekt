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