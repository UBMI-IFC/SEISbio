require "open3"

module TutorialTUI
  class SandboxSessionManager
    def initialize
      @session = {}
    end

    def exec(command)
      cmd = command.to_s.strip
      
      # Handle conda activate/deactivate locally
      if (match = cmd.match(/^conda\s+activate\s+([^\s;]+)/))
        env_name = match[1]
        @session[:conda_env] = env_name
        return { output: "Environment activated: #{env_name}", exit_status: 0, duration_ms: 0 }
      elsif cmd.match?(/^conda\s+deactivate\b/)
        @session.delete(:conda_env)
        return { output: "Environment deactivated.", exit_status: 0, duration_ms: 0 }
      end

      # Prepare local bash command
      bash_cmd = if @session[:conda_env]
                   "source ~/.bashrc && conda activate #{@session[:conda_env]} && #{cmd}"
                 else
                   "source ~/.bashrc && #{cmd}"
                 end

      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      stdout, stderr, status = Open3.capture3("bash", "-c", bash_cmd)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i

      {
        output: [stdout, stderr].reject(&:empty?).join("\n"),
        exit_status: status.exitstatus,
        duration_ms: duration_ms
      }
    rescue StandardError => e
      {
        output: "Execution error: #{e.message}",
        exit_status: 1,
        duration_ms: 0
      }
    end

    def stop
      # Nothing to clean up for local sessions
    end
  end
end
