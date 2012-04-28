procedure employee_pkg.update_ssn(p_employee_id in number,
                                    p_employee_ssn in varchar2,
                                    p_status out varchar2,
                                    p_message out varchar2,
                                    p_msg_count out number,
                                    p_change_id out number);

procedure employee_pkg.update_salary(p_employee_id in number,
                                    p_employee_ssn in number,
                                    p_effective_date in out date,
                                    p_status out varchar2,
                                    p_message out varchar2,
                                    p_msg_count out number,
                                    p_change_id out number);