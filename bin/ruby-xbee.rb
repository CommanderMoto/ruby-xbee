begin
  require 'rubygems'
  gem 'ruby-xbee'
rescue LoadError => e
  load_path_addition = File.dirname(File.dirname(__FILE__)) + "/lib"
  puts "Falling back to extended load path #{load_path_addition}"
  $: << load_path_addition
  require 'ruby_xbee'
end

@xbee_usbdev_str = case ARGV[0]
  when "cable" : "/dev/tty.usbserial-FTE4UXEA"
  else "/dev/tty.usbserial-A7004nmf"
end

# default baud - this can be overridden on the command line
@xbee_baud = 9600

# serial framing
@data_bits = 8
@stop_bits = 1
@parity = 0

