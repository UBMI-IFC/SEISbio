class SandboxController < ApplicationController
  rescue_from StandardError, with: :handle_error

  def start
    name = sandbox_service.start!
    render json: { status: "ready", name: name }
  end

  def exec
    command = params[:command].to_s
    if command.strip.empty?
      render json: { error: "Command is required." }, status: :unprocessable_entity
      return
    end

    result = sandbox_service.exec(command)
    render json: result
  end

  def stop
    sandbox_service.stop!
    render json: { status: "stopped" }
  end

  private

  def sandbox_service
    @sandbox_service ||= SandboxService.new(session)
  end

  def handle_error(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end
end
