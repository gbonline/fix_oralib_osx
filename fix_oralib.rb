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
  opts.on("-a", "--[no-]absolute-path",
          "Use the absolute path of instant client directory instead of @rpath") do |v|
    options[:abs] = v
  end
  opts.on("-n", "--[no-]dry-run",
          "Perform a trial run with no changes made") do |v|
    options[:dry_run] = v
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

  @@oralibs = [/^libclntsh.dylib.\d+.\d$/, # in basic and basiclite packages
               /^libnnz\d+.dylib$/,        # in basic and basiclite packages
               /^libocci.dylib.\d+.\d$/,   # in basic and basiclite packages
               "libociei.dylib",           # in basic package
               "libociicus.dylib",         # in basiclite package
               /^libocijdbc\d+.dylib$/,    # in basic and basiclite packages
               "libsqlplus.dylib",         # in sqlplus package
               "libsqlplusic.dylib",       # in sqlplus package
               /^libheteroxa\d+.dylib$/    # in jdbc package
              ]
  @@ic_dir = nil

  def initialize(filename, opts)
    @filename = filename
    @rpath_list = []
    @library_id = nil
    @dependent_libraries = []
    @abs = opts[:abs]
    @dry_run = opts[:dry_run]

    open(%Q{|otool -l "#{filename}"}) do |f|
      line = f.gets
      if line != "#{filename}:\n"
        break
      end
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
    @is_oracle_library = @library_id && is_oralib?(@library_id)
    @dependent_oracle_libraries = @dependent_libraries.select do |fname|
      is_oralib?(fname)
    end
    if File.identical?(@@ic_dir, File.dirname(@filename))
      @oracle_rpath = '@loader_path'
    else
      @oracle_rpath = @@ic_dir
    end
    @libdir = @abs ? @@ic_dir : '@rpath'

    @should_be_fixed = false
    @rpath_should_be_fixed = false
    if not @dependent_libraries.empty?
      if @abs ? (@library_id and is_oralib?(@library_id, true))
        : (not @dependent_oracle_libraries.empty?)
        if not @rpath_list.include? @oracle_rpath
          @rpath_should_be_fixed = true
          @should_be_fixed = true
        end
      end
      if @is_oracle_library
        if @library_id != "#{@libdir}/#{File.basename(@library_id)}"
          @should_be_fixed = true
        end
      end
      @dependent_oracle_libraries.each do |lib|
        if lib != "#{@libdir}/#{File.basename(lib)}"
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
        if @library_id != "#{@libdir}/#{basename}"
          run_install_name_tool(:id, "#{@libdir}/#{basename}", @filename)
        end
      end
      @dependent_oracle_libraries.each do |lib|
        basename = File.basename(lib)
        if lib != "#{@libdir}/#{basename}"
          run_install_name_tool(:change, lib, "#{@libdir}/#{basename}", @filename)
        end
      end
      puts "" if @filename_outputted
    ensure
      restore_file_mode
    end
  end

  def self.set_rpath(ic_dir)
    if ic_dir
      if not is_oralib_dir?(ic_dir)
        raise Error, "#{ic_dir} is not an instant client directory."
      end
      ic_dir = File.expand_path(ic_dir)
    else
      if is_oralib_dir?('.')
        ic_dir = File.expand_path('.')
      elsif is_oralib_dir?(File.expand_path('..', __FILE__))
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
  def is_oralib?(filename, check_first_only = false)
    basename = File.basename(filename)
    if check_first_only
      @@oralibs[0] === basename
    else
      @@oralibs.any? do |lib|
        lib === basename
      end
    end
  end

  def self.is_oralib_dir?(dirname)
    Dir.entries(dirname).any? do |filename|
      @@oralibs[0] === filename
    end
  end

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
      puts "   change identification name"
      puts "     from: #{library_id}"
      puts "       to: #{args[0]}"
    when :change
      puts "   change install name"
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
  files = Dir['*'].select {|file| File.file?(file)}
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
