# == Synopsis
# xbeeconfig.rb - the configuration file for Ruby::XBee utilities and classes.  defines various
# defaults that make it more convenient to use
#
# See also:  xbeeconfigure.rb, xbeeinfo.rb, xbeelisten.rb, xbee.rb
#
# == Copyright
# Copyright (C) 2008-2009 360VL, Inc. and Landon Cox 
#
# This is free software: you can redistribute it and/or modify
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
# You can learn more about Ruby::XBee and other projects at http://sawdust.see-do.org
#   

require "ruby-serialport-0.6/serialport.so"

STDIN.sync = 1
STDOUT.sync = 1
$stdin.sync = true
$stdout.sync = true

# this is the monitor port device
# your device will be different than this

#@xbee_usbdev_str = "/dev/tty.KeySerial1" 

@xbee_usbdev_str = "/dev/tty.usbserial-A80081sF" 

# default baud - this can be overridden on the command line
@xbee_baud = 9600

# serial framing
@data_bits = 8
@stop_bits = 1
@parity = SerialPort::NONE

