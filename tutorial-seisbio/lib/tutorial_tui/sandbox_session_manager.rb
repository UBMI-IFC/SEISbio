module TutorialTUI
  class SandboxSessionManager
    def initialize
      @session = {}
      @service = SandboxService.new(@session)
    end

    def exec(command)
      @service.exec(command)
    end

    def stop
      @service.stop!
    end
  end
end
