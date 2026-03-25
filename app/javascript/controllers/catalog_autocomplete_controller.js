import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hiddenInput", "results", "status"]
  static values = {
    url: String,
    minChars: { type: Number, default: 2 },
    debounce: { type: Number, default: 300 }
  }

  connect() {
    this.abortController = null
    this.debounceTimer = null
    this.options = []
    this.activeIndex = -1
    this.selectedLabel = this.inputTarget.value.trim()

    this.hiddenInputTarget.disabled = false

    this.documentClickHandler = this.handleDocumentClick.bind(this)
    document.addEventListener("click", this.documentClickHandler)
  }

  disconnect() {
    this.cancelPendingRequest()
    this.clearDebounce()
    document.removeEventListener("click", this.documentClickHandler)
  }

  onInput() {
    const query = this.inputTarget.value.trim()

    if (query !== this.selectedLabel) {
      this.hiddenInputTarget.value = ""
      this.selectedLabel = ""
    }

    if (query.length < this.minCharsValue) {
      this.renderOptions([])
      this.setStatus(query.length === 0 ? "" : `Escribe al menos ${this.minCharsValue} caracteres.`)
      return
    }

    this.setStatus("Buscando...")
    this.clearDebounce()
    this.debounceTimer = setTimeout(() => this.search(query), this.debounceValue)
  }

  onFocus() {
    const query = this.inputTarget.value.trim()
    if (query.length >= this.minCharsValue && this.options.length > 0) {
      this.showResults()
    }
  }

  onBlur() {
    setTimeout(() => this.hideResults(), 120)
  }

  onKeydown(event) {
    if (this.options.length === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.activeIndex = Math.min(this.activeIndex + 1, this.options.length - 1)
      this.highlightActiveOption()
      return
    }

    if (event.key === "ArrowUp") {
      event.preventDefault()
      this.activeIndex = Math.max(this.activeIndex - 1, 0)
      this.highlightActiveOption()
      return
    }

    if (event.key === "Enter" && this.activeIndex >= 0) {
      event.preventDefault()
      this.selectOption(this.options[this.activeIndex])
      return
    }

    if (event.key === "Escape") {
      event.preventDefault()
      this.hideResults()
    }
  }

  async search(query) {
    this.cancelPendingRequest()
    this.abortController = new AbortController()

    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("q", query)

      const response = await fetch(url.toString(), {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal
      })

      if (!response.ok) {
        this.renderOptions([])
        this.setStatus("No fue posible cargar resultados.")
        return
      }

      const payload = await response.json()
      const results = Array.isArray(payload.results) ? payload.results : []
      this.renderOptions(results)
    } catch (error) {
      if (error.name !== "AbortError") {
        this.renderOptions([])
        this.setStatus("No fue posible cargar resultados.")
      }
    }
  }

  selectFromClick(event) {
    event.preventDefault()
    const index = Number(event.currentTarget.dataset.index)
    const option = this.options[index]
    if (option) {
      this.selectOption(option)
    }
  }

  handleDocumentClick(event) {
    if (!this.element.contains(event.target)) {
      this.hideResults()
    }
  }

  selectOption(option) {
    this.hiddenInputTarget.value = option.id
    this.inputTarget.value = option.label
    this.selectedLabel = option.label
    this.setStatus("")
    this.renderOptions([])
  }

  renderOptions(options) {
    this.options = options
    this.activeIndex = -1

    if (options.length === 0) {
      this.resultsTarget.innerHTML = ""
      this.hideResults()
      if (this.inputTarget.value.trim().length >= this.minCharsValue) {
        this.setStatus("Sin resultados.")
      }
      return
    }

    const list = document.createElement("ul")
    list.className = "py-1"

    options.forEach((option, index) => {
      const button = document.createElement("button")
      button.type = "button"
      button.dataset.index = String(index)
      button.className = "w-full px-4 py-2 text-left hover:bg-blue-50 focus:bg-blue-50 focus:outline-none"
      button.dataset.action = "mousedown->catalog-autocomplete#selectFromClick"

      const title = document.createElement("div")
      title.className = "text-sm font-medium text-gray-800"
      title.textContent = option.label
      button.appendChild(title)

      if (option.subtitle) {
        const subtitle = document.createElement("div")
        subtitle.className = "text-xs text-gray-500 mt-0.5"
        subtitle.textContent = option.subtitle
        button.appendChild(subtitle)
      }

      const li = document.createElement("li")
      li.appendChild(button)
      list.appendChild(li)
    })

    this.resultsTarget.innerHTML = ""
    this.resultsTarget.appendChild(list)
    this.showResults()
    this.setStatus(`${options.length} resultado${options.length === 1 ? "" : "s"}.`)
  }

  highlightActiveOption() {
    const buttons = this.resultsTarget.querySelectorAll("button[data-index]")
    buttons.forEach((button, index) => {
      if (index === this.activeIndex) {
        button.classList.add("bg-blue-50")
        button.scrollIntoView({ block: "nearest" })
      } else {
        button.classList.remove("bg-blue-50")
      }
    })
  }

  showResults() {
    this.resultsTarget.classList.remove("hidden")
  }

  hideResults() {
    this.resultsTarget.classList.add("hidden")
  }

  setStatus(message) {
    this.statusTarget.textContent = message
  }

  cancelPendingRequest() {
    if (this.abortController) {
      this.abortController.abort()
      this.abortController = null
    }
  }

  clearDebounce() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
      this.debounceTimer = null
    }
  }
}
