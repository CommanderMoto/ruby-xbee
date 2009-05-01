module XBee
  module ATCommands
    class ParameterDescriptor
      def initialize
        yield self if block_given?
      end
    end

    class CommandDescriptor
      attr_reader :command, :command_name, :command_description, :parameter

      def initialize (command, command_name, command_description = nil, parameter = nil)
        @command = command
        @command_name = command_name
        @command_description = command_description
        @parameter = parameter
        yield self if block_given?
      end

      def has_parameter?
        parameter.nil?
      end
    end

    AP_PARAM_DESCRIPTOR = ParameterDescriptor.new
    AP = CommandDescriptor.new("AP","API Mode","0 = off; 1 = on, unescaped; 2 = on, escaped", AP_PARAM_DESCRIPTOR)
  end
end
