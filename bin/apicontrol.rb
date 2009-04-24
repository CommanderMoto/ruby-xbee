$: << File.dirname(__FILE__)

require 'date'
require 'ruby-xbee'
require 'xbee_api'
require 'pp'

@xbee = XBee::RFModule.new( @xbee_usbdev_str, @xbee_baud, @data_bits, @stop_bits, @parity )

puts "Testing API now ..."
puts "XBee Version: #{@xbee.version_long}"
sleep 1
response = @xbee.neighbors
response.each do |r|
  r.each do |key, val|
    if (key == :NI)
      puts "#{key} = #{val}"
    else
      puts "#{key} = 0x%x" % val
    end
  end
end
