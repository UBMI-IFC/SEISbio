module TutorialTUI
  class ProgressTracker
    def initialize(lessons)
      @lessons = lessons
      @completed_steps = 0
    end

    def total_steps
      @lessons.sum { |lesson| lesson[:steps].length }
    end

    def complete_step!
      @completed_steps += 1
    end

    def completed_steps
      @completed_steps
    end

    def overall_percent
      return 0 if total_steps.zero?

      ((@completed_steps.to_f / total_steps) * 100).round
    end

    def lesson_progress(lesson_index)
      completed_before = @lessons.take(lesson_index).sum { |lesson| lesson[:steps].length }
      current_steps = @lessons[lesson_index][:steps].length
      completed_in_lesson = [@completed_steps - completed_before, 0].max
      completed_in_lesson = [completed_in_lesson, current_steps].min

      {
        completed: completed_in_lesson,
        total: current_steps
      }
    end
  end
end
