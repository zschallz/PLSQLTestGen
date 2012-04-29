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
class PLVariable
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
    @name       = name.downcase
    @data_type  = data_type.downcase
    @in_out     = in_out.downcase
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
        dec_str << ' := SYSDATE;'
      else
        dec_str << ';'
      end
    end
    dec_str
  end
end

class PLProcedure
  attr_accessor :name, :parameters, :type

  def initialize(name, parameters, type)
    @name           = name.downcase
    @procedures     = parameters
    if %w[procedure function].include? type.downcase
      @type         = type.downcase
    else
      raise ArgumentError, 'Expected type of function or procedure, but got: ' << type
    end
  end

  # Takes a string of a procedure signature and creates a PLProcedure Method for it.
  def self.process_procedure(string)
    proc_string       = string.downcase
    # remove procedure identifier from proc_string after identification
    proc_string 			= proc_string.gsub('procedure ', '')
    procedure_name 		= proc_string[0,proc_string.index('(')]
    parameters 				= Array.new


    # remove procedure name from proc_string after identification
    proc_string       = proc_string.gsub(procedure_name, '')
    # remove parenthesis - not used for detection... but later check if they are there
    proc_string       = proc_string.delete('()')

    # split parameter list by ','
    proc_string.split(',').each { |s|
      # for each parameter, split by ' in ', ' out ', or ' in out ' and identify param names and datatypes
      if s.index(' in out ') != nil
        in_out_params = s.split(' in out ')
        parameters    << PLVariable.new(in_out_params[0].strip, in_out_params[1].strip, 'in out')
      elsif s.index(' in ') != nil
        in_params     = s.split(' in ')
        parameters    << PLVariable.new(in_params[0].strip, in_params[1].strip, 'in')
      elsif s.index(' out ') != nil
        out_params    = s.split(' out ')
        parameters    << PLVariable.new(out_params[0].strip, out_params[1].strip, 'out')
      end
    }

    # Start outputting the script
    #puts generate_anon_block(procedure_name, parameters)
    PLProcedure.new(procedure_name, parameters, 'procedure')

  end

  # Returns an anonymous block for this procedure as a string.
  def generate_anon_block(package_name)
    named_param_assignments = Array.new

    anon_block = ""
    anon_block << "DECLARE\n"
    # Declare each local variable in PL/SQL and assign them default values if they're IN params
    # Also, generate the named parameter assignments for the procedure call
    @procedures.each { |p|
      anon_block << "\t" + p.get_var_declaration() + "\n"
      named_param_assignments << p.get_named_param_assignment
    }
    # Begin anonymous block
    anon_block << "BEGIN\n"
    # Construct a call to the procedure using the parameters.
    anon_block << "\t" + package_name + "." + @name + "(\n"
    anon_block << "\t\t" + named_param_assignments.join(",\n\t\t") + "\n"
    anon_block << "\t);\n"

    # Anon Block Finished
    anon_block << "END;\n"

    anon_block
  end

  def write_anon_block_to_file(filename, package_name)
    file = File.new(filename, "w")

    file.puts(generate_anon_block(package_name))
    file.close
  end
end

class PackageSpec

  attr_accessor :name, :procedures

  def initialize(name, procedures)
    @name           = name.downcase
    @procedures     = procedures
  end

  # Takes an open file object representing a package specification and reads it line by line to find procedures.
  def self.parse_package_spec(file)
    procedures = Array.new
    proc_string = ''
    parsing_object  = false
    parsing_name    = false
    procedure_name  = nil
    package_name    = nil
    line_num = 0

    # read file line by line
    while( line = file.gets )
      line_num += 1
      if parsing_name
        temp_line = line
        # Get next word
        package_name = temp_line.split(' ')[0]
        parsing_name = false
      else
        # If procedure name has not yet been parsed, we are not currently parsing, and we find the word package
        if package_name == nil && parsing_name == false &&  line.index('package ')
          parsing_name = true

          temp_line = line
          # Remove 'package' from the line strip and strip any white spaces left over before the next word
          temp_line = temp_line.gsub('package', "")
          temp_line = temp_line.lstrip

          # Get next word on line. If it does not exist, nil should be returned
          package_name = temp_line.split(' ')[0]
          if package_name != nil
            parsing_name = false
          end
        end
      end
      # when we find 'procedure ' or 'function ' and not already parsing an object
      # ignore keywords procedure and function if already processing so that variable/object names don't throw us off
      if parsing_object == false
        if line.index('procedure ') != nil || line.index('function ') != nil
          # start storing the pl/sql object signature until we find ;
          parsing_object = true
          if line.index(';') == nil
            proc_string << line
          else
            proc_string << first_line_until_semicolon(line)
          end
        end
      else
        # ; found. Create the PLProcedure Object.
        if line.index(';') == nil
          proc_string << line
        else
          parsing_object = false
          proc_string << line[0,line.index(';')]
          procedures.push(PLProcedure.process_procedure(proc_string.delete(';')))
          proc_string = ''
          # TODO: check to see if there's another procedure after ; on the same line.
        end
      end
    end

    PackageSpec.new(package_name, procedures)
    #puts "package name = " + package_name
    # File full read... Create PackageSpec object and return it

  end

  def self.first_line_until_semicolon(str)
    proc_string  = ''

    if str.index(';') == nil
      proc_string << str
    else
      # if procedure or function is found in the same line as ';', start the string slice there, otherwise start at index 0.
      if str.index('procedure ') != nil
        start_index = str.index('procedure ')
      else # line.index('function ') != nil
        start_index = str.index('function ')
      end
      proc_string = str[start_index,str.index(';')]
    end
           puts 'finished first line = ' + proc_string
    proc_string
  end

end

pkg_spec = PackageSpec.parse_package_spec(File.new("example/test2.pks"))
pkg_spec.procedures.each { |p|
  p.write_anon_block_to_file(pkg_spec.name + "." + p.name + ".sql",pkg_spec.name)
}

if ARGV.size == 0
  puts "Please input valid package bodies you wish to process as arguments."
end

ARGV.each do |value|
  pkg_spec = PackageSpec.parse_package_spec(File.new(value))
  pkg_spec.procedures.each { |p|
    filename = pkg_spec.name + "." + p.name + ".sql"

    if File.exists?(filename)
      puts "File '" + filename + "' already exists. Overwrite? (y/N)"
      overwrite = STDIN.gets
      overwrite.chomp!

      if overwrite == 'y'
        p.write_anon_block_to_file(filename, pkg_spec.name)
        puts p.name + " generated."
      else
        puts p.name + " skipped."
      end

    else
      p.write_anon_block_to_file(filename, pkg_spec.name)
      puts p.name + " generated."
    end
  }
end