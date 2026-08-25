# Stands in for the shell, recording the command it was asked to run.
class StandInShell
  ExitStatus = Struct.new(:success?)

  attr_reader :ran

  def initialize(output = "", success: true)
    @output = output
    @success = success
  end

  def capture2(*command)
    @ran = command

    [ @output, ExitStatus.new(@success) ]
  end
end
