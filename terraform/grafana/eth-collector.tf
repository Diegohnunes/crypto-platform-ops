resource "grafana_dashboard" "eth-collector_apm" {
  config_json = jsonencode({
    title       = "eth-collector - APM Dashboard"
    uid         = "eth-collector-apm"
    tags        = ["apm", "ETH", "collector", "terraform"]
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
          datasource = { 
            type = "prometheus"
            uid = var.prometheus_datasource_uid 
          }
          expr = "eth-collector_up"
          refId = "A"
          legendFormat = ""
          instant = false
          range = true
        }]
        fieldConfig = {
          defaults = {
            unit = "none"
            decimals = 0
            thresholds = {
              mode = "absolute"
              steps = [
                { value = null, color = "red" },
                { value = 1, color = "green" }
              ]
            }
            mappings = [
              { 
                type = "value"
                options = {
                  "0" = { text = "DOWN", color = "red", index = 0 }
                  "1" = { text = "UP", color = "green", index = 1 }
                }
              }
            ]
          }
          overrides = []
        }
        options = {
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
          orientation = "auto"
          textMode = "auto"
          colorMode = "background"
          graphMode = "none"
          justifyMode = "auto"
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
          expr = "rate(eth-collector_data_collection_total[5m]) * 60"
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
          expr = "rate(eth-collector_data_collection_errors_total[5m]) * 60"
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
          expr = "sum(rate(eth-collector_api_calls_total{status=\"success\"}[5m])) / sum(rate(eth-collector_api_calls_total[5m])) * 100"
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
          expr = "sum by(endpoint) (rate(eth-collector_http_requests_total[5m]))"
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
          expr = "histogram_quantile(0.95, sum by(endpoint, le) (rate(eth-collector_http_request_duration_seconds_bucket[5m])))"
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
            expr = "rate(eth-collector_data_collection_total[5m]) * 60"
            refId = "A"
            legendFormat = "Success"
          },
          {
            datasource = { uid = var.prometheus_datasource_uid }
            expr = "rate(eth-collector_data_collection_errors_total[5m]) * 60"
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
          expr = "sum by(status) (rate(eth-collector_api_calls_total[5m]))"
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
        title = "ETH Price (USD)"
        type = "timeseries"
        gridPos = { h = 8, w = 24, x = 0, y = 22 }
        targets = [{
          datasource = { uid = var.prometheus_datasource_uid }
          expr = "crypto_price{symbol=\"ETH\"}"
          refId = "A"
          legendFormat = "ETH/USD"
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

output "dashboard_eth-collector_url" {
  value = "http://localhost:3000/d/$${grafana_dashboard.eth-collector_apm.uid}"
}