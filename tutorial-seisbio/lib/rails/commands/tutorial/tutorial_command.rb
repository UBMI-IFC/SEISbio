require "tutorial_tui/runner"

module Rails
  module Command
    class TutorialCommand < Base
      desc "start", "Start the interactive terminal tutorial"
      option :file, type: :string, aliases: "-f", desc: "Path to lesson YAML file"

      def start
        path = options[:file]
        runner = TutorialTUI::Runner.new(lesson_path: path)
        runner.run
      end
    end
  end
end
