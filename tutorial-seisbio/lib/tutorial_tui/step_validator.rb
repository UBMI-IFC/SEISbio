module TutorialTUI
  class StepValidator
    def initialize(step)
      @step = step
      @validation = step[:validation] || {}
    end

    def valid_input?(input)
      input = input.to_s.strip
      return [false, "Empty command"] if input.empty?

      [true, nil]
    end

    def matches_step?(input)
      input = input.to_s.strip
      return false if input.empty?

      if @validation["aliases"]
        return validate_aliases(input, @validation["aliases"]).first
      end

      if @validation["contains"]
        return validate_contains(input, @validation["contains"]).first
      end

      if @step[:command]
        return validate_contains(input, tokenize(@step[:command])).first
      end

      true
    end

    def validate_success!(sandbox)
      success_cmd = @step[:success_command]
      return [true, nil] if success_cmd.to_s.strip.empty?

      result = sandbox.exec(success_cmd)
      output = result[:output].to_s
      contains = @step[:success_contains]

      return [true, nil] if contains.nil?

      checks = contains.is_a?(Array) ? contains : [contains]
      missing = checks.reject { |needle| output.include?(needle.to_s) }
      if missing.empty?
        [true, nil]
      else
        [false, "Missing expected output: #{missing.join(", ")}"]
      end
    end

    private

    def validate_contains(input, contains)
      input_tokens = tokenize(input)
      needles = contains.is_a?(Array) ? contains : [contains]

      missing = needles.reject do |needle|
        needle_str = needle.to_s
        if needle_str.include?(" ")
          input.downcase.include?(needle_str.downcase)
        else
          input_tokens.include?(needle_str.downcase)
        end
      end

      if missing.empty?
        [true, nil]
      else
        [false, "Command is missing: #{missing.join(", ")}"]
      end
    end

    def tokenize(command)
      command.to_s.strip.split(/\s+/).map(&:downcase)
    end
  end

  def validate_aliases(input, aliases)
    candidates = aliases.is_a?(Array) ? aliases : [aliases]
    candidates.each do |candidate|
      ok, = validate_contains(input, tokenize(candidate))
      return [true, nil] if ok
    end

    [false, "Command does not match any allowed alias"]
  end
end
