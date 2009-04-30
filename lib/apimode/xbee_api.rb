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

    def Frame.factory(source_io)
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
      ReceivedFrame.instantiate(data)
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

    class ReceivedFrame < BaseCommandModeInterface
      def ReceivedFrame.instantiate(data)
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

      def initialize(frame_data)
        raise "Frame data must be an enumerable type" unless frame_data.kind_of?(Enumerable)
        self.api_identifier = frame_data[0]
        # puts "Initializing a ReceivedFrame of type 0x%x" % self.api_identifier
        self.cmd_data = frame_data[1..-1]
      end
    end

    class ModemStatus < ReceivedFrame
      attr_accessor :status

      def initialize(data = nil)
        super(data) && (yield self if block_given?)
      end

      def modem_statuses
        [
          [1, :Hardware_Reset],
          [2, :Watchdog_Timer_Reset],
          [3, :Associated],
        ]
      end

      def cmd_data=(data_string)
        status_byte = data_string.unpack("c")
        # update status ivar for later use
        self.status = case status_byte
        when 1..3 : modem_statuses.assoc(status_byte)
        else raise "ModemStatus frame appears to include an invalid status value: #{data_string}"
        end
        #actually assign and move along
        @cmd_data = data_string
      end
    end

    class ATCommand < BaseCommandModeInterface
      def api_identifier ; 0x08 ; end

      attr_accessor :frame_id, :at_command, :parameter_value, :parameter_pack_string

      def initialize(at_command, frame_id = nil, parameter_value = nil, parameter_pack_string = "a*")
        self.frame_id = frame_id
        self.at_command = at_command # TODO: Check for valid AT command codes here
        self.parameter_value = parameter_value
        self.parameter_pack_string = parameter_pack_string
        yield self if block_given?
      end

      def cmd_data=(data_string)
        self.frame_id, self.at_command, self.parameter_value = data_string.unpack("ca2#{parameter_pack_string}")
      end

      def cmd_data
        [frame_id, at_command, parameter_value].pack("ca2#{parameter_pack_string}")
      end
    end

    class ATCommandQueueParameterValue < ATCommand
      def api_identifier ; 0x09 ; end
    end

    class ATCommandResponse < ReceivedFrame
      attr_accessor :frame_id, :at_command, :status, :retrieved_value

      def initialize(data = nil)
        super(data) && (yield self if block_given?)
      end

      def command_statuses
        [:OK, :ERROR, :Invalid_Command, :Invalid_Parameter]
      end

      def cmd_data=(data_string)
        self.frame_id, self.at_command, status_byte, self.retrieved_value = data_string.unpack("ca2ca*")
        self.status = case status_byte
        when 0..3 : command_statuses[status_byte]
        else raise "AT Command Response frame appears to include an invalid status: 0x%x" % status_byte
        end
        #actually assign and move along
        @cmd_data = data_string
      end
    end

    class RemoteCommandRequest < BaseCommandModeInterface
      def api_identifier ; 0x17 ; end
    end

    class RemoteCommandResponse < ReceivedFrame
    end

    class TransmitRequest < BaseCommandModeInterface
      def api_identifier ; 0x10 ; end
    end

    class ExplicitAddressingCommand < BaseCommandModeInterface
      def api_identifier ; 0x11 ; end
    end

    class TransmitStatus < ReceivedFrame
    end

    class ReceivePacket < ReceivedFrame
    end

    class ExplicitRxIndicator < ReceivedFrame
    end
  end
end
