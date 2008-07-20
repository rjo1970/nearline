$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'nearline'

require 'test/unit'
require 'active_record'

class FileContentTest < Test::Unit::TestCase
    
  def test_content_fails_verification
    file_content = Nearline::Models::FileContent.new
    file_content.fingerprint = "wrong!"
    assert !file_content.verified?
  end
  
end  