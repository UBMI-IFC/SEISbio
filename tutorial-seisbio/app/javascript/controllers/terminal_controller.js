import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output", "input", "status", "progress"]

  connect() {
    this.sandboxReady = false
    this.setStatus("Not started")
    this.focus()

    // Install a single unload handler once per page to stop sandbox on close
    if (!window.__seisbio_sandbox_unload_installed) {
      window.__seisbio_sandbox_unload_installed = true
      const token = document.querySelector("meta[name='csrf-token']")?.content
      window.addEventListener('beforeunload', () => {
        try {
          navigator.sendBeacon ||= false
        } catch (_) {}
        try {
          fetch('/sandbox/stop', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': token },
            body: JSON.stringify({}),
            keepalive: true
          })
        } catch (e) {
          // best-effort
        }
      })
    }
  }

  // Do not auto-stop on disconnect to allow multiple terminals to share the same sandbox

  async start() {
    if (this.sandboxReady) {
      return true
    }

    this.setStatus("Starting sandbox...")
    const response = await this.postJson("/sandbox/start", {})
    if (response.error) {
      this.appendLine(`Error: ${response.error}`)
      this.setStatus("Error starting")
      this.sandboxReady = false
      return false
    }

    this.sandboxReady = true
    this.setStatus(`Sandbox ready: ${response.name}`)
    return true
  }

  async stop() {
    await this.postJson("/sandbox/stop", {})
    this.sandboxReady = false
    this.setStatus("Sandbox stopped")
  }

  async run() {
    const command = this.inputTarget.value.trim()
    if (!command) {
      return
    }

    const ready = await this.start()
    if (!ready) {
      return
    }
    this.appendLine(`$ ${command}`)
    this.inputTarget.value = ""
    this.focus()

    // show progress for long-running installs/searches
    const shouldShow = /^(pip install|conda (install|create|update|env create)|mamba (install|create)|apt |pacman |yay )/i.test(command)
    this.showProgress(shouldShow)
    const response = await this.postJson("/sandbox/exec", { command: command })
    this.hideProgress()
    if (response.error) {
      this.appendLine(`Error: ${response.error}`)
      return
    }

    if (response.output && response.output.length > 0) {
      this.appendLine(response.output)
    }

    this.appendLine(`(exit ${response.exit_status}, ${response.duration_ms}ms)`)
  }

  // Execute a command received from a section button (runs directly)
  async runCommand(event) {
    const command = event.params?.command || event.target?.dataset?.terminalCommand
    if (!command) return

    const ready = await this.start()
    if (!ready) return

    this.appendLine(`$ ${command}`)

    const shouldShow = /^(pip install|conda (install|create|update|env create)|mamba (install|create)|apt |pacman |yay )/i.test(command)
    this.showProgress(shouldShow)
    const response = await this.postJson('/sandbox/exec', { command: command })
    this.hideProgress()
    if (response.error) {
      this.appendLine(`Error: ${response.error}`)
      return
    }
    if (response.output && response.output.length > 0) {
      this.appendLine(response.output)
    }
    this.appendLine(`(exit ${response.exit_status}, ${response.duration_ms}ms)`)
  }

  queue(event) {
    const command = event.params.command
    this.inputTarget.value = command
    this.inputTarget.focus()
  }

  focus() {
    this.inputTarget?.focus()
  }

  appendLine(line) {
    const current = this.outputTarget.textContent
    this.outputTarget.textContent = current.length > 0 ? `${current}\n${line}` : line
    this.outputTarget.scrollTop = this.outputTarget.scrollHeight
  }

  showProgress(immediate = false) {
    if (!this.hasProgressTarget) return
    clearInterval(this._progressInterval)
    const container = this.progressTarget
    const bar = container.querySelector('.progress-bar')
    if (!bar) return
    container.classList.add('active')
    bar.style.width = immediate ? '6%' : '2%'
    // slowly increase width to simulate progress (up to 95%)
    this._progressInterval = setInterval(() => {
      const cur = parseFloat(bar.style.width)
      if (isNaN(cur)) bar.style.width = '2%'
      let inc = Math.random() * 6 + 2 // 2-8%
      let next = Math.min(95, cur + inc)
      bar.style.width = `${next}%`
    }, 700)
  }

  hideProgress() {
    if (!this.hasProgressTarget) return
    const container = this.progressTarget
    const bar = container.querySelector('.progress-bar')
    if (!bar) return
    clearInterval(this._progressInterval)
    bar.style.width = '100%'
    setTimeout(() => {
      bar.style.width = '0%'
      container.classList.remove('active')
    }, 350)
  }

  setStatus(text) {
    this.statusTarget.textContent = `Status: ${text}`
  }

  async postJson(url, payload) {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token
      },
      body: JSON.stringify(payload)
    })

    let data = null
    try {
      data = await response.json()
    } catch (error) {
      return { error: `Invalid response (${response.status})` }
    }

    if (!response.ok && !data?.error) {
      return { error: `Server error (${response.status})` }
    }

    return data
  }
}
