$: << File.dirname(__FILE__)

require 'date'
require 'ruby-xbee'
require 'xbee_api'
require 'pp'

@xbee = XBee::RFModule.new( @xbee_usbdev_str, @xbee_baud, @data_bits, @stop_bits, @parity )

puts "Testing API now ..."
response = @xbee.neighbors
puts "status = #{response.status}, parameter_value = #{response.retrieved_value.gsub("\r","\n")}"
