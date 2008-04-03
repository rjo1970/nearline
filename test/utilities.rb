require 'fileutils'

$temp_path = File.join(File.dirname(__FILE__), "..", "temp")
$readme = $temp_path +"/README"

unless File.exist?($temp_path)
  FileUtils.mkdir $temp_path
  FileUtils.cp(File.join(File.dirname(__FILE__), "..", "README"), $temp_path)  
end
