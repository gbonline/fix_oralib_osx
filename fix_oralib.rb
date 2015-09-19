#!/usr/bin/env ruby

require 'optparse'

options = {}
parser = OptionParser.new do |opts|
  opts.banner = "Usage: fix_oralib.rb [options] files..."

  opts.on("-d", "--ic_dir=DIRECTORY",
          "Sepcify Oracle instant client directory",
          "(default: current directory or script directory)") do |dir|
    options[:ic_dir] = File.expand_path('.', dir)
  end
  opts.on("-n", "--[no-]dry-run",
          "Perform a trial run with no changes made") do |v|
    options[:dry_run] = v
  end
  opts.on("-f", "--[no-]force",
          "Force addition of rpath") do |v|
    options[:force] = v
  end
end
parser.parse!

class ObjectFileInfo
  attr_reader :library_id
  attr_reader :is_oracle_library
  attr_reader :dependent_libraries
  attr_reader :dependent_oracle_libraries
  attr_reader :should_be_fixed

  class Error < RuntimeError
  end

  @@oralibs = ["libclntsh.dylib.11.1",
               "libnnz11.dylib",
               "libocci.dylib.11.1",
               "libociei.dylib",
               "libociicus.dylib",
               "libocijdbc11.dylib",
               "libsqlplus.dylib",
               "libsqlplusic.dylib",
              ]
  @@ic_dir = nil

  def initialize(filename, opts)
    @filename = filename
    @rpath_list = []
    @library_id = nil
    @dependent_libraries = []
    force = opts[:force]
    @dry_run = opts[:dry_run]

    open(%Q{|otool -l "#{filename}"}) do |f|
      line = f.gets
      if line != "#{filename}:\n"
        break
      end
      state = :wait_cmd
      while line = f.gets
        case line.strip
        when 'cmd LC_RPATH'
          f.gets
          f.gets =~ /path (.*) \(/
          @rpath_list << $1
        when 'cmd LC_ID_DYLIB'
          f.gets
          f.gets =~ /name (.*) \(/
          @library_id = $1
        when 'cmd LC_LOAD_DYLIB'
          f.gets
          f.gets =~ /name (.*) \(/
          @dependent_libraries << $1
        end
      end
    end
    @is_oracle_library = @library_id && @@oralibs.include?(File.basename(@library_id))
    @dependent_oracle_libraries = @dependent_libraries.select do |fname|
      @@oralibs.include?(File.basename(fname))
    end
    if File.identical?(@@ic_dir, File.dirname(@filename))
      @oracle_rpath = '@loader_path'
    else
      @oracle_rpath = @@ic_dir
    end

    @should_be_fixed = false
    @rpath_should_be_fixed = false
    if not @dependent_libraries.empty?
      if force or not @dependent_oracle_libraries.empty?
        if not @rpath_list.include? @oracle_rpath
          @rpath_should_be_fixed = true
          @should_be_fixed = true
        end
      end
      if @is_oracle_library
        if @library_id != "@rpath/#{File.basename(@library_id)}"
          @should_be_fixed = true
        end
      end
      @dependent_oracle_libraries.each do |lib|
        if lib != "@rpath/#{File.basename(lib)}"
          @should_be_fixed = true
        end
      end
    end
  end

  def fix_path
    @file_mode_fixed = nil
    @filename_outputted = false
    begin
      if @rpath_should_be_fixed
        run_install_name_tool(:add_rpath, @oracle_rpath, @filename)
      end
      if @is_oracle_library
        basename = File.basename(@library_id)
        if @library_id != "@rpath/#{basename}"
          run_install_name_tool(:id, "@rpath/#{basename}", @filename)
        end
      end
      @dependent_oracle_libraries.each do |lib|
        basename = File.basename(lib)
        if lib != "@rpath/#{basename}"
          run_install_name_tool(:change, lib, "@rpath/#{basename}", @filename)
        end
      end
      puts "" if @filename_outputted
    ensure
      restore_file_mode
    end
  end

  def self.set_rpath(ic_dir)
    if ic_dir
      if not File.exists?(File.join(ic_dir, @@oralibs[0]))
        raise Error, "#{ic_dir} is not an instant client directory."
      end
    else
      if File.exists?(@@oralibs[0])
        ic_dir = File.expand_path('.')
      elsif File.exists?(File.expand_path("../#{@@oralibs[0]}", __FILE__))
        ic_dir = File.expand_path('..', __FILE__)
      else
        raise Error, <<EOS
Instant client is not found. Use --ic_dir option to set the Instant client path.

Example:
  ruby fix_oralib.rb --ic_dir=/opt/instantclient_11_2 ...
EOS
      end
    end
    @@ic_dir = ic_dir
  end

private

  def run_install_name_tool(command, *args)
    ensure_writable unless @dry_run
    if not @filename_outputted
      puts "#{@filename}:"
      @filename_outputted = true
    end
    case command
    when :add_rpath
      puts "   add rpath: #{args[0]}"
    when :id
      puts "   change library id"
      puts "     from: #{library_id}"
      puts "       to: #{args[0]}"
    when :change
      puts "   change dependent library"
      puts "     from: #{args[0]}"
      puts "       to: #{args[1]}"
    end
    unless @dry_run
      cmdline = %Q{install_name_tool -#{command} "#{args.join('" "')}"}
      system(cmdline)
      if $? != 0
        raise "Failed to run install_name_tool"
      end
    end
  end

  def ensure_writable
    if @file_mode_fixed.nil?
      @file_mode_original = File.stat(@filename).mode
      if (@file_mode_original & 0200) == 0
        File.chmod(@file_mode_original | 0200, @filename)
        @file_mode_fixed = true
      else
        @file_mode_fixed = false
      end
    end
  end

  def restore_file_mode
    if @file_mode_fixed
      File.chmod(@file_mode_original, @filename)
    end
  end
end

files = ARGV
if files.size == 0
  files = Dir['*']
end

begin
  ObjectFileInfo.set_rpath(options[:ic_dir])

  files.each do |file|
    info = ObjectFileInfo.new(file, options)
    if info.should_be_fixed
      info.fix_path
    end
  end
rescue ObjectFileInfo::Error
  puts $!
  exit 1
end
