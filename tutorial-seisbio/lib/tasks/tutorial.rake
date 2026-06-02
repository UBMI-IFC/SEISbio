require "tutorial_tui/runner"

namespace :tutorial do
  desc "Start the interactive terminal tutorial"
  task :start, [:file] => :environment do |_t, args|
    runner = TutorialTUI::Runner.new(lesson_path: args[:file])
    runner.run
  end
end
