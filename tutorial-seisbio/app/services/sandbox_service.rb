require "open3"
require "securerandom"
require "timeout"

class SandboxService
  IMAGE_NAME = ENV.fetch("SEISBIO_SANDBOX_IMAGE", "seisbio-tutorial-sandbox")
  CMD_TIMEOUT = Integer(ENV.fetch("SANDBOX_CMD_TIMEOUT", "600"))

  def initialize(session)
    @session = session
  end

  def start!
    name = current_name
    return name if name && container_running?(name)

    if name
      cleanup_container(name) if container_exists?(name)
      @session.delete(:sandbox_name)
      @session.delete(:conda_env)
    end

    name = "seisbio-sandbox-#{SecureRandom.hex(6)}"
    repo_path = ENV.fetch("SEISBIO_REPO_PATH", Rails.root.join("..").to_s)

    raise "Repo path does not exist: #{repo_path}" unless Dir.exist?(repo_path)

    run!(
      [
        "docker", "run", "-d",
        "--name", name,
        "--tmpfs", "/home/tutorial:exec,mode=755,size=4g,uid=1000,gid=1000",
        IMAGE_NAME
      ]
    )

    unless container_running?(name)
      logs = container_logs(name)
      cleanup_container(name)
      raise "Sandbox failed to stay running. Logs:\n#{logs}"
    end

    @session[:sandbox_name] = name
    name
  end

  def exec(command)
    name = start!
    if (env_name = conda_activate_name(command))
      return handle_conda_activate(name, env_name)
    end

    if conda_deactivate_command?(command)
      @session.delete(:conda_env)
      return { output: "Environment deactivated.", exit_status: 0, duration_ms: 0 }
    end

    normalized = normalize_command(command)

    stdout, stderr, status, duration_ms = run_with_timeout(
      ["docker", "exec", name, "bash", "-lc", normalized]
    )

    if status != 0 && container_exec_failure?(stderr)
      logs = container_logs(name)
      cleanup_container(name)
      return {
        output: "Sandbox stopped unexpectedly. Logs:\n#{logs}",
        exit_status: status,
        duration_ms: duration_ms
      }
    end

    {
      output: [stdout, stderr].reject(&:empty?).join("\n"),
      exit_status: status,
      duration_ms: duration_ms
    }
  end

  def stop!
    name = current_name
    return unless name

    cleanup_container(name)
    @session.delete(:sandbox_name)
    @session.delete(:conda_env)
  end

  private

  def current_name
    @session[:sandbox_name]
  end

  def container_running?(name)
    stdout, = Open3.capture3("docker", "ps", "--filter", "name=^/#{name}$", "--format", "{{.Names}}")
    stdout.split("\n").include?(name)
  end

  def container_exists?(name)
    stdout, = Open3.capture3("docker", "ps", "-a", "--filter", "name=^/#{name}$", "--format", "{{.Names}}")
    stdout.split("\n").include?(name)
  end

  def container_logs(name)
    stdout, stderr, = Open3.capture3("docker", "logs", name)
    combined = [stdout, stderr].reject(&:empty?).join("\n")
    combined.empty? ? "(no logs)" : combined
  rescue StandardError
    "(unable to read logs)"
  end

  def cleanup_container(name)
    stdout, stderr, status = Open3.capture3("docker", "rm", "-f", name)
    return if status.success?

    message = [stdout, stderr].reject(&:empty?).join("\n")
    raise "Sandbox cleanup error: #{message}" unless message.include?("No such container")
  end

  def container_exec_failure?(stderr)
    stderr.include?("No such container") || stderr.include?("is not running")
  end

  def normalize_command(command)
    cmd = command.to_s.strip
    return cmd if cmd.empty?

    update_conda_env_state(cmd)
    cmd = ensure_activate_shell(cmd)
    cmd = ensure_conda_bootstrap(cmd)
    cmd = prepend_conda_env(cmd)

    cmd
  end

  def update_conda_env_state(cmd)
    activate_match = cmd.match(/^\s*conda\s+activate\s+([^\s;]+)/)
    if activate_match
      @session[:conda_env] = activate_match[1]
      return
    end

    return unless cmd.match(/^\s*conda\s+deactivate/)

    @session.delete(:conda_env)
  end

  def ensure_conda_bootstrap(cmd)
    return cmd unless needs_conda?(cmd) || conda_env_present?

    bootstrap = <<~BASH.strip
      export PATH="/opt/miniforge/bin:$PATH"
      export CONDA_PKGS_DIRS="/home/tutorial/.conda/pkgs"
      export CONDA_ENVS_DIRS="/home/tutorial/.conda/envs"
    BASH

    "#{bootstrap}; #{cmd}"
  end

  def ensure_activate_shell(cmd)
    return cmd unless cmd.match(/^\s*conda\s+(activate|deactivate)\b/)

    "source /opt/miniforge/etc/profile.d/conda.sh; #{cmd}"
  end

  def prepend_conda_env(cmd)
    return cmd unless conda_env_present?
    return cmd if cmd.match(/^\s*conda\b/)

    "conda run -n #{current_conda_env} bash -c '#{cmd}'"
  end

  def conda_env_present?
    @session[:conda_env].to_s.strip.length.positive?
  end

  def current_conda_env
    @session[:conda_env]
  end

  def needs_conda?(cmd)
    cmd.match?(/^\s*(conda|mamba)\b/) || cmd.include?("conda ")
  end

  def conda_activate_name(cmd)
    match = cmd.to_s.strip.match(/^conda\s+activate\s+([^\s;]+)/)
    match ? match[1] : nil
  end

  def conda_deactivate_command?(cmd)
    cmd.to_s.strip.match?(/^conda\s+deactivate\b/)
  end

  def handle_conda_activate(container_name, env_name)
    check_cmd = ensure_conda_bootstrap("conda env list")
    stdout, stderr, status, duration_ms = run_with_timeout(
      ["docker", "exec", container_name, "bash", "-lc", check_cmd]
    )

    unless status == 0
      return { output: stderr, exit_status: status, duration_ms: duration_ms }
    end

    env_exists = stdout.lines.any? { |line| line.split.first == env_name }
    unless env_exists
      return {
        output: "EnvironmentNameNotFound: Could not find conda environment: #{env_name}",
        exit_status: 1,
        duration_ms: duration_ms
      }
    end

    @session[:conda_env] = env_name
    { output: "Environment activated: #{env_name}", exit_status: 0, duration_ms: duration_ms }
  end

  def run!(args)
    stdout, stderr, status = Open3.capture3(*args)
    return if status.success?

    message = "Sandbox error: #{stderr.strip.empty? ? stdout : stderr}"
    raise message
  end

  def run_with_timeout(args)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    stdout = ""
    stderr = ""
    status = nil

    Timeout.timeout(CMD_TIMEOUT) do
      stdout, stderr, status = Open3.capture3(*args)
    end

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i
    [stdout, stderr, status.exitstatus, duration_ms]
  rescue Timeout::Error
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i
    ["", "Command timed out after #{CMD_TIMEOUT}s", 124, duration_ms]
  end
end
