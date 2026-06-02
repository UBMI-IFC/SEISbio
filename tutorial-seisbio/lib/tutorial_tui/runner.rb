require "tutorial_tui/yaml_lesson_loader"
require "tutorial_tui/progress_tracker"
require "tutorial_tui/step_validator"
require "tutorial_tui/sandbox_session_manager"
require "tutorial_tui/lesson_renderer"
require "tutorial_tui/terminal_ui"

module TutorialTUI
  class Runner
    def initialize(lesson_path: nil)
      default_path = Rails.root.join("config", "tutorial_tui.yml")
      fallback_path = Rails.root.join("config", "tutorial_commands.yml")
      @lesson_path = lesson_path || (File.exist?(default_path) ? default_path : fallback_path)
      @loader = YamlLessonLoader.new(@lesson_path)
      @lessons = @loader.load_lessons
      @progress = ProgressTracker.new(@lessons)
      @sandbox = SandboxSessionManager.new
      @ui = TerminalUI.new
    end

    def run
      @lessons.each_with_index do |lesson, lesson_index|
        run_lesson(lesson, lesson_index)
        @ui.show_completed(lesson[:title])
      end

      @ui.show_all_completed
    rescue Interrupt
      @ui.set_status(:error, "Tutorial interrupted")
      @ui.render(
        subtitle: "Interrupted",
        lesson_title: "",
        lesson_description: "",
        step_title: "",
        step_description: "",
        step_command: "",
        step_hint: "",
        lesson_progress: { completed: 0, total: 0 },
        overall_percent: 0,
        completed_steps: @progress.completed_steps,
        total_steps: @progress.total_steps
      )
      @ui.pause("Press any key to exit")
    ensure
      @sandbox.stop
    end

    private

    def run_lesson(lesson, lesson_index)
      lesson[:steps].each_with_index do |step, step_index|
        run_step(lesson, lesson_index, step, step_index)
        @progress.complete_step!
      end
    end

    def run_step(lesson, lesson_index, step, step_index)
      validator = StepValidator.new(step)

      loop do
        render_context(lesson, lesson_index, step, step_index)
        input = @ui.prompt_command

        if quit_command?(input)
          @ui.set_status(:error, "Tutorial exited by user")
          render_context(lesson, lesson_index, step, step_index)
          @ui.pause("Press any key to exit")
          raise Interrupt
        end

        ok, error = validator.valid_input?(input)
        unless ok
          @ui.set_status(:error, error)
          next
        end

        result = @ui.with_spinner { @sandbox.exec(input) }
        @ui.set_output(result[:output])

        matches = validator.matches_step?(input)
        unless matches
          @ui.set_status(:error, "Command did not match step goal")
          render_context(lesson, lesson_index, step, step_index)
          next
        end

        if result[:exit_status] != 0
          @ui.set_status(:error, "Command failed (exit #{result[:exit_status]})")
          render_context(lesson, lesson_index, step, step_index)
          next
        end

        ok, error = validator.validate_success!(@sandbox)
        unless ok
          @ui.set_status(:error, error)
          render_context(lesson, lesson_index, step, step_index)
          next
        end

        @ui.set_status(:success, "Step complete")
        render_context(lesson, lesson_index, step, step_index)
        @ui.pause
        @ui.clear_status
        break
      end
    end

    def render_context(lesson, lesson_index, step, step_index)
      @ui.render(
        subtitle: "Lesson #{lesson_index + 1}/#{@lessons.length}",
        lesson_title: lesson[:title],
        lesson_description: lesson[:description],
        step_title: step[:title] || "Step #{step_index + 1}",
        step_description: step[:description],
        step_command: step[:command],
        step_hint: step[:hint],
        lesson_progress: @progress.lesson_progress(lesson_index),
        overall_percent: @progress.overall_percent,
        completed_steps: @progress.completed_steps,
        total_steps: @progress.total_steps
      )
    end

    def quit_command?(input)
      %w[exit quit q].include?(input.to_s.strip.downcase)
    end
  end
end
