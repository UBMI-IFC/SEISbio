class TutorialController < ApplicationController
  def index
    commands_path = Rails.root.join("config", "tutorial_commands.yml")
    @sections = YAML.safe_load(File.read(commands_path), symbolize_names: true)
  end
end
