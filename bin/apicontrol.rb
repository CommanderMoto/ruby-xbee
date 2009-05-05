$: << File.dirname(__FILE__)

require 'date'
require 'ruby-xbee'
require 'pp'

@xbee = XBee::BaseAPIModeInterface.new(@xbee_usbdev_str)

puts "Testing API now ..."
puts "XBee Version: #{@xbee.version_long}"
puts "Firmware Rev: 0x%04x" % @xbee.fw_rev
puts "Hardware Rev: 0x%04x" % @xbee.hw_rev
puts "Serial Number High: 0x%08x" % @xbee.serial_num_high
puts "Serial Number Low: 0x%08x" % @xbee.serial_num_low
puts "Serial Number: 0x%016x" % @xbee.serial_num
tmp = @xbee.xbee_serialport.read_timeout
@xbee.xbee_serialport.read_timeout = 5000
puts "Remote d0 = digital output low ... #{@xbee.set_remote_param("D0",0x04, 0x0013a200404b229d, 0xfffe, "C") { |r| r.inspect} }"
puts "Remote d0 = digital output high ... #{@xbee.set_remote_param("D0",0x05, 0x0013a200404b229d, 0xfffe, "C") { |r| r.inspect} }"
sleep 5
@xbee.xbee_serialport.read_timeout = tmp
puts "Detecting neighbors ..."
response = @xbee.neighbors
response.each do |r|
  puts "----------------------"
  r.each do |key, val|
    puts case key
      when :NI : "#{key} = '#{val}'"
      when :STATUS, :DEVICE_TYPE : "#{key} = 0x%02x" % val
      when :SH, :SL : "#{key} = 0x%08x" % val
      else "#{key} = 0x%04x" % val
    end
  end
end
