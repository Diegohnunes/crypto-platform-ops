resource "grafana_dashboard" "btc_collector_apm" {
  config_json = jsonencode({
    title       = "btc_collector - APM Dashboard"
    uid         = "btc_collector-apm"
    tags        = ["apm", "BTC", "collector", "terraform"]
    timezone    = "browser"
    editable    = true
    refresh     = "30s"
    schemaVersion = 39
    time = {
      from = "now-1m"
      to   = "now"
    }
    
    panels = [
      # Row 1: Service Health
      {
        id = 1
        title = "Service Status"
        type = "stat"
        gridPos = { h = 6, w = 6, x = 0, y = 0 }
        targets = [{
          datasource = { uid = var.prometheus_datasource_uid }
          expr = "btc_collector_up"
          refId = "A"
          legendFormat = "btc_collector"
        }]
        fieldConfig = {
          defaults = {
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "red" },
                { value = 1, color = "green" }
              ]
            }
            mappings = [
              { type = "value", value = "0", text = "DOWN" },
              { type = "value", value = "1", text = "UP" }
            ]
          }
        }
        options = {
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
          }
          textMode = "auto"
          colorMode = "background"
          graphMode = "none"
        }
      },
      
      # Row 1: Throughput
      {
        id = 2
        title = "Data Collection Rate"
        type = "stat"
        gridPos = { h = 6, w = 6, x = 6, y = 0 }
        targets = [{
          datasource = { uid = var.prometheus_datasource_uid }
          expr = "rate(btc_collector_data_collection_total[5m]) * 60"
          refId = "A"
          legendFormat = "Data points/min"
        }]
        fieldConfig = {
          defaults = {
            unit = "ops"
            color = { mode = "palette-classic" }
          }
        }
        options = {
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
          }
          textMode = "auto"
          colorMode = "value"
          graphMode = "area"
        }
      },
      
      # Row 1: Error Rate
      {
        id = 3
        title = "Error Rate"
        type = "stat"
        gridPos = { h = 6, w = 6, x = 12, y = 0 }
        targets = [{
          datasource = { uid = var.prometheus_datasource_uid }
          expr = "rate(btc_collector_data_collection_errors_total[5m]) * 60"
          refId = "A"
          legendFormat = "Errors/min"
        }]
        fieldConfig = {
          defaults = {
            unit = "ops"
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "green" },
                { value = 0.1, color = "yellow" },
                { value = 1, color = "red" }
              ]
            }
          }
        }
        options = {
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
          }
          textMode = "auto"
          colorMode = "background"
          graphMode = "area"
        }
      },
      
      # Row 1: API Success Rate
      {
        id = 4
        title = "API Success Rate"
        type = "gauge"
        gridPos = { h = 6, w = 6, x = 18, y = 0 }
        targets = [{
          datasource = { uid = var.prometheus_datasource_uid }
          expr = "sum(rate(btc_collector_api_calls_total{status=\"success\"}[5m])) / sum(rate(btc_collector_api_calls_total[5m])) * 100"
          refId = "A"
        }]
        fieldConfig = {
          defaults = {
            unit = "percent"
            min = 0
            max = 100
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "red" },
                { value = 90, color = "yellow" },
                { value = 99, color = "green" }
              ]
            }
          }
        }
        options = {
          showThresholdLabels = false
          showThresholdMarkers = true
        }
      },
      
      # Row 2: HTTP Request Rate
      {
        id = 5
        title = "HTTP Request Rate"
        type = "timeseries"
        gridPos = { h = 8, w = 12, x = 0, y = 6 }
        targets = [{
          datasource = { uid = var.prometheus_datasource_uid }
          expr = "sum by(endpoint) (rate(btc_collector_http_requests_total[5m]))"
          refId = "A"
          legendFormat = "{{endpoint}}"
        }]
        fieldConfig = {
          defaults = {
            unit = "reqps"
            custom = {
              lineInterpolation = "smooth"
              showPoints = "never"
              fillOpacity = 10
            }
          }
        }
        options = {
          legend = {
            displayMode = "table"
            placement = "bottom"
            calcs = ["mean", "max"]
          }
        }
      },
      
      # Row 2: HTTP Response Time (p95)
      {
        id = 6
        title = "HTTP Response Time (p95)"
        type = "timeseries"
        gridPos = { h = 8, w = 12, x = 12, y = 6 }
        targets = [{
          datasource = { uid = var.prometheus_datasource_uid }
          expr = "histogram_quantile(0.95, sum by(endpoint, le) (rate(btc_collector_http_request_duration_seconds_bucket[5m])))"
          refId = "A"
          legendFormat = "{{endpoint}} (p95)"
        }]
        fieldConfig = {
          defaults = {
            unit = "s"
            custom = {
              lineInterpolation = "smooth"
              showPoints = "never"
              fillOpacity = 10
            }
          }
        }
        options = {
          legend = {
            displayMode = "table"
            placement = "bottom"
            calcs = ["mean", "max"]
          }
        }
      },
      
      # Row 3: Data Collection Trend
      {
        id = 7
        title = "Data Collection Success vs Errors"
        type = "timeseries"
        gridPos = { h = 8, w = 12, x = 0, y = 14 }
        targets = [
          {
            datasource = { uid = var.prometheus_datasource_uid }
            expr = "rate(btc_collector_data_collection_total[5m]) * 60"
            refId = "A"
            legendFormat = "Success"
          },
          {
            datasource = { uid = var.prometheus_datasource_uid }
            expr = "rate(btc_collector_data_collection_errors_total[5m]) * 60"
            refId = "B"
            legendFormat = "Errors"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "ops"
            custom = {
              lineInterpolation = "smooth"
              showPoints = "never"
              fillOpacity = 20
            }
          }
          overrides = [
            {
              matcher = { id = "byName", options = "Errors" }
              properties = [
                { id = "color", value = { mode = "fixed", fixedColor = "red" } }
              ]
            }
          ]
        }
      },
      
      # Row 3: API Calls by Status
      {
        id = 8
        title = "API Calls by Status"
        type = "timeseries"
        gridPos = { h = 8, w = 12, x = 12, y = 14 }
        targets = [{
          datasource = { uid = var.prometheus_datasource_uid }
          expr = "sum by(status) (rate(btc_collector_api_calls_total[5m]))"
          refId = "A"
          legendFormat = "{{status}}"
        }]
        fieldConfig = {
          defaults = {
            unit = "reqps"
            custom = {
              lineInterpolation = "smooth"
              showPoints = "never"
              fillOpacity = 10
              stacking = { mode = "normal" }
            }
          }
        }
        options = {
          legend = {
            displayMode = "table"
            placement = "bottom"
            calcs = ["mean", "max"]
          }
        }
      },
      
      # Row 4: Crypto Price (Business Metric)
      {
        id = 9
        title = "BTC Price (USD)"
        type = "timeseries"
        gridPos = { h = 8, w = 24, x = 0, y = 22 }
        targets = [{
          datasource = { uid = var.prometheus_datasource_uid }
          expr = "crypto_price{symbol=\"BTC\"}"
          refId = "A"
          legendFormat = "BTC/USD"
        }]
        fieldConfig = {
          defaults = {
            unit = "currencyUSD"
            custom = {
              lineInterpolation = "smooth"
              showPoints = "never"
              fillOpacity = 20
            }
          }
        }
        options = {
          legend = {
            displayMode = "list"
            placement = "bottom"
          }
        }
      }
    ]
  })
}

output "dashboard_btc_collector_url" {
  value = "http://localhost:3000/d/$${grafana_dashboard.btc_collector_apm.uid}"
}
