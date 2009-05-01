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
    if (key == :NI)

    else

    end
  end
end
