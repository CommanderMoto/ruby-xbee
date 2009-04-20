begin
  gem 'ruby-xbee'
rescue LoadError => e
  puts "LoadError?! => #{e}"
  if require 'rubygems'
    puts "Okay, required rubygems. retrying now ..."
    retry
  else
    $: << File.dirname(File.dirname(__FILE__)) + "/lib"
    require 'ruby_xbee'
  end
end
