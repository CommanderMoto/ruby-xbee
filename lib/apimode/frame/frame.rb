$: << File.dirname(__FILE__)

class String
  def xb_escape
    self.gsub(/[\176\175\021\023]/) { |c| [0x7D, c[0] ^ 0x20].pack("CC")}
  end
  def xb_unescape
    self.gsub(/\175./) { |ec| [ec.unpack("CC").last ^ 0x20].pack("C")}
  end
end

module XBee
  module Frame
    def Frame.checksum(data)
      0xFF - (data.unpack("C*").inject(0) { |sum, byte| (sum + byte) & 0xFF })
    end

    def Frame.new(source_io)
      stray_bytes = []
      until (start_delimiter = source_io.readchar) == 0x7e
        puts "Stray byte 0x%x" % start_delimiter
        stray_bytes << start_delimiter
      end
      puts "Got some stray bytes for ya: #{stray_bytes.map {|b| "0x%x" % b} .join(", ")}" unless stray_bytes.empty?
      header = source_io.read(3).xb_unescape
      # puts "Read header: #{header.unpack("C*").join(", ")}"
      frame_remaining = frame_length = api_identifier = cmd_data = ""
      if header.length == 3
        frame_length, api_identifier = header.unpack("nC")
      else
        frame_length, api_identifier = header.unpack("n").first, source_io.readchar
      end
      cmd_data_intended_length = frame_length - 1
      while ((unescaped_length = cmd_data.xb_unescape.length) < cmd_data_intended_length)
        cmd_data += source_io.read(cmd_data_intended_length - unescaped_length)
      end
      data = api_identifier.chr + cmd_data.xb_unescape
      sent_checksum = source_io.getc
      unless sent_checksum == Frame.checksum(data)
        raise "Bad checksum - data discarded"
      end
      case data[0]
      when 0x8A : ModemStatus.new(data)
      when 0x88 : ATCommandResponse.new(data)
      when 0x97 : RemoteCommandResponse.new(data)
      when 0x8B : TransmitStatus.new(data)
      when 0x90 : ReceivePacket.new(data)
      when 0x91 : ExplicitRxIndicator.new(data)
      else ReceivedFrame.new(data)
      end
    end

    class Base
      attr_accessor :api_identifier, :cmd_data

      def api_identifier ; @api_identifier ||= 0x00 ; end

      def cmd_data ; @cmd_data ||= "" ; end

      def length ; data.length ; end

      def data
        Array(api_identifier).pack("C") + cmd_data
      end

      def _dump
        raise "Too much data (#{self.length} bytes) to fit into one frame!" if (self.length > 0xFFFF)
        "~" + [length].pack("n").xb_escape + data.xb_escape + [Frame.checksum(data)].pack("C")
      end
    end

    class ReceivedFrame < Base
      def initialize(frame_data)
        raise "Frame data must be an enumerable type" unless frame_data.kind_of?(Enumerable)
        self.api_identifier = frame_data[0]
        # puts "Initializing a ReceivedFrame of type 0x%x" % self.api_identifier
        self.cmd_data = frame_data[1..-1]
      end
    end
  end
end

require 'at_command'
require 'at_command_response'
require 'explicit_addressing_command'
require 'explicit_rx_indicator'
require 'modem_status'
require 'receive_packet'
require 'remote_command_request'
require 'remote_command_response'
require 'transmit_request'
require 'transmit_status'

