module Nearline  
  module_function

  # VERSION of the software
  VERSION = "0.0.5"
  
  # Array of every Nearline Model using an ActiveRecord connection
  AR_MODELS = Nearline::Models.constants.map do |m|
    Nearline::Models.const_get(m)
  end.select do |c|
    c.superclass == ActiveRecord::Base
  end
  
  # Establishes the ActiveRecord connection
  # 
  # Accepts a Hash to establish the connection or
  # a String referring to an entry in config/database.yml.
  # 
  # Will establish the Nearline database tables if they are absent.
  # 
  # Stomps on any ActiveRecord::Base.establish_connection you might
  # have already established.
  # 
  # === Examples
  # Nearline.connect!({:adapter => 'sqlite3', :database => 'data/sqlite.db'})
  # 
  # Nearline.connect! 'production'
  # 
  def connect!(config="development")
    if (config.is_a? String)
      ActiveRecord::Base.establish_connection(
        YAML.load_file("config/database.yml")[config]
      )
    elsif (config.is_a? Hash)
      ActiveRecord::Base.establish_connection(config)      
    end
    
    unless Nearline::Models::Block.table_exists?
      Nearline::Models.generate_schema
    end
    nil
  end
  
  # Establishes a connection only to the Nearline ActiveDirectory models
  # 
  # Will not change the ActiveRecord::Base connection
  # 
  # Will not establish Nearline tables in the database
  # 
  # Accepts a Hash to establish the connection or
  # a String referring to an entry in config/database.yml.
  # === Examples
  # Nearline.connect({:adapter => 'sqlite3', :database => 'data/sqlite.db'})
  # 
  # Nearline.connect 'production'
  # 
  def connect(config="development")
    # These are the ActiveRecord models in place
    # Each one needs an explicit establish_connection
    # if you don't want it running though ActiveRecord::Base  
    if (config.is_a? String)
      hash = YAML.load_file("config/database.yml")[config]
    else
      hash = config
    end
    
    AR_MODELS.each do |m|
      m.establish_connection(hash)
    end
    nil
  end
  
  # Performs a backup labeled for system_name,
  # Recursing through a single string or an array of backup_paths,
  # Excluding any path matching any of the regular
  # expressions in the backup_exclusions array or single string.
  # 
  # Expects the Nearline database connection has already
  # been established
  # 
  # Returns a Manifest for the backup
  #
  # === Examples
  # Backup my laptop, recursing my home folder, skipping .svn folders
  # 
  # Nearline.backup('my_laptop','/home/me', '/\\.svn/')
  #
  # Backup my laptop, recurse /home/me and /var/svn
  # 
  # Nearline.backup('my_laptop', ['/home/me', '/var/svn']
  #
  def backup(system_name, backup_paths,backup_exclusions= [])
    raise_failing_version_check
    Nearline::Models::System.backup(
      system_name,
      Utilities.string_to_array(backup_paths),
      Utilities.string_to_array(backup_exclusions)
    )
  end
  
  module Utilities
    module_function
    def self.string_to_array(x)
      if x.is_a? String
        return [x]
      end
      x      
    end
  end
  
  # Restore all missing files from the latest backup
  # for system_name and backed up no later than latest_date_time
  # 
  # All modified or existing files are left alone
  # 
  # Expects the Nearline database connection has already
  # been established
  # 
  # Returns an Array of paths restored
  def restore(system_name, latest_date_time = Time.now)
    raise_failing_version_check
    Nearline::Models::System.restore_all_missing(system_name, latest_date_time)
  end
  
  # Returns an array of paths that would be restored given the provided
  # parameters
  def what_would_restore(system_name, latest_date_time = Time.now)
    raise_failing_version_check
    Nearline::Models::System.what_would_restore(system_name, latest_date_time)
  end
  
  
  
  # Returns the nearline version of the database
  def schema_version
    begin
      return Nearline::Models::Block.connection.select_value(
        "select version from nearline_version"
      )
    rescue
      return ""
    end    
  end
  
  def raise_failing_version_check
    unless version_check?
      raise SchemaVersionException.for_version(schema_version)
    end        
  end
  
  # Returns true only if the Nearline version matches the schema
  def version_check?
    Nearline::VERSION == schema_version()
  end
  
  class SchemaVersionException < Exception
    def self.for_version(v)
      SchemaVersionException.new("Schema #{v} is not the same "+
          "version as nearline #{Nearline::VERSION}!")
    end
  end
  
end
