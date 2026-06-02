import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static values = {
		year: Number,
		invoicesPath: String,
		chartId: String,
		portSeriesByLabel: Object
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

		if (chart.__revenueByPortLinksBound) return

		const clickHandler = (event) => {
			const portLabel = event?.point?.series?.name || this.series?.name
			const monthIndex = Number(event?.point?.x ?? this.x)
			const targetUrl = this.buildInvoicesUrl(portLabel, monthIndex)
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

		chart.__revenueByPortLinksBound = true
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

	buildInvoicesUrl(portLabel, monthIndex) {
		const serie = this.portSeriesByLabelValue?.[portLabel]
		if (!serie) return null
		if (!Number.isInteger(monthIndex) || monthIndex < 0 || monthIndex > 11) return null

		const month = monthIndex + 1
		const year = this.yearValue

		const startDate = `${year}-${String(month).padStart(2, "0")}-01`
		const endDate = this.endOfMonth(year, month)

		const params = new URLSearchParams({
			kind: "ingreso",
			status_scope: "management_revenue",
			date_field: "issued_at",
			serie,
			start_date: startDate,
			end_date: endDate
		})

		return `${this.invoicesPathValue}?${params.toString()}`
	}

	endOfMonth(year, month) {
		const endDate = new Date(year, month, 0)
		const monthValue = String(endDate.getMonth() + 1).padStart(2, "0")
		const dayValue = String(endDate.getDate()).padStart(2, "0")
		return `${endDate.getFullYear()}-${monthValue}-${dayValue}`
	}
}
