module TutorialTUI
  class LessonRenderer
    def initialize(pastel)
      @pastel = pastel
    end

    def header(title, subtitle)
      [
        @pastel.bold(@pastel.green(title)),
        @pastel.dim(subtitle)
      ].join("\n")
    end

    def lesson_info(lesson_title, lesson_description)
      lines = []
      lines << @pastel.bold(lesson_title.to_s)
      lines << @pastel.dim(lesson_description.to_s) if lesson_description.to_s.strip.length.positive?
      lines.join("\n")
    end

    def step_info(step_title, step_description, step_command, hint)
      lines = []
      lines << @pastel.cyan("Step: #{step_title}")
      lines << @pastel.dim(step_description.to_s) if step_description.to_s.strip.length.positive?
      if step_command.to_s.strip.length.positive?
        lines << @pastel.yellow("Goal: #{step_command}")
      end
      if hint.to_s.strip.length.positive?
        lines << @pastel.blue("Hint: #{hint}")
      end
      lines.join("\n")
    end

    def status_line(status, detail)
      message = "#{status.to_s.upcase}: #{detail}"
      status == :success ? @pastel.green(message) : @pastel.red(message)
    end
  end
end
