resource "grafana_dashboard" "xrp_collector_apm" {
  config_json = jsonencode({
    title       = "XRP - APM Dashboard"
    uid         = "xrp-collector-apm"
    tags        = ["premium", "apm", "XRP", "monitoring"]
    timezone    = "browser"
    editable    = true
    refresh     = "30s"
    schemaVersion = 39
    time = {
      from = "now-5m"
      to   = "now"
    }
    
    # Modern dark theme with custom background
    style = "dark"
    
    # Dashboard-wide styling
    graphTooltip = 1
    
    panels = [
      # === HTML HEADER PANEL ===
      {
        id = 99
        title = ""
        type = "text"
        gridPos = { h = 4, w = 24, x = 0, y = 0 }
        options = {
          mode = "html"
          content = <<-HTML
            <style>
              /* Fonte Tecnológica */
              @import url('https://fonts.googleapis.com/css2?family=Rajdhani:wght@500;700&display=swap');

              /* --- CSS GLOBAL (Fundo da Página Inteira) --- */
              .main-view, .dashboard-page, .dashboard-container {
                background: radial-gradient(circle at 50% 0%, #1a202c 0%, #0b0c10 100%) !important;
              }
              
              /* Grade de fundo sutil */
              .dashboard-container::before {
                content: "";
                position: absolute;
                top: 0; left: 0; width: 100%; height: 100%;
                background-image: 
                  linear-gradient(rgba(255, 255, 255, 0.03) 1px, transparent 1px),
                  linear-gradient(90deg, rgba(255, 255, 255, 0.03) 1px, transparent 1px);
                background-size: 40px 40px;
                pointer-events: none;
                z-index: 0;
              }

              /* Remove bordas do painel do Grafana para o Header flutuar */
              div[data-panel-id] .panel-container {
                background: transparent !important;
                border: none !important;
                box-shadow: none !important;
              }

              /* Animação do ponto verde */
              @keyframes pulse-ring {
                0% { box-shadow: 0 0 0 0 rgba(76, 175, 80, 0.4); }
                70% { box-shadow: 0 0 0 10px rgba(76, 175, 80, 0); }
                100% { box-shadow: 0 0 0 0 rgba(76, 175, 80, 0); }
              }
            </style>

            <!-- CONTAINER DO HEADER -->
            <div style="
              width: 100%;
              min-height: 80px;
              display: flex;
              justify-content: space-between;
              align-items: center;
              background: rgba(20, 30, 48, 0.7); /* Fundo semi-transparente */
              backdrop-filter: blur(12px); /* Efeito de vidro */
              border-bottom: 1px solid rgba(100, 150, 255, 0.2); /* Borda inferior sutil */
              border-radius: 6px;
              padding: 0 30px;
              box-sizing: border-box;
              font-family: 'Rajdhani', sans-serif;
              box-shadow: 0 10px 20px rgba(0,0,0,0.3);
            ">

              <!-- LADO ESQUERDO: Títulos -->
              <div style="display: flex; flex-direction: column; justify-content: center;">
                  <h1 style="
                    margin: 0;
                    font-size: 32px;
                    font-weight: 700;
                    color: #FFFFFF; /* Branco Sólido */
                    text-transform: uppercase;
                    letter-spacing: 2px;
                    text-shadow: 0 0 15px rgba(100, 181, 246, 0.4); /* Brilho azulado leve */
                    line-height: 1.2;
                  ">XRP Collector</h1>
                
                <div style="
                  display: flex; 
                  align-items: center; 
                  gap: 10px; 
                ">
                  <span style="
                    font-size: 14px; 
                    color: #94a3b8; 
                    font-weight: 500; 
                    letter-spacing: 1px;
                  ">APPLICATION MONITORING</span>
                </div>
              </div>

              <!-- LADO DIREITO: Status -->
              <div style="display: flex; align-items: center; gap: 20px;">
                <div style="
                  display: flex;
                  align-items: center;
                  gap: 10px;
                  padding: 8px 20px;
                  background: rgba(16, 185, 129, 0.1);
                  border: 1px solid rgba(16, 185, 129, 0.3);
                  border-radius: 4px;
                ">
                  <div style="
                    width: 8px;
                    height: 8px;
                    border-radius: 50%;
                    background: #10B981;
                    animation: pulse-ring 2s infinite;
                  "></div>
                  <span style="
                    color: #10B981;
                    font-weight: 700;
                    font-size: 16px;
                    letter-spacing: 1px;
                  ">SYSTEM ONLINE</span>
                </div>
              </div>
            </div>
          HTML
        }
        transparent = true
      },
      
      # === ROW: HEADER WITH BIG STATS ===
      {
        id = 100
        title = "System Overview"
        type = "row"
        gridPos = { h = 1, w = 24, x = 0, y = 4 }
        collapsed = false
      },

      
      # BIG STAT: Service Status (Premium Style)
      {
        id = 1
        title = "Service Status"
        type = "stat"
        gridPos = { h = 8, w = 6, x = 0, y = 5 }
        targets = [{
          datasource = { 
            type = "prometheus"
            uid = var.prometheus_datasource_uid 
          }
          expr = "xrp_collector_up"
          refId = "A"
        }]
        fieldConfig = {
          defaults = {
            unit = "none"
            decimals = 0
            thresholds = {
              mode = "absolute"
              steps = [
                { value = null, color = "rgba(237, 46, 24, 0.3)" },
                { value = 1, color = "rgba(50, 215, 75, 0.3)" }
              ]
            }
            mappings = [
              { 
                type = "value"
                options = {
                  "0" = { text = "DOWN", color = "red", index = 0 }
                  "1" = { text = "HEALTHY", color = "green", index = 1 }
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
          orientation = "horizontal"
          textMode = "value"
          colorMode = "background_gradient"
          graphMode = "none"
          justifyMode = "center"
          text = {
            titleSize = 16
            valueSize = 48
          }
        }
        pluginVersion = "10.0.0"
        transparent = false
      },
      
      # BIG STAT: XRP Price (Gradient Background)
      {
        id = 2
        title = "XRP Price"
        type = "stat"
        gridPos = { h = 8, w = 6, x = 6, y = 5 }
        targets = [{
          datasource = { 
            type = "prometheus"
            uid = var.prometheus_datasource_uid 
          }
          expr = "crypto_price{symbol=\"XRP\"}"
          refId = "A"
        }]
        fieldConfig = {
          defaults = {
            unit = "currencyUSD"
            decimals = 2
            thresholds = {
              mode = "absolute"
              steps = [
                { value = null, color = "rgba(255, 152, 0, 0.2)" },
                { value = 50000, color = "rgba(255, 204, 0, 0.2)" },
                { value = 80000, color = "rgba(76, 175, 80, 0.2)" }
              ]
            }
          }
          overrides = []
        }
        options = {
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
          }
          orientation = "horizontal"
          textMode = "value"
          colorMode = "background_gradient"
          graphMode = "area"
          justifyMode = "center"
          text = {
            titleSize = 16
            valueSize = 36
          }
        }
        pluginVersion = "10.0.0"
        transparent = false
      },
      
      # BIG STAT: Throughput (Data Collection Rate)
      {
        id = 3
        title = ""
        type = "stat"
        gridPos = { h = 8, w = 6, x = 12, y = 5 }
        targets = [{
          datasource = { 
            type = "prometheus"
            uid = var.prometheus_datasource_uid 
          }
          expr = "rate(xrp_collector_data_collection_total[5m]) * 60"
          refId = "A"
        }]
        fieldConfig = {
          defaults = {
            unit = "ops"
            decimals = 2
            displayName = "💾 Data Points/min"
            thresholds = {
              mode = "absolute"
              steps = [
                { value = null, color = "rgba(96, 125, 139, 0.2)" },
                { value = 0.5, color = "rgba(33, 150, 243, 0.2)" },
                { value = 1, color = "rgba(0, 188, 212, 0.2)" }
              ]
            }
          }
          overrides = []
        }
        options = {
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
          }
          orientation = "horizontal"
          textMode = "value_and_name"
          colorMode = "background_gradient"
          graphMode = "area"
          justifyMode = "center"
          text = {
            titleSize = 16
            valueSize = 32
          }
        }
        pluginVersion = "10.0.0"
      },
      
      # GAUGE: API Success Rate (Premium Gauge)
      {
        id = 4
        title = ""
        type = "gauge"
        gridPos = { h = 8, w = 6, x = 18, y = 5 }
        targets = [{
          datasource = { 
            type = "prometheus"
            uid = var.prometheus_datasource_uid 
          }
          expr = "sum(rate(xrp_collector_api_calls_total{status=\"success\"}[5m])) / sum(rate(xrp_collector_api_calls_total[5m])) * 100"
          refId = "A"
        }]
        fieldConfig = {
          defaults = {
            unit = "percent"
            decimals = 2
            displayName = "🎯 API Success Rate"
            min = 0
            max = 100
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "rgba(229, 57, 53, 0.8)" },
                { value = 90, color = "rgba(255, 193, 7, 0.8)" },
                { value = 95, color = "rgba(139, 195, 74, 0.8)" },
                { value = 99, color = "rgba(76, 175, 80, 0.8)" }
              ]
            }
          }
          overrides = []
        }
        options = {
          showThresholdLabels = false
          showThresholdMarkers = true
          orientation = "auto"
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
          }
          text = {
            titleSize = 16
            valueSize = 28
          }
        }
      },
      
      # === ROW: PERFORMANCE METRICS ===
      {
        id = 101
        title = "⚡ Performance & Latency"
        type = "row"
        gridPos = { h = 1, w = 24, x = 0, y = 13 }
        collapsed = false
      },
      
      # HTTP Request Rate (Modern Timeseries with Gradient)
      {
        id = 5
        title = "🌐 HTTP Request Rate"
        type = "timeseries"
        gridPos = { h = 9, w = 12, x = 0, y = 14 }
        targets = [{
          datasource = { 
            type = "prometheus"
            uid = var.prometheus_datasource_uid 
          }
          expr = "sum by(endpoint) (rate(xrp_collector_http_requests_total[5m]))"
          refId = "A"
          legendFormat = "{{endpoint}}"
        }]
        fieldConfig = {
          defaults = {
            unit = "reqps"
            color = { 
              mode = "palette-classic"
              seriesBy = "last"
            }
            custom = {
              lineWidth = 2
              lineInterpolation = "smooth"
              showPoints = "never"
              fillOpacity = 25
              gradientMode = "opacity"
              spanNulls = true
              axisPlacement = "auto"
              axisLabel = "Requests/sec"
              drawStyle = "line"
              pointSize = 5
            }
            thresholds = {
              mode = "absolute"
              steps = [
                { value = null, color = "green" }
              ]
            }
          }
          overrides = []
        }
        options = {
          tooltip = {
            mode = "multi"
            sort = "desc"
          }
          legend = {
            showLegend = true
            displayMode = "table"
            placement = "bottom"
            calcs = ["mean", "max", "last"]
          }
        }
      },
      
      # HTTP Response Time (Multi-Percentile)
      {
        id = 6
        title = "⏱️ HTTP Response Time (Percentiles)"
        type = "timeseries"
        gridPos = { h = 9, w = 12, x = 12, y = 14 }
        targets = [
          {
            datasource = { 
              type = "prometheus"
              uid = var.prometheus_datasource_uid 
            }
            expr = "histogram_quantile(0.50, sum by(le) (rate(xrp_collector_http_request_duration_seconds_bucket[5m])))"
            refId = "A"
            legendFormat = "p50 (median)"
          },
          {
            datasource = { 
              type = "prometheus"
              uid = var.prometheus_datasource_uid 
            }
            expr = "histogram_quantile(0.95, sum by(le) (rate(xrp_collector_http_request_duration_seconds_bucket[5m])))"
            refId = "B"
            legendFormat = "p95"
          },
          {
            datasource = { 
              type = "prometheus"
              uid = var.prometheus_datasource_uid 
            }
            expr = "histogram_quantile(0.99, sum by(le) (rate(xrp_collector_http_request_duration_seconds_bucket[5m])))"
            refId = "C"
            legendFormat = "p99"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "s"
            custom = {
              lineWidth = 2
              lineInterpolation = "smooth"
              showPoints = "never"
              fillOpacity = 20
              gradientMode = "hue"
              spanNulls = true
              axisPlacement = "auto"
              axisLabel = "Latency"
            }
          }
          overrides = [
            {
              matcher = { id = "byName", options = "p50 (median)" }
              properties = [
                { id = "color", value = { mode = "fixed", fixedColor = "blue" } }
              ]
            },
            {
              matcher = { id = "byName", options = "p95" }
              properties = [
                { id = "color", value = { mode = "fixed", fixedColor = "orange" } }
              ]
            },
            {
              matcher = { id = "byName", options = "p99" }
              properties = [
                { id = "color", value = { mode = "fixed", fixedColor = "red" } }
              ]
            }
          ]
        }
        options = {
          tooltip = {
            mode = "multi"
            sort = "desc"
          }
          legend = {
            showLegend = true
            displayMode = "table"
            placement = "bottom"
            calcs = ["mean", "max", "last"]
          }
        }
      },
      
      # === ROW: DATA COLLECTION ===
      {
        id = 102
        title = "📦 Data Collection & Reliability"
        type = "row"
        gridPos = { h = 1, w = 24, x = 0, y = 23 }
        collapsed = false
      },
      
      # Data Collection Success vs Errors (Dual Axis)
      {
        id = 7
        title = "📊 Data Collection Metrics"
        type = "timeseries"
        gridPos = { h = 9, w = 16, x = 0, y = 24 }
        targets = [
          {
            datasource = { 
              type = "prometheus"
              uid = var.prometheus_datasource_uid 
            }
            expr = "rate(xrp_collector_data_collection_total[5m]) * 60"
            refId = "A"
            legendFormat = "✅ Success"
          },
          {
            datasource = { 
              type = "prometheus"
              uid = var.prometheus_datasource_uid 
            }
            expr = "rate(xrp_collector_data_collection_errors_total[5m]) * 60"
            refId = "B"
            legendFormat = "❌ Errors"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "ops"
            custom = {
              lineWidth = 2
              lineInterpolation = "smooth"
              showPoints = "auto"
              fillOpacity = 30
              gradientMode = "opacity"
              spanNulls = true
              axisPlacement = "auto"
            }
          }
          overrides = [
            {
              matcher = { id = "byName", options = "✅ Success" }
              properties = [
                { 
                  id = "color"
                  value = { mode = "fixed", fixedColor = "green" } 
                },
                {
                  id = "custom.fillOpacity"
                  value = 40
                }
              ]
            },
            {
              matcher = { id = "byName", options = "❌ Errors" }
              properties = [
                { 
                  id = "color"
                  value = { mode = "fixed", fixedColor = "red" } 
                },
                {
                  id = "custom.fillOpacity"
                  value = 60
                }
              ]
            }
          ]
        }
        options = {
          tooltip = {
            mode = "multi"
            sort = "desc"
          }
          legend = {
            showLegend = true
            displayMode = "table"
            placement = "bottom"
            calcs = ["mean", "max", "last", "sum"]
          }
        }
      },
      
      # API Calls Distribution (Pie Chart)
      {
        id = 8
        title = "🔄 API Call Status Distribution"
        type = "piechart"
        gridPos = { h = 9, w = 8, x = 16, y = 24 }
        targets = [{
          datasource = { 
            type = "prometheus"
            uid = var.prometheus_datasource_uid 
          }
          expr = "sum by(status) (increase(xrp_collector_api_calls_total[5m]))"
          refId = "A"
          legendFormat = "{{status}}"
        }]
        fieldConfig = {
          defaults = {
            unit = "short"
            decimals = 0
          }
          overrides = [
            {
              matcher = { id = "byName", options = "success" }
              properties = [
                { id = "color", value = { mode = "fixed", fixedColor = "green" } }
              ]
            },
            {
              matcher = { id = "byName", options = "error" }
              properties = [
                { id = "color", value = { mode = "fixed", fixedColor = "red" } }
              ]
            }
          ]
        }
        options = {
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
          }
          pieType = "donut"
          displayLabels = ["name", "percent"]
          legend = {
            displayMode = "table"
            placement = "bottom"
            calcs = ["sum"]
            values = ["value"]
          }
          tooltip = {
            mode = "single"
          }
        }
      },
      
      # === ROW: BUSINESS METRICS ===
      {
        id = 103
        title = "💰 Business Metrics"
        type = "row"
        gridPos = { h = 1, w = 24, x = 0, y = 33 }
        collapsed = false
      },
      
      # XRP Price Chart (Premium Styling)
      {
        id = 9
        title = "₿ XRP Price (USDT)"
        type = "timeseries"
        gridPos = { h = 10, w = 24, x = 0, y = 34 }
        targets = [{
          datasource = { 
            type = "prometheus"
            uid = var.prometheus_datasource_uid 
          }
          expr = "crypto_price{symbol=\"XRP\"}"
          refId = "A"
          legendFormat = "XRP/USDT"
        }]
        fieldConfig = {
          defaults = {
            unit = "currencyUSD"
            decimals = 2
            color = { 
              mode = "thresholds"
            }
            custom = {
              lineWidth = 3
              lineInterpolation = "smooth"
              showPoints = "never"
              fillOpacity = 35
              gradientMode = "scheme"
              spanNulls = true
              axisPlacement = "auto"
              axisLabel = "Price (USD)"
              drawStyle = "line"
            }
            thresholds = {
              mode = "percentage"
              steps = [
                { value = 0, color = "red" },
                { value = 25, color = "orange" },
                { value = 50, color = "yellow" },
                { value = 75, color = "green" },
                { value = 100, color = "blue" }
              ]
            }
          }
          overrides = []
        }
        options = {
          tooltip = {
            mode = "multi"
            sort = "none"
          }
          legend = {
            showLegend = true
            displayMode = "list"
            placement = "bottom"
            calcs = ["mean", "min", "max", "last"]
          }
        }
      }
    ]
  })
}

output "dashboard_xrp_collector_url" {
  value = "http://localhost:3000/d/$${grafana_dashboard.xrp_collector_apm.uid}"
}