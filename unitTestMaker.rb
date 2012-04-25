#!/usr/bin/env ruby

# unitTestMaker is a script to generate PL/SQL unit tests.
# This script identifies procedures and their structure in order
# to create a valid anonymous block that declares all input and output
# variables and a call to the procedure. Output variables also have
# dbms_output.put_line calls generated.
#
# Note: I made this script as a basic ruby learning project. Please excuse any weirdness.
# --------------
# Current status: Getting basic algorithm down (testing it) while learning Ruby. 60% complete.
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
    return "v_" + @name.gsub('p_', '')
  end

  def get_named_param_assignment
    return @name + " => " + get_local_name

  end

  def getVarDeclaration
    decStr = get_local_name() + " " + @data_type
    if @in_out == 'out'
      decStr << ';'
    else
      # IN and IN OUT parameters
      if NUMERIC_TYPES.include? @data_type
        decStr << ' := 0;'
      elsif CHAR_TYPES.include? @data_type
        decStr << ' := \'\';'
      elsif DATE_TYPES.include? @data_type
        decStr << ' := SYSDATE';
      else
        decStr << ';'
      end
    end
    return decStr
  end
end

def generate_anon_block(procedureName, parameters)
  named_param_assignments = Array.new
  
  anonBlock = ""
  anonBlock << "DECLARE\n"
  # Declare each local variable in PL/SQL and assign them default values if they're IN params
  # Also, generate the named parameter assignments for the procedure call
  parameters.each { |p|
    anonBlock << "\t" + p.getVarDeclaration() + "\n"
    named_param_assignments << p.get_named_param_assignment
  }
  # Begin anonymous block
  anonBlock << "BEGIN\n"
  # Construct a call to the procedure using the parameters.
  anonBlock << "\t" + procedureName + "(\n"
  anonBlock << "\t\t" + named_param_assignments.join(",\n\t\t") + "\n"
  anonBlock << "\t);\n"
  
  # PL/SQL Finished
  anonBlock << "END;\n"
  
  return anonBlock;
end

ARGV.each do |value|
  procString = value.downcase

  if procString.index('procedure') == 0
    # remove procedure identifier from procString after identification
    procString 				= procString.gsub('procedure ', '')
    procedureName 		= procString[0,procString.index('(')]
    parameters 				= Array.new

    # remove procedure name from procString after identification
    procString = procString.gsub(procedureName, '')
    # remove parenthesis - not used for detection... but later check if they are there
    procString = procString.delete('()')

    # split parameter list by ','
    procString.split(',').each { |s|
    # for each parameter, split by ' in ' or ' out ' and identify param names and datatypes
      if s.index(' in out ') != nil
        inOutParams = s.split(' in out ')
        parameters << ProcVariable.new(inOutParams[0].strip, inOutParams[1].strip, 'in out')
      elsif s.index(' in ') != nil
        inParams = s.split(' in ')
        parameters << ProcVariable.new(inParams[0].strip, inParams[1].strip, 'in')
      elsif s.index(' out ') != nil
        outParams = s.split(' out ')
        parameters << ProcVariable.new(outParams[0].strip, outParams[1].strip, 'out')
      end
    }

    # Start outputting the script
    puts generate_anon_block(procedureName, parameters)
  end

end