import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hiddenInput", "results", "status"]
  static values = {
    url: String,
    minChars: { type: Number, default: 2 },
    debounce: { type: Number, default: 300 },
    dependsOnField: String,
    dependsOnParam: String
  }

  connect() {
    this.abortController = null
    this.debounceTimer = null
    this.blurTimer = null
    this.options = []
    this.activeIndex = -1
    this.selectedLabel = this.inputTarget.value.trim()
    this.selectedOptionDataKeys = []

    this.hiddenInputTarget.disabled = false

    this.documentClickHandler = this.handleDocumentClick.bind(this)
    document.addEventListener("click", this.documentClickHandler)
  }

  disconnect() {
    this.cancelPendingRequest()
    this.clearDebounce()
    this.clearBlurTimer()
    document.removeEventListener("click", this.documentClickHandler)
  }

  onInput() {
    const query = this.inputTarget.value.trim()

    if (query !== this.selectedLabel) {
      const hadValue = this.hiddenInputTarget.value !== ""
      this.hiddenInputTarget.value = ""
      this.selectedLabel = ""
      this.clearSelectedOptionData()
      if (hadValue) {
        this.hiddenInputTarget.dispatchEvent(new Event("change", { bubbles: true }))
      }
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
    this.clearBlurTimer()
    this.blurTimer = setTimeout(() => {
      if (!this.element.isConnected) return

      this.resolveSelectionOnBlur({ showError: false })
        .finally(() => this.hideResults())
    }, 120)
  }

  async resolveSelectionOnBlur({ showError = true } = {}) {
    const query = this.inputTarget.value.trim()
    if (!query || this.hiddenInputTarget.value) return

    // If we have no options loaded yet, run one final search before deciding.
    if (this.options.length === 0 && query.length >= this.minCharsValue) {
      await this.search(query)
    }

    if (this.options.length === 0) return

    const normalizedQuery = this.normalizeText(query)
    const exactMatch = this.options.find((option) => this.normalizeText(option.label) === normalizedQuery)

    if (exactMatch) {
      this.selectOption(exactMatch)
      return
    }

    if (this.options.length === 1) {
      this.selectOption(this.options[0])
      return
    }

    if (showError) {
      this.setStatus("Selecciona una opción de la lista.")
    }
  }

  normalizeText(text) {
    return (text || "")
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .trim()
  }

  onKeydown(event) {
    if (event.key === "ArrowDown") {
      if (this.options.length === 0) return
      event.preventDefault()
      this.activeIndex = Math.min(this.activeIndex + 1, this.options.length - 1)
      this.highlightActiveOption()
      return
    }

    if (event.key === "ArrowUp") {
      if (this.options.length === 0) return
      event.preventDefault()
      this.activeIndex = Math.max(this.activeIndex - 1, 0)
      this.highlightActiveOption()
      return
    }

    if (event.key === "Enter") {
      if (this.activeIndex >= 0 && this.options[this.activeIndex]) {
        event.preventDefault()
        this.selectOption(this.options[this.activeIndex])
        return
      }

      if (!this.hiddenInputTarget.value && this.inputTarget.value.trim() !== "") {
        event.preventDefault()
        this.resolveSelectionOnBlur({ showError: true })
      }

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

      if (this.hasDependsOnFieldValue && this.hasDependsOnParamValue) {
        const dependencyField = document.getElementById(this.dependsOnFieldValue)
        const dependencyValue = dependencyField?.value?.trim()
        if (dependencyValue) {
          url.searchParams.set(this.dependsOnParamValue, dependencyValue)
        }
      }

      const response = await fetch(url.toString(), {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal
      })

      if (!response.ok) {
        this.renderOptions([])
        this.setStatus("No fue posible cargar resultados.")
        return []
      }

      const payload = await response.json()
      const results = Array.isArray(payload.results) ? payload.results : []
      this.renderOptions(results)
      return results
    } catch (error) {
      if (error.name !== "AbortError") {
        this.renderOptions([])
        this.setStatus("No fue posible cargar resultados.")
      }

      return []
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
    this.applySelectedOptionData(option)
    this.hiddenInputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.setStatus("")
    this.renderOptions([], { suppressEmptyStatus: true })
  }

  applySelectedOptionData(option) {
    this.clearSelectedOptionData()

    const payload = option?.data
    if (!payload || typeof payload !== "object") return

    Object.entries(payload).forEach(([key, value]) => {
      if (value === null || value === undefined) return

      const normalizedKey = this.normalizeDataKey(key)
      this.hiddenInputTarget.dataset[normalizedKey] = String(value)
      this.selectedOptionDataKeys.push(normalizedKey)
    })
  }

  clearSelectedOptionData() {
    this.selectedOptionDataKeys.forEach((key) => {
      delete this.hiddenInputTarget.dataset[key]
    })
    this.selectedOptionDataKeys = []
  }

  normalizeDataKey(key) {
    return String(key)
      .replace(/[-_]+([a-zA-Z0-9])/g, (_, char) => char.toUpperCase())
      .replace(/^[A-Z]/, (char) => char.toLowerCase())
  }

  renderOptions(options, { suppressEmptyStatus = false } = {}) {
    if (!this.element.isConnected || !this.hasResultsTarget || !this.hasInputTarget) {
      return
    }

    this.options = options
    this.activeIndex = -1

    if (options.length === 0) {
      this.resultsTarget.innerHTML = ""
      this.hideResults()
      if (!suppressEmptyStatus && this.inputTarget.value.trim().length >= this.minCharsValue) {
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
    this.activeIndex = 0
    this.showResults()
    this.highlightActiveOption()
    this.setStatus(`${options.length} resultado${options.length === 1 ? "" : "s"}.`)
  }

  highlightActiveOption() {
    if (!this.element.isConnected || !this.hasResultsTarget) return

    const buttons = this.resultsTarget.querySelectorAll("button[data-index]")
    buttons.forEach((button, index) => {
      if (index === this.activeIndex) {
        button.classList.add("bg-blue-50")
        if (button.isConnected) {
          try {
            button.scrollIntoView({ block: "nearest" })
          } catch (_error) {
            // Ignore transient detached-node errors during Turbo navigation.
          }
        }
      } else {
        button.classList.remove("bg-blue-50")
      }
    })
  }

  showResults() {
    if (!this.element.isConnected || !this.hasResultsTarget) return
    this.resultsTarget.classList.remove("hidden")
  }

  hideResults() {
    if (!this.hasResultsTarget) return
    this.resultsTarget.classList.add("hidden")
  }

  setStatus(message) {
    if (!this.hasStatusTarget) return
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

  clearBlurTimer() {
    if (this.blurTimer) {
      clearTimeout(this.blurTimer)
      this.blurTimer = null
    }
  }
}
