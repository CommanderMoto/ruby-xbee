#!/usr/bin/env ruby  
# == Synposis
# xbeesend.rb - A Ruby utility for sending raw data to and through an XBee 
# 
# :title: xbeesend.rb - A Ruby utility for sending raw data to and through an XBee 
#
# == Copyright
# Copyright (C) 2008-2009 360VL, Inc. and Landon Cox
#
# == License
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
# You can learn more about ruby for XBee and other projects at http://sawdust.see-do.org
#
# == Usage
#    xbeesend.rb [message]
#  
# example:
#      ./xbeesend.rb 'this is some data to send' 'some more data' 'last bits'
#
# each of the 3 parameters above is sent in succession.  You can put as many messages on the command
# line as will be accomodated by the shell.
#   
# example
#      ./xbeesend.rb
#       
# this form of the command will wait for you to input data from the keyboard...it reads stdin input
# and every line you type will be sent to/through the XBee when you hit enter 
#
# this utility can be used also for just setting up an XBee with raw AT commands. 
# it doesn't interpret anything in or out of the XBee.  You can put the XBee into attention by:
#      ./xbeesend.rb '+++'
# if you monitor it with the xbeelisten.rb utility, you'd see an 'OK' in response 
#
# See conf/xbeeconfig.rb for configuration defaults
#
# this code is for the following XBee modules:
# IEEE® 802.15.4 OEM RF Modules by Digi International
#
# == See Also
# xbeeinfo.rb, xbeeconfigure.rb, xbeedio.rb, xbeelisten.rb, xbeesend.rb
#
# == Learn more
# You can learn more about Ruby::XBee and other projects at http://sawdust.see-do.org
#
# see Digi product manual: "Product Manual v1.xCx - 802.15.4 Protocol"
# for details on the operation of XBee series 1 modules. 
# 

$: << File.dirname(__FILE__)

require 'date'
require 'getoptlong'

require 'ruby-xbee'

# start a connection to the XBee
@xbee = XBee::V1.new( @xbee_usbdev_str, @xbee_baud, @data_bits, @stop_bits, @parity )

if ( ARGV.size > 0 )
  ARGV.each do | message |
    puts "Sending: #{message}"
    @xbee.send! message 
  end
else  # take input from STDIN to make it interactive
  while true
    message = gets
    @xbee.send! message 
  end 
end

