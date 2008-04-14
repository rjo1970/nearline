module Nearline  
  module_function

  # VERSION of the software
  VERSION = "0.0.4"
  
  # Every model using an ActiveRecord connection
  AR_MODELS = [
    Nearline::Models::ArchivedFile,
    Nearline::Models::Block,
    Nearline::Models::FileContent,
    Nearline::Models::Manifest,
    Nearline::Models::Sequence,
    Nearline::Models::Log
  ]
  
  
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
    end
    
    if (config.is_a? Hash)
      ActiveRecord::Base.establish_connection(config)      
    end
    
    unless Nearline::Models::Block.table_exists?
      Nearline::Models.generate_schema
    end
    Nearline::Models::Block.connected?
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
    Nearline::Models::Block.connected?
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
  def backup(system_name, backup_paths,backup_exclusions= [])
    Nearline::Models::Manifest.backup(
      system_name,
      string_to_array(backup_paths),
      string_to_array(backup_exclusions)
    )
  end
     
  def string_to_array(x)
    if x.is_a? String
      return [x]
    end
    x
  end

  # Restore all missing files from the latest backup
  # for system_name and no earlier than latest_date_time
  # 
  # All updated or existing files are left alone
  # 
  # Expects the Nearline database connection has already
  # been established
  # 
  # Returns an Array of paths restored
  def restore(system_name, latest_date_time = Time.now)
    Nearline::Models::Manifest.restore_all_missing(system_name, latest_date_time)
  end
  
end
