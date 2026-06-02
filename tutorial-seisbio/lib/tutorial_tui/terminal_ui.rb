require "tty-prompt"
require "tty-box"
require "tty-screen"
require "pastel"
require "tty-spinner"
require "io/console"

module TutorialTUI
  class TerminalUI
    def initialize
      @prompt = TTY::Prompt.new
      @pastel = Pastel.new
      @renderer = LessonRenderer.new(@pastel)
      @spinner = TTY::Spinner.new("[:spinner] Running command...", format: :dots)
      @last_output = ""
      @status = nil
      @status_detail = nil
    end

    def render(context)
      clear
      width = TTY::Screen.width
      height = TTY::Screen.height
      width = 80 if width < 80
      height = 24 if height < 24

      header = @renderer.header("Interactive Terminal Tutorial", context[:subtitle])
      lesson_info = @renderer.lesson_info(context[:lesson_title], context[:lesson_description])
      step_info = @renderer.step_info(context[:step_title], context[:step_description], context[:step_command], context[:step_hint])
      progress_line = progress_summary(context)

      puts safe_box(width: width, height: 5, title: " Tutorial ") { header }
      puts safe_box(width: width, title: " Lesson ") { lesson_info }
      puts safe_box(width: width, title: " Step ") { step_info }

      if @status
        status_line = @renderer.status_line(@status, @status_detail.to_s)
        puts safe_box(width: width, title: " Status ") { status_line }
      end

      # Ensure at least 5 visible output lines inside the box
      output_height = [height - 22, 8].max
      puts safe_box(width: width, height: output_height, title: " Output ") { truncate_output(@last_output, output_height - 4) }
      puts @pastel.dim(progress_line)
    end

    def prompt_command
      @prompt.ask(@pastel.bold("$"), required: true)
    end

    def pause(message = "Press any key to continue")
      print @pastel.dim(message)
      STDIN.getch
      puts
    end

    def with_spinner
      @spinner.auto_spin
      yield
    ensure
      @spinner.stop("done")
    end

    def set_output(output)
      @last_output = clean_output(output)
    end

    def set_status(status, detail)
      @status = status
      @status_detail = detail
    end

    def clear_status
      @status = nil
      @status_detail = nil
    end

    def show_completed(lesson_title)
      clear
      width = TTY::Screen.width
      message = @pastel.green("Lesson completed: #{lesson_title}")
      puts safe_box(width: width, padding: 2, title: " Completed ") { message }
      pause
    end

    def show_all_completed
      clear
      width = TTY::Screen.width
      message = @pastel.green("All lessons completed. Great job!")
      puts safe_box(width: width, padding: 2, title: " Finished ") { message }
    end

    private

    def clear
      # Use ANSI clear to avoid depending on tty-screen helpers
      print "\e[2J\e[H"
    end

    def progress_summary(context)
      lesson_progress = context[:lesson_progress]
      overall_percent = context[:overall_percent]
      "Lesson progress: #{lesson_progress[:completed]}/#{lesson_progress[:total]} | Course: #{context[:completed_steps]}/#{context[:total_steps]} (#{overall_percent}%)"
    end

    def truncate_output(output, max_lines)
      lines = output.to_s.split("\n")
      return output if lines.length <= max_lines

      lines.last(max_lines).join("\n")
    end

    def clean_output(output)
      return "" if output.nil?

      # Remove all ANSI escape sequences (colors, cursor movements, screen clear, etc.)
      cleaned = output.to_s.gsub(/\e\[[0-9;?]*[a-zA-Z]/, "")

      # Process carriage returns (\r) to simulate line overwrites in progress bars
      lines = cleaned.split("\n").map do |line|
        if line.include?("\r")
          line.split("\r").last || ""
        else
          line
        end
      end

      # Strip backspaces and other control characters
      lines.map! { |line| line.gsub(/[\b\u0007]/, "") }

      lines.join("\n")
    end

    def safe_box(width:, title:, padding: 1, height: nil)
      content = yield.to_s
      content = content.gsub(/\e\[[0-9;?]*[a-zA-Z]/, "") # avoid ANSI length and layout issues

      box_opts = { width: width, padding: padding, title: { top_left: title } }
      box_opts[:height] = height if height

      TTY::Box.frame(**box_opts) { content }
    rescue IndexError
      # Fallback: strip content if TTY::Box sizing explodes
      TTY::Box.frame(**box_opts) { "" }
    end
  end
end
