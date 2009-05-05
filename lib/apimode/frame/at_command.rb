module XBee
  module Frame
    class ATCommand < Base
      def api_identifier ; 0x08 ; end

      attr_accessor :at_command, :parameter_value, :parameter_pack_string

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
        if parameter_value.nil?
          [frame_id, at_command].pack("ca2")
        else
          [frame_id, at_command, parameter_value].pack("ca2#{parameter_pack_string}")
        end
      end
    end

    class ATCommandQueueParameterValue < ATCommand
      def api_identifier ; 0x09 ; end
    end

  end
end
