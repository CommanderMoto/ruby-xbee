module XBee
  module Frame
    class ATCommandResponse < ReceivedFrame
      attr_accessor :frame_id, :at_command, :status, :retrieved_value

      def initialize(data = nil)
        super(data) && (yield self if block_given?)
      end

      def command_statuses
        [:OK, :ERROR, :Invalid_Command, :Invalid_Parameter]
      end

      def cmd_data=(data_string)
        self.frame_id, self.at_command, status_byte, self.retrieved_value = data_string.unpack("Ca2Ca*")
        self.status = case status_byte
        when 0..3 : command_statuses[status_byte]
        else raise "AT Command Response frame appears to include an invalid status: 0x%x" % status_byte
        end
        #actually assign and move along
        @cmd_data = data_string
      end
    end
  end
end
