begin
  gem 'ruby-xbee'
rescue LoadError => e
  # puts "LoadError?! => #{e}"
  if require 'rubygems'
    # puts "Okay, required rubygems. retrying now ..."
    retry
  else
    $: << File.dirname(File.dirname(__FILE__)) + "/lib"
    # puts "$: = #{$:.join(", ")}"
    require 'ruby_xbee'
  end
end

if ARGV[0] && ARGV[0].to_s.downcase == "cable"
  @xbee_usbdev_str = "/dev/tty.usbserial-FTE4UXEA"
end

@xbee_usbdev_str ||= "/dev/tty.usbserial-A7004nmf"

# default baud - this can be overridden on the command line
@xbee_baud = 9600

# serial framing
@data_bits = 8
@stop_bits = 1
@parity = 0

