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
  attr_accessor :procVarName, :procVarDataType, :procVarInOut

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
  def initialize(procVarName, procVarDataType, procVarInOut)
    @procVarName = procVarName.downcase
    @procVarDataType = procVarDataType.downcase
    @procVarInOut = procVarInOut.downcase
  end

  def get_local_name()
    return "v_" + @procVarName.gsub('p_', '')
  end

  def get_named_param_assignment
    return @procVarName + " => " + get_local_name

  end

  def getVarDeclaration
    decStr = get_local_name() + " " + @procVarDataType
    if @procVarInOut == 'out'
      decStr << ';'
    else
      if NUMERIC_TYPES.include? @procVarDataType
        decStr << ' := 0;'
      elsif CHAR_TYPES.include? @procVarDataType
        decStr << ' := \'\';'
      elsif DATE_TYPES.include? @procVarDataType
        decStr << ' := SYSDATE';
      else
        decStr << ';'
      end
    end
    return decStr
  end
end

ARGV.each do |value|
  procString = value.downcase

  if procString.index('procedure') == 0
    # remove procedure identifier from procString after identification
    procString 				= procString.gsub('procedure ', '')
    procedureName 			= procString[0,procString.index('(')]
    parameters 				= Array.new
    named_param_assignments = Array.new

    puts "Procedure Name = " + procedureName
    # remove procedure name from procString after identification
    procString = procString.gsub(procedureName, '')
    # remove parenthesis - not used f|| detection... but later check if they are there
    procString = procString.delete('()')

    # split parameter list by ','
    procString.split(',').each { |s|
    # for each parameter, split by ' in ' or ' out ' and identify param names and datatypes
      if s.index(' in ') != nil
        inParams = s.split(' in ')
        puts "IN Param: " + s
        parameters << ProcVariable.new(inParams[0].strip, inParams[1].strip, 'in')
      elsif s.index(' out ') != nil
        outParams = s.split(' out ')
        puts "OUT Param: " + s
        parameters << ProcVariable.new(outParams[0].strip, outParams[1].strip, 'out')
      end
    }

    # Start outputting the script
    puts 'DECLARE'
    # Declare each local variable in PL/SQL and assign them default values if they're IN params
    # Also, generate the named parameter assignments for the procedure call
    parameters.each { |p|
      puts "\t" + p.getVarDeclaration()
      named_param_assignments << p.get_named_param_assignment
    }
    # Begin anonymous block
    puts 'BEGIN'
    # Construct a call to the procedure using the parameters.
    puts "\t" + procedureName + "("
    puts "\t\t" + named_param_assignments.join(",\n\t\t")
    puts "\t);"

    # PL/SQL Finished
    puts 'END;'

  end

end