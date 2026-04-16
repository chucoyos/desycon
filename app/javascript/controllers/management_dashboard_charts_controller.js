import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["revenue", "containers", "blLines", "ports"]

  static values = {
    monthLabels: Array,
    revenue: Object,
    operations: Object,
    ports: Object
  }

  connect() {
    this.renderRevenueChart()
    this.renderContainersChart()
    this.renderBlLinesChart()
    this.renderPortsChart()
  }

  disconnect() {}

  renderRevenueChart() {
    if (!this.hasRevenueTarget) return

    this.drawBarChart(this.revenueTarget, {
      labels: this.monthLabelsValue,
      currency: true,
      datasets: [
        { label: "Emitido", data: this.revenueValue.emitted || [], color: "#10b981" },
        { label: "Cobrado", data: this.revenueValue.collected || [], color: "#3b82f6" }
      ]
    })
  }

  renderContainersChart() {
    if (!this.hasContainersTarget) return

    const containers = this.operationsValue.containers || {}
    this.drawLineChart(this.containersTarget, {
      labels: this.monthLabelsValue,
      currency: false,
      datasets: [
        { label: "Creados", data: containers.created || [], color: "#334155" },
        { label: "Cerrados", data: containers.closed || [], color: "#4f46e5" },
        { label: "Desconsolidados", data: containers.unconsolidated || [], color: "#0ea5e9" }
      ]
    })
  }

  renderBlLinesChart() {
    if (!this.hasBlLinesTarget) return

    const blLines = this.operationsValue.bl_house_lines || {}
    this.drawLineChart(this.blLinesTarget, {
      labels: this.monthLabelsValue,
      currency: false,
      datasets: [
        { label: "Creadas", data: blLines.created || [], color: "#f59e0b" },
        { label: "Revalidadas", data: blLines.revalidated || [], color: "#8b5cf6" },
        { label: "Despachadas", data: blLines.dispatched || [], color: "#22c55e" }
      ]
    })
  }

  renderPortsChart() {
    if (!this.hasPortsTarget) return

    const portPalette = {
      "Manzanillo": "rgba(244, 63, 94, 1)",
      "Lazaro Cardenas": "rgba(236, 72, 153, 1)",
      "Altamira": "rgba(249, 115, 22, 1)",
      "Veracruz": "rgba(234, 88, 12, 1)"
    }

    const datasets = Object.entries(this.portsValue || {}).map(([name, series]) => ({
      label: name,
      data: series,
      color: (portPalette[name] || "rgba(148, 163, 184, 1)").replace("rgba(", "rgb(").replace(", 1)", ")")
    }))

    this.drawLineChart(this.portsTarget, {
      labels: this.monthLabelsValue,
      currency: false,
      datasets
    })
  }

  drawBarChart(canvas, config) {
    const { ctx, w, h } = this.prepareCanvas(canvas)
    const labels = config.labels || []
    const datasets = config.datasets || []

    if (!labels.length || !datasets.some((d) => (d.data || []).some((v) => Number(v) > 0))) {
      this.drawEmptyState(ctx, w, h)
      return
    }

    const layout = this.computeLayout(ctx, w, h, datasets)
    this.drawLegend(ctx, layout.legend)
    this.drawAxes(ctx, layout)

    const { left, top, plotW, plotH } = layout
    const max = Math.max(1, ...datasets.flatMap((d) => d.data || [0]).map((v) => Number(v) || 0))
    const groups = Math.max(labels.length, 1)
    const barsPerGroup = Math.max(datasets.length, 1)
    const groupW = plotW / groups
    const innerPad = Math.min(10, groupW * 0.2)
    const barW = Math.max(6, (groupW - innerPad * 2) / barsPerGroup)

    for (let i = 0; i < labels.length; i++) {
      datasets.forEach((set, j) => {
        const value = Number((set.data || [])[i] || 0)
        const x = left + i * groupW + innerPad + j * barW
        const y = top + plotH - (value / max) * plotH
        const height = top + plotH - y
        ctx.fillStyle = this.alpha(set.color, 0.85)
        ctx.fillRect(x, y, barW - 2, height)
      })

      ctx.fillStyle = "#64748b"
      ctx.font = "11px sans-serif"
      ctx.textAlign = "center"
      ctx.fillText(labels[i], left + i * groupW + groupW / 2, top + plotH + 16)
    }

    this.drawYTicks(ctx, left, top, plotH, max, config.currency)
  }

  drawLineChart(canvas, config) {
    const { ctx, w, h } = this.prepareCanvas(canvas)
    const labels = config.labels || []
    const datasets = config.datasets || []

    if (!labels.length || !datasets.some((d) => (d.data || []).some((v) => Number(v) > 0))) {
      this.drawEmptyState(ctx, w, h)
      return
    }

    const layout = this.computeLayout(ctx, w, h, datasets)
    this.drawLegend(ctx, layout.legend)
    this.drawAxes(ctx, layout)

    const { left, top, plotW, plotH } = layout
    const max = Math.max(1, ...datasets.flatMap((d) => d.data || [0]).map((v) => Number(v) || 0))

    datasets.forEach((set) => {
      ctx.strokeStyle = set.color
      ctx.lineWidth = 2
      ctx.beginPath()

      labels.forEach((_, i) => {
        const value = Number((set.data || [])[i] || 0)
        const x = left + (i * plotW) / Math.max(labels.length - 1, 1)
        const y = top + plotH - (value / max) * plotH
        if (i === 0) ctx.moveTo(x, y)
        else ctx.lineTo(x, y)
      })

      ctx.stroke()
    })

    labels.forEach((label, i) => {
      const x = left + (i * plotW) / Math.max(labels.length - 1, 1)
      ctx.fillStyle = "#64748b"
      ctx.font = "11px sans-serif"
      ctx.textAlign = "center"
      ctx.fillText(label, x, top + plotH + 16)
    })

    this.drawYTicks(ctx, left, top, plotH, max, config.currency)
  }

  computeLayout(ctx, w, h, datasets) {
    const left = 56
    const right = 24
    const bottom = 36
    const legend = this.measureLegend(ctx, datasets, w, left, right)
    const top = legend.bottom + 14
    const plotW = Math.max(120, w - left - right)
    const plotH = Math.max(110, h - top - bottom)

    return { left, right, top, bottom, plotW, plotH, legend }
  }

  measureLegend(ctx, datasets, w, left, right) {
    const items = []
    const rowH = 18
    let x = left
    let y = 18
    const maxX = w - right

    ctx.font = "12px sans-serif"

    datasets.forEach((set) => {
      const labelWidth = ctx.measureText(set.label).width
      const itemW = Math.min(240, 12 + 8 + labelWidth + 16)

      if (x + itemW > maxX && x > left) {
        x = left
        y += rowH
      }

      items.push({ x, y, label: set.label, color: set.color })
      x += itemW
    })

    return { items, bottom: y + 8 }
  }

  prepareCanvas(canvas) {
    const ratio = window.devicePixelRatio || 1
    const width = canvas.clientWidth || 600
    const height = canvas.clientHeight || 320

    canvas.width = Math.floor(width * ratio)
    canvas.height = Math.floor(height * ratio)

    const ctx = canvas.getContext("2d")
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0)
    ctx.clearRect(0, 0, width, height)
    ctx.fillStyle = "#ffffff"
    ctx.fillRect(0, 0, width, height)

    return { ctx, w: width, h: height }
  }

  drawAxes(ctx, layout) {
    const { left, top, plotW, plotH } = layout
    ctx.strokeStyle = "#cbd5e1"
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.moveTo(left, top)
    ctx.lineTo(left, top + plotH)
    ctx.lineTo(left + plotW, top + plotH)
    ctx.stroke()
  }

  drawLegend(ctx, legend) {
    legend.items.forEach((set) => {
      ctx.fillStyle = set.color
      ctx.fillRect(set.x, set.y - 7, 12, 8)
      ctx.fillStyle = "#334155"
      ctx.font = "12px sans-serif"
      ctx.textAlign = "left"
      ctx.fillText(set.label, set.x + 18, set.y)
    })
  }

  drawYTicks(ctx, left, top, plotH, max, currency) {
    for (let i = 0; i <= 4; i++) {
      const value = (max * (4 - i)) / 4
      const y = top + (i * plotH) / 4
      ctx.strokeStyle = "#e2e8f0"
      ctx.beginPath()
      ctx.moveTo(left, y)
      ctx.lineTo(left + 8, y)
      ctx.stroke()

      ctx.fillStyle = "#64748b"
      ctx.font = "10px sans-serif"
      ctx.textAlign = "right"
      ctx.fillText(currency ? this.formatMoneyCompact(value) : this.formatNumber(value), left - 6, y + 3)
    }
  }

  drawEmptyState(ctx, w, h) {
    ctx.fillStyle = "#64748b"
    ctx.font = "14px sans-serif"
    ctx.textAlign = "center"
    ctx.fillText("Sin datos para mostrar", w / 2, h / 2)
  }

  formatNumber(value) {
    return new Intl.NumberFormat("es-MX", { maximumFractionDigits: 0 }).format(value)
  }

  formatMoneyCompact(value) {
    return new Intl.NumberFormat("es-MX", { notation: "compact", compactDisplay: "short" }).format(value)
  }

  alpha(color, alphaValue) {
    if (color.startsWith("#")) return color
    if (color.startsWith("rgb(")) return color.replace("rgb(", "rgba(").replace(")", `, ${alphaValue})`)
    return color
  }
}
