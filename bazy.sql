if exists(select 1 from master.dbo.sysdatabases where name = 'HR_Bendig_Pecyna_Szubert_Michalak') drop database HR_Bendig_Pecyna_Szubert_Michalak
GO
CREATE DATABASE HR_Bendig_Pecyna_Szubert_Michalak
GO

CREATE TABLE HR_Bendig_Pecyna_Szubert_Michalak..Employees(
	employee_id		int				IDENTITY(1,1),
	first_name		varchar(20),
	last_name		varchar(20),
	phone_number	varchar(9),
	salary			money,
	team_id			int,
	position_id		int,

	CONSTRAINT PK_employee_id PRIMARY KEY (employee_id),
);

CREATE TABLE HR_Bendig_Pecyna_Szubert_Michalak..Vacations(
	vacation_id		int				IDENTITY(1,1),
	start_date		date,
	end_date		date,
	nr_days			int,
	employee_id		int,

	CONSTRAINT PK_vacation_id PRIMARY KEY (vacation_id),
	CONSTRAINT FKvacations_employee_id FOREIGN KEY (employee_id) REFERENCES HR_Bendig_Pecyna_Szubert_Michalak..Employees (employee_id)
);

CREATE TABLE HR_Bendig_Pecyna_Szubert_Michalak..Remote_work(
	rw_id			int				IDENTITY(1,1),
	start_date		date,
	end_date		date,
	nr_days			int,
	employee_id		int,

	CONSTRAINT PK_rw_id PRIMARY KEY (rw_id),
	CONSTRAINT FKremote_work_employee_id FOREIGN KEY (employee_id) REFERENCES HR_Bendig_Pecyna_Szubert_Michalak..Employees (employee_id)
);

CREATE TABLE HR_Bendig_Pecyna_Szubert_Michalak..Sick_leave(
	sl_id			int				IDENTITY(1,1),
	start_date		date,
	end_date		date,
	nr_days			int,
	employee_id		int,

	CONSTRAINT PK_sl_id PRIMARY KEY (sl_id),
	CONSTRAINT FKsick_leave_employee_id FOREIGN KEY (employee_id) REFERENCES HR_Bendig_Pecyna_Szubert_Michalak..Employees (employee_id)
);

CREATE TABLE HR_Bendig_Pecyna_Szubert_Michalak..Contracts(
	contract_id		int				IDENTITY(1,1),
	employee_id		int,
	hire_date		date,
	end_date		date,
	vacation_days	int,

	CONSTRAINT PK_contract_id PRIMARY KEY (contract_id),
	CONSTRAINT FKcontracts_employee_id FOREIGN KEY (employee_id) REFERENCES HR_Bendig_Pecyna_Szubert_Michalak..Employees (employee_id)
);

CREATE TABLE HR_Bendig_Pecyna_Szubert_Michalak..Job_history(
	job_id			int				IDENTITY(1,1),
	employee_id		int,
	vacation_used	int,
	remote_work_used int,
	sick_days_used	int,
	work_experience	int,

	CONSTRAINT PK_job_id PRIMARY KEY (job_id),
	CONSTRAINT FKjob_history_employee_id FOREIGN KEY (employee_id) REFERENCES HR_Bendig_Pecyna_Szubert_Michalak..Employees (employee_id)
);

CREATE TABLE HR_Bendig_Pecyna_Szubert_Michalak..Positions(
	position_id		int				IDENTITY(1,1),
	min_salary		money,
	max_salary		money,
	remote_work_days int,

	CONSTRAINT PK_position_id PRIMARY KEY (position_id),
);

CREATE TABLE HR_Bendig_Pecyna_Szubert_Michalak..Departments(
	department_id		int			IDENTITY(1,1),
	department_name		varchar(30),
	city_name			varchar(30),

	CONSTRAINT PK_department_id PRIMARY KEY (department_id),
);

CREATE TABLE HR_Bendig_Pecyna_Szubert_Michalak..Teams(
	team_id			int				IDENTITY(1,1),
	team_name		varchar(30),
	manager_id		int,
	department_id	int,

	CONSTRAINT PK_team_id PRIMARY KEY (team_id),
	CONSTRAINT FKteams_manager_id FOREIGN KEY (manager_id) REFERENCES HR_Bendig_Pecyna_Szubert_Michalak..Employees (employee_id),
	CONSTRAINT FKteams_department_id FOREIGN KEY (department_id) REFERENCES HR_Bendig_Pecyna_Szubert_Michalak..Departments (department_id)
);

ALTER TABLE  HR_Bendig_Pecyna_Szubert_Michalak..Employees ADD FOREIGN KEY (team_id) REFERENCES HR_Bendig_Pecyna_Szubert_Michalak..Teams (team_id);
ALTER TABLE  HR_Bendig_Pecyna_Szubert_Michalak..Employees ADD FOREIGN KEY (position_id) REFERENCES HR_Bendig_Pecyna_Szubert_Michalak..Positions (position_id);


GO