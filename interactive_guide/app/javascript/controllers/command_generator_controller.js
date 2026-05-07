import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["envName", "channels", "packages", "file", "dryRun", "output"]

  connect() {
    this.update()
  }

  update() {
    const envName = this.envNameTarget.value.trim()
    const channels = this.parseList(this.channelsTarget.value)
    const packages = this.parseList(this.packagesTarget.value)
    const file = this.fileTarget.value.trim()
    const dryRun = this.dryRunTarget.checked

    const parts = ["conda", "create"]
    if (envName) {
      parts.push("-n", envName)
    }
    channels.forEach((channel) => {
      parts.push("-c", channel)
    })
    if (file) {
      parts.push("--file", file)
    }
    if (packages.length) {
      parts.push(...packages)
    }
    if (dryRun) {
      parts.push("--dry-run")
    }

    this.outputTarget.textContent = parts.join(" ")
  }

  copy(event) {
    const button = event.currentTarget
    const text = button.dataset.copyText || this.outputTarget.textContent
    if (!text) return

    navigator.clipboard.writeText(text).then(() => {
      this.flash(button, "Copiado")
    })
  }

  parseList(value) {
    return value
      .split(/[,\s]+/)
      .map((item) => item.trim())
      .filter((item) => item.length > 0)
  }

  flash(button, message) {
    const original = button.dataset.originalText || button.textContent
    button.dataset.originalText = original
    button.textContent = message
    window.setTimeout(() => {
      button.textContent = original
    }, 1200)
  }
}
