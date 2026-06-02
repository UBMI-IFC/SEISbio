require "yaml"

module TutorialTUI
  class YamlLessonLoader
    def initialize(path)
      @path = path
    end

    def load_lessons
      raw = YAML.safe_load(File.read(@path), aliases: true)

      if raw.is_a?(Hash) && raw["lessons"].is_a?(Array)
        return normalize_lessons(raw["lessons"])
      end

      # Backward-compatible: existing tutorial_commands.yml format
      if raw.is_a?(Array)
        return normalize_sections(raw)
      end

      raise "Unsupported lesson format in #{@path}"
    end

    private

    def normalize_lessons(lessons)
      lessons.map do |lesson|
        {
          id: lesson["id"],
          title: lesson["title"],
          description: lesson["description"],
          steps: normalize_steps(lesson["steps"] || [])
        }
      end
    end

    def normalize_sections(sections)
      sections.map do |section|
        steps = (section["commands"] || []).map do |cmd|
          {
            title: cmd["label"],
            command: cmd["command"],
            validation: { "contains" => tokenize(cmd["command"]) }
          }
        end

        {
          id: section["id"],
          title: section["title"],
          description: section["description"],
          steps: steps
        }
      end
    end

    def normalize_steps(steps)
      steps.map do |step|
        {
          title: step["title"] || step["label"],
          description: step["description"],
          command: step["command"],
          hint: step["hint"],
          validation: step["validation"],
          success_command: step["success_command"],
          success_contains: step["success_contains"]
        }
      end
    end

    def tokenize(command)
      command.to_s.strip.split(/\s+/).map(&:downcase)
    end
  end
end
