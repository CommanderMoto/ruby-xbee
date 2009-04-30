# == Synopsis
# xbee.rb - A Ruby class for manipulating an XBee via the serial communication port of the host
#
# this code is designed for the following XBee modules:
#   IEEE® 802.15.4 OEM RF Modules by Digi International
#   Series 1 XBee and XBee Pro modules
#
# :title: xbee.rb - A Ruby class for manipulating an XBee via the serial communication port of the host
#
# == Copyright
#
# Copyright (C) 2008-2009 360VL, Inc. and Landon Cox
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
# You can learn more about Ruby::XBee and other projects at http://sawdust.see-do.org
#
# see Digi product manual: "Product Manual v1.xCx - 802.15.4 Protocol"
# for details on the operation of XBee series 1 modules.

require 'date'
require 'pp'

begin
  gem 'ruby-serialport'
  require 'serialport'
  STDIN.sync = 1
  STDOUT.sync = 1
  $stdin.sync = true
  $stdout.sync = true
rescue LoadError => e
  puts "LoadError?! => #{e}"
  if require 'rubygems'
    puts "Okay, required rubygems. retrying now ..."
    retry
  end
end

module XBee
  ##
  # Accessor for the factory below (to preserve legacy API)
  def XBee.new( xbee_usbdev_str, baud, data_bits, stop_bits, parity )
    uart_config = XBeeUARTConfig.new(baud, data_bits, parity, stop_bits)
    RFModule.factory(xbee_usbdev_str, uart_config)
  end

  ##
  # a method for getting results from any Ruby SerialPort object. Not ideal, but seems effective enough.

  def getresults( sp, echo = true )
    results = ""
    while (c = sp.getc) do
      if ( !echo.nil? && echo )
        putc c
      end
      results += "#{c.chr}"
    end

    # deal with multiple lines
    results.gsub!( "\r", "\n")
  end

  ##
  # A class for encapsulating UART communication parameters

  class XBeeUARTConfig
    attr_accessor :baud, :data_bits, :parity, :stop_bits

    def parities
      { :None => 0, :Even => 1, :Odd => 2, :Mark => 3, :Space => 4 }
    end

    def parity_code(parity_symbol)
      if parity_symbol.kind_of?(Symbol)
        self.parities[parity_symbol]
      else
        raise "parity_symbol must be one of #{parities.keys.join(", ")}"
      end
    end

    def parity_symbol(parity_code)
      if parity_code.kind_of?(Integer) && self.parities.values.include?(parity_code)
        # TODO: This works for now but is bound to result in subtle failure later, I just know it.
        self.parities.keys[parity_code]
      else
        raise "parity_code must be an integer in the set [#{self.parities.values.join(", ")}]"
      end
    end

    def initialize(baud = 9600, data_bits = 8, parity = :None, stop_bits = 1)
      self.baud = Integer(baud)
      self.data_bits = Integer(data_bits)
      self.parity = self.parities[parity]
      self.stop_bits = Integer(stop_bits)
    end
  end

  ##
  # This is it, the base class where it all starts. Command mode or API mode, version 1 or version 2, all XBees descend
  # from this class.
  class RFModule
    include XBee
    attr_accessor :xbee_serialport, :xbee_uart_config

    # XBee response times vary based on both hardware and firmware versions.  These
    # constants may need to be adjusted for your devices, but these will
    # work fine for most cases.  The unit of time for a timeout constant is ms

    TYPICAL_READ_TIMEOUT = 1200
    LONG_READ_TIMEOUT    = 3000

    VERSION = "1.0"                 # version of this class

    ##
    # This is the way we instantiate XBee modules now, via this factory method. It will ultimately autodetect what
    # flavor of XBee module we're using and return the most appropriate subclass to control that module.

    def RFModule.factory(xbee_usbdev_str = "/dev/tty.usbserial-A7004nmf", uart_config = XBeeUARTConfig.new)
      xbee_uart_config = uart_config.kind_of?(XBeeUARTConfig) ? uart_config : XBeeUARTConfig.new
      require 'legacy/command_mode'
      BaseCommandModeInterface.new(xbee_usbdev_str,
              xbee_uart_config.baud,
              xbee_uart_config.data_bits,
              xbee_uart_config.stop_bits,
              xbee_uart_config.parity)
    end
  end
end  # module XBee

=begin rdoc
  reads lines from a given serial port object until there are no more lines left to read (timesout with @xbee.serial_timeout value)
=end

