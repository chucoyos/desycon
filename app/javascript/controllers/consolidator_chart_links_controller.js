import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    year: Number,
    invoicesPath: String,
    chartId: String,
    consolidatorIdByName: Object
  }

  connect() {
    this.attachClickLinks(0)
  }

  attachClickLinks(attempt) {
    const chart = this.resolveChart()

    if (!chart) {
      if (attempt < 25) {
        setTimeout(() => this.attachClickLinks(attempt + 1), 120)
      }
      return
    }

    if (chart.__consolidatorLinksBound) return

    const clickHandler = (event) => {
      const consolidatorName = event?.point?.series?.name
      const targetUrl = this.buildInvoicesUrl(consolidatorName)
      if (!targetUrl) return

      window.location.assign(targetUrl)
    }

    chart.update(
      {
        plotOptions: {
          series: {
            cursor: "pointer",
            point: {
              events: {
                click: clickHandler
              }
            }
          }
        }
      },
      true,
      false,
      false
    )

    chart.__consolidatorLinksBound = true
  }

  resolveChart() {
    const chartId = this.chartIdValue

    const chartkickChart = window.Chartkick?.charts?.[chartId]
    if (chartkickChart?.getChartObject) {
      return chartkickChart.getChartObject()
    }

    const highchartsCharts = window.Highcharts?.charts || []
    return highchartsCharts.find((chart) => chart?.renderTo?.id === chartId)
  }

  buildInvoicesUrl(consolidatorName) {
    if (!consolidatorName) return null

    const consolidatorIdByName = this.consolidatorIdByNameValue || {}
    const consolidatorId = consolidatorIdByName[consolidatorName]
    
    if (!consolidatorId) return null

    const year = this.yearValue
    const startDate = `${year}-01-01`
    const endDate = `${year}-12-31`

    const params = new URLSearchParams({
      kind: "ingreso",
      status_scope: "management_revenue",
      date_field: "issued_at",
      start_date: startDate,
      end_date: endDate,
      consolidator_id: consolidatorId
    })

    return `${this.invoicesPathValue}?${params.toString()}`
  }
}
