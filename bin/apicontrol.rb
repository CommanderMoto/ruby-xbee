$: << File.dirname(__FILE__)

require 'date'
require 'ruby-xbee'
require 'xbee_api'
require 'pp'

@xbee = XBee::V2.new( @xbee_usbdev_str, @xbee_baud, @data_bits, @stop_bits, @parity )

puts "Testing API now ..."
@xbee.test_api
