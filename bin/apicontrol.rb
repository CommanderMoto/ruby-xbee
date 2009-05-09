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
puts "Resetting remote module to factory defaults ... #{@xbee.set_remote_param("RE",nil, 0x0013a200404b22a1, 0xfffe, "a*") { |r| r.inspect} }"

puts "Detecting neighbors ..."
other_xbee_serials = []
response = @xbee.neighbors
response.each do |r|
  puts "----------------------"
  neighbor_serial = @xbee.concatenate_address(r[:SH], r[:SL])
  other_xbee_serials << neighbor_serial unless neighbor_serial == @xbee.serial_num
  r.each do |key, val|
    puts case key
      when :NI : "#{key} = '#{val}'"
      when :STATUS, :DEVICE_TYPE : "#{key} = 0x%02x" % val
      when :SH, :SL : "#{key} = 0x%08x" % val
      else "#{key} = 0x%04x" % val
    end
  end
end

if other_xbee_serials.empty?
  puts "Huh. Looks like we didn't find any neighbors. Boo."
else
  neighbor = other_xbee_serials.first
  puts "Found %s, serial is 0x%016x" % [(other_xbee_serials.size > 1 ? "#{other_xbee_serials.size} neighbors" : "a neighbor"), neighbor]
  sleep 3
  puts "Resetting remote module to factory defaults ... #{@xbee.set_remote_param("RE",nil, neighbor, 0xfffe, "a*") { |r| r.inspect} }"
  puts "Remote d0 = digital output low ... #{@xbee.set_remote_param("D0",0x04, neighbor, 0xfffe, "C") { |r| r.inspect} }"
  sleep 0.5
  puts "Remote d0 = digital output high ... #{@xbee.set_remote_param("D0",0x05, neighbor, 0xfffe, "C") { |r| r.inspect} }"
  sleep 0.1
  puts "Remote d1 = digital output low ... #{@xbee.set_remote_param("D1",0x04, neighbor, 0xfffe, "C") { |r| r.inspect} }"
  sleep 0.5
  puts "Remote d1 = digital output high ... #{@xbee.set_remote_param("D1",0x05, neighbor, 0xfffe, "C") { |r| r.inspect} }"
  sleep 0.1
  puts "Remote d2 = digital output low ... #{@xbee.set_remote_param("D2",0x04, neighbor, 0xfffe, "C") { |r| r.inspect} }"
  sleep 0.5
  puts "Remote d2 = digital output high ... #{@xbee.set_remote_param("D2",0x05, neighbor, 0xfffe, "C") { |r| r.inspect} }"
  sleep 0.1
  puts "Remote d3 = digital output low ... #{@xbee.set_remote_param("D3",0x04, neighbor, 0xfffe, "C") { |r| r.inspect} }"
  sleep 0.5
  puts "Remote d3 = digital output high ... #{@xbee.set_remote_param("D3",0x05, neighbor, 0xfffe, "C") { |r| r.inspect} }"
  sleep 0.5
end
