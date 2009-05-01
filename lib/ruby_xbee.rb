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

require 'rubygems'
gem 'ruby-serialport'
require 'serialport'

require 'module_config'
require 'apimode/xbee_api'

module XBee
  ##
  # supports legacy API, command-mode interface
  def XBee.new( xbee_usbdev_str, baud, data_bits, stop_bits, parity )
    require 'legacy/command_mode'
    BaseCommandModeInterface.new(xbee_usbdev_str, baud, data_bits, stop_bits, parity)
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
  # This is it, the base class where it all starts. Command mode or API mode, version 1 or version 2, all XBees descend
  # from this class.
  class RFModule
    include XBee
    include Config
    attr_accessor :xbee_serialport, :xbee_uart_config, :guard_time, :command_mode_timeout, :command_character, :node_discover_timeout, :node_identifier
    attr_reader :serial_number, :hardware_rev, :firmware_rev


    def version
      "2.0"
    end

    ##
    # This is the way we instantiate XBee modules now, via this factory method. It will ultimately autodetect what
    # flavor of XBee module we're using and return the most appropriate subclass to control that module.
    def initialize(xbee_usbdev_str = "/dev/tty.usbserial-A7004nmf", uart_config = XBeeUARTConfig.new)
      unless uart_config.kind_of?(XBeeUARTConfig)
        raise "uart_config must be an instance of XBeeUARTConfig for this to work"
      end
      self.xbee_uart_config = uart_config
      @xbee_serialport = SerialPort.new( xbee_usbdev_str, uart_config.baud, uart_config.data_bits, uart_config.stop_bits, uart_config.parity )
      @xbee_serialport.read_timeout = self.read_timeout(:short)
      @guard_time = GuardTime.new
      @command_mode_timeout= CommandModeTimeout.new
      @command_character = CommandCharacter.new
      @node_discover_timeout = NodeDiscoverTimeout.new
      @node_identifier = NodeIdentifier.new
    end

    def in_command_mode
      sleep self.guard_time.in_seconds
      @xbee_serialport.write(self.command_character.value * 3)
      sleep self.guard_time.in_seconds
      @xbee_serialport.read(3)
      # actually do some work now ...
      yield if block_given?
      # Exit command mode
      @xbee_serialport.write("ATCN\r")
      @xbee_serialport.read(3)
    end

    ##
    # XBee response times vary based on both hardware and firmware versions. These
    # constants may need to be adjusted for your devices, but these will
    # work fine for most cases.  The unit of time for a timeout constant is ms
    def read_timeout(type = :short)
      case type
        when :short : 1200
        when :long : 3000
        else 3000
      end
    end
  end
end  # module XBee
