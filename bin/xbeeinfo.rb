#!/usr/bin/env ruby -rubygems
# == Synopsis
# xbeeinfo.rb - A Ruby utility for extracting XBee setup information using xbee ruby class (Ruby::XBee)
#
# :title: A Ruby utility for extracting XBee setup information using xbee ruby class (Ruby::XBee)
# == Usage
#  ./xbeeinfo.rb
#
# example output from xbeeinfo:
#    Attention: OK
#    Firmware: 10CD
#    Hardware: 180B
#    Baud: 9600
#    Parity: None
#    Neighbors:
#    [{:SL=>"4008A642", :DB=>"-56", :NI=>" ", :MY=>"0", :SH=>"13A200"},
#    {:SL=>"4008A697", :DB=>"-75", :NI=>" ", :MY=>"0", :SH=>"13A200"},
#    {:SL=>"40085AD5", :DB=>"-64", :NI=>" ", :MY=>"0", :SH=>"13A200"}]
#    Node ID: BaseStation
#    Channel: C
#    PAN ID: 1
#    MY: 1
#    SH: 13A200
#    SL: 4008A64E
#    DH: 0
#    DL: 2
#    Last received signal strength (dBm): -36
#    Port 0: Disabled
#    Port 1: DI
#    Port 2: Disabled
#    Port 3: Disabled
#    Port 4: Disabled
#    Port 5: Associated_Indicator
#    Port 6: Disabled
#    Port 7: CTS
#    Port 8: Disabled
#
# See conf/xbeeconfig.rb for configuration defaults
#
# this code is designed for the following XBee modules:
# IEEE® 802.15.4 OEM RF Modules by Digi International
# Series 1 XBee and XBee Pro modules
#
# == Copyright
# Copyright (C) 2008-2009 360VL, Inc. and Landon Cox
#
# == License
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License version 3 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License version 3 for more details.
#
# You should have received a copy of the GNU Affero General Public License along with this program.
# If not, see http://www.gnu.org/licenses/
#
# == See Also
# xbeeinfo.rb, xbeeconfigure.rb, xbeedio.rb, xbeelisten.rb, xbeesend.rb
#
# == Learn more
# You can learn more about Ruby::XBee and other projects at http://sawdust.see-do.org
#
# see Digi product manual: "Product Manual v1.xCx - 802.15.4 Protocol"
# for details on the operation of XBee series 1 modules.


$: << File.dirname(__FILE__)

require 'date'
require 'ruby-xbee'

STDIN.sync = 1
STDOUT.sync = 1
$stdin.sync = true
$stdout.sync = true

require 'pp'

@xbee = XBee.new( @xbee_usbdev_str, @xbee_baud, @data_bits, @stop_bits, @parity )

puts "Attention: #{@xbee.attention}"
puts "Firmware: #{@xbee.fw_rev}"
puts "Hardware: #{@xbee.hw_rev}"

puts "Baud: #{@xbee.baud}"
puts "Parity: #{@xbee.parity}"

puts "Neighbors:"
pp @xbee.neighbors

puts "Node ID: #{@xbee.node_id}"
puts "Channel: #{@xbee.channel}"
puts "PAN ID: #{@xbee.pan_id}"
puts "MY: #{@xbee.my_src_address}"
puts "SH: #{@xbee.serial_num_high}"
puts "SL: #{@xbee.serial_num_low}"
puts "DH: #{@xbee.destination_high}"
puts "DL: #{@xbee.destination_low}"
puts "Last received signal strength (dBm): #{@xbee.received_signal_strength}"

0.upto(8) do | num |
  portsym = "D#{num}".to_sym
  puts "Port #{num}: #{@xbee.dio( portsym )}"
end


