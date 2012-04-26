#!/usr/bin/env ruby

# unitTestMaker is a script to generate PL/SQL unit tests.
# This script identifies procedures and their structure in order
# to create a valid anonymous block that declares all input and output
# variables and a call to the procedure. Output variables also have
# dbms_output.put_line calls generated.
#
# Note: I made this script as a basic ruby learning project. Please excuse any weirdness.
# --------------
# Current status: Getting basic algorithm down (testing it) while learning Ruby. 60% complete
class ProcVariable
  attr_accessor :name, :data_type, :in_out

  NUMERIC_TYPES = %w{
  number binary_integer dec
  double precision float
  int integer natural
  naturaln numeric pls_integer
  positive positiven real
  signtype smallint
  }

  CHAR_TYPES = %w{
  varchar2 char character
  long long raw nchar
  nvarchar2 raw rowid
  string urowid varchar
  varchar2
  }

  DATE_TYPES = %w{
  date
  }
  def initialize(name, data_type, in_out)
    @name = name.downcase
    @data_type = data_type.downcase
    @in_out = in_out.downcase
  end

  def get_local_name()
    "v_" + @name.gsub('p_', '')
  end

  def get_named_param_assignment
    @name + " => " + get_local_name

  end

  def get_var_declaration
    dec_str = get_local_name() + " " + @data_type
    if @in_out == 'out'
      dec_str << ';'
    else
      # IN and IN OUT parameters
      if NUMERIC_TYPES.include? @data_type
        dec_str << ' := 0;'
      elsif CHAR_TYPES.include? @data_type
        dec_str << '(2048) := \'\';'
      elsif DATE_TYPES.include? @data_type
        dec_str << ' := SYSDATE'
      else
        dec_str << ';'
      end
    end
    dec_str
  end
end

def generate_anon_block(procedure_name, parameters)
  named_param_assignments = Array.new
  
  anon_block = ""
  anon_block << "DECLARE\n"
  # Declare each local variable in PL/SQL and assign them default values if they're IN params
  # Also, generate the named parameter assignments for the procedure call
  parameters.each { |p|
    anon_block << "\t" + p.get_var_declaration() + "\n"
    named_param_assignments << p.get_named_param_assignment
  }
  # Begin anonymous block
  anon_block << "BEGIN\n"
  # Construct a call to the procedure using the parameters.
  anon_block << "\t" + procedure_name + "(\n"
  anon_block << "\t\t" + named_param_assignments.join(",\n\t\t") + "\n"
  anon_block << "\t);\n"
  
  # PL/SQL Finished
  anon_block << "END;\n"
  
  anon_block
end

ARGV.each do |value|
  proc_string = value.downcase

  if proc_string.index('procedure') == 0
    # remove procedure identifier from proc_string after identification
    proc_string 				= proc_string.gsub('procedure ', '')
    procedure_name 		= proc_string[0,proc_string.index('(')]
    parameters 				= Array.new

    # remove procedure name from proc_string after identification
    proc_string = proc_string.gsub(procedure_name, '')
    # remove parenthesis - not used for detection... but later check if they are there
    proc_string = proc_string.delete('()')

    # split parameter list by ','
    proc_string.split(',').each { |s|
    # for each parameter, split by ' in ' or ' out ' and identify param names and datatypes
      if s.index(' in out ') != nil
        in_out_params = s.split(' in out ')
        parameters << ProcVariable.new(in_out_params[0].strip, in_out_params[1].strip, 'in out')
      elsif s.index(' in ') != nil
        in_params = s.split(' in ')
        parameters << ProcVariable.new(in_params[0].strip, in_params[1].strip, 'in')
      elsif s.index(' out ') != nil
        out_params = s.split(' out ')
        parameters << ProcVariable.new(out_params[0].strip, out_params[1].strip, 'out')
      end
    }

    # Start outputting the script
    puts generate_anon_block(procedure_name, parameters)
  end

end