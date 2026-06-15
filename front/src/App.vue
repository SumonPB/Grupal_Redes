<template>
  <div class="dashboard">
    <!-- HEADER -->
    <header class="header">
      <div class="header-left">
        <span class="header-tag">BDI · GAMA Platform</span>
        <h1 class="header-title">WannaCry Network Simulation</h1>
      </div>
      <div class="header-stats">
        <div class="stat" :class="{ danger: stats.infectados > 0 }">
          <span class="stat-value">{{ stats.infectados }}</span>
          <span class="stat-label">Infectados</span>
        </div>
        <div class="stat">
          <span class="stat-value">{{ stats.sanos }}</span>
          <span class="stat-label">Sanos</span>
        </div>
        <div class="stat warn">
          <span class="stat-value">{{ stats.aislados }}</span>
          <span class="stat-label">Aislados</span>
        </div>
        <div class="stat">
          <span class="stat-value">{{ stats.ciclo }}</span>
          <span class="stat-label">Ciclo</span>
        </div>
        <div class="pulse-dot" :class="pollingActive ? 'active' : 'inactive'"></div>
      </div>
    </header>

    <!-- MAPA DE RED -->
    <section class="map-section">
      <div class="section-label">Red · Topología en vivo</div>
      <div ref="cyContainer" class="cy-container"></div>
      <div class="legend">
        <span class="leg-item"><span class="dot" style="background:#22c55e"></span>Sano</span>
        <span class="leg-item"><span class="dot" style="background:#ef4444"></span>Infectado</span>
        <span class="leg-item"><span class="dot"
            style="background:#1e293b;border:2px solid #475569"></span>Aislado</span>
        <span class="leg-item"><span class="dot square" style="background:#3b82f6"></span>Firewall</span>
        <span class="leg-item"><span class="dot square" style="background:#94a3b8"></span>Switch</span>
        <span class="leg-item"><span class="dot" style="background:#facc15"></span>Internet</span>
      </div>
    </section>

    <!-- GRAFICAS -->
    <section class="charts-section">
      <div class="chart-card">
        <div class="chart-label">Infectados por ciclo</div>
        <div ref="chartInfectados" class="chart-box"></div>
      </div>
      <div class="chart-card">
        <div class="chart-label">Patch level promedio</div>
        <div ref="chartPatch" class="chart-box"></div>
      </div>
      <div class="chart-card">
        <div class="chart-label">Intenciones BDI</div>
        <div ref="chartIntenciones" class="chart-box"></div>
      </div>
      <div class="chart-card events-card">
        <div class="chart-label">Eventos en tiempo real</div>
        <div class="events-table-wrap">
          <table class="events-table">
            <thead>
              <tr>
                <th>Ciclo</th>
                <th>Nodo</th>
                <th>Evento</th>
                <th>Desde</th>
                <th>P</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(ev, i) in eventosRecientes" :key="i" :class="rowClass(ev.evento)">
                <td>{{ ev.ciclo }}</td>
                <td>{{ ev.nodo }}</td>
                <td><span class="badge" :class="badgeClass(ev.evento)">{{ ev.evento }}</span></td>
                <td>{{ ev.desde }}</td>
                <td>{{ ev.probabilidad && ev.probabilidad !== '-' ? parseFloat(ev.probabilidad).toFixed(3) : '-' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import Papa from 'papaparse'
import * as echarts from 'echarts'
import cytoscape from 'cytoscape'

const BASE = '/results'

const cyContainer = ref(null)
const chartInfectados = ref(null)
const chartPatch = ref(null)
const chartIntenciones = ref(null)

let cy = null
let ecInfectados = null
let ecPatch = null
let ecIntenciones = null
let pollTimer = null

const pollingActive = ref(false)
const eventos = ref([])
const nodoEstado = ref({})

// ── helper: limpia espacios en claves del CSV ──────────────
function cleanRow(row) {
  const out = {}
  Object.keys(row).forEach(k => { out[k.trim()] = typeof row[k] === 'string' ? row[k].trim() : row[k] })
  return out
}

const stats = computed(() => {
  const vals = Object.values(nodoEstado.value)
  const infectados = vals.filter(n => n.infected && !n.is_internet).length
  const aislados = vals.filter(n => n.isolated).length
  const sanos = vals.filter(n => !n.infected && !n.is_internet && !n.isolated).length
  const ultimo = eventos.value.length ? eventos.value[eventos.value.length - 1].ciclo : 0
  return { infectados, aislados, sanos, ciclo: ultimo }
})

const eventosRecientes = computed(() => [...eventos.value].reverse().slice(0, 50))

// ── INIT ──────────────────────────────────────────────────
onMounted(async () => {
  await initCytoscape()
  initCharts()
  startPolling()
})

onUnmounted(() => clearInterval(pollTimer))

// ── CYTOSCAPE ─────────────────────────────────────────────
async function initCytoscape() {

  const [nodosRaw, topoRaw] = await Promise.all([
    fetchCSV(`${BASE}/log_nodos.csv`),
    fetchCSV(`${BASE}/log_topologia.csv`),
  ])

  const nodos = nodosRaw.map(cleanRow)
  const topo = topoRaw.map(cleanRow)

  console.log('NODOS:', nodos)
  console.log('TOPO:', topo)

  nodos.forEach(n => {

    nodoEstado.value[n.nombre] = {

      tipo: n.tipo,

      // todos inician sanos
      infected: false,

      isolated: false,

      is_internet: n.tipo === 'internet',

    }

  })

  const elements = [
    ...nodos.map(n => ({
      data: { id: n.nombre, label: n.nombre, tipo: n.tipo },
    })),
    ...topo.map(t => ({
      data: { id: `${t.origen}-${t.destino}`, source: t.origen, target: t.destino },
    })),
  ]

  cy = cytoscape({
    container: cyContainer.value,
    elements,
    style: cyStyles(),
    layout: { name: 'breadthfirst', directed: false, padding: 40, spacingFactor: 1.5 },
    userZoomingEnabled: true,
    userPanningEnabled: true,
  })
}

function cyStyles() {
  return [
    {
      selector: 'node',
      style: {
        label: 'data(label)',
        'font-size': '11px',
        'font-family': 'monospace',
        color: '#e2e8f0',
        'text-valign': 'bottom',
        'text-margin-y': '6px',
        width: '38px',
        height: '38px',
        'background-color': '#22c55e',
        'border-width': '2px',
        'border-color': '#166534',
      },
    },
    { selector: 'node[tipo="internet"]', style: { 'background-color': '#facc15', 'border-color': '#854d0e' } },
    { selector: 'node[tipo="firewall"]', style: { 'background-color': '#3b82f6', 'border-color': '#1e3a8a', shape: 'rectangle' } },
    { selector: 'node[tipo="switch"]', style: { 'background-color': '#94a3b8', 'border-color': '#334155', shape: 'rectangle' } },
    { selector: 'node[tipo="server"]', style: { 'background-color': '#a855f7', 'border-color': '#581c87', shape: 'rectangle' } },
    { selector: 'node.infected', style: { 'background-color': '#ef4444', 'border-color': '#7f1d1d' } },
    { selector: 'node.isolated', style: { 'background-color': '#1e293b', 'border-color': '#94a3b8', 'border-width': '4px' } },
    {
      selector: 'edge',
      style: {
        width: 2,
        'line-color': '#f97316',
        'target-arrow-color': '#f97316',
        'target-arrow-shape': 'triangle',
        'curve-style': 'bezier',
        opacity: 0.7,
      },
    },
    {
      selector: 'edge.attack',

      style: {

        'line-color': '#ef4444',

        'target-arrow-color': '#ef4444',

        width: 5,

        opacity: 1,

        'line-style': 'solid'

      }

    }
  ]
}

function updateCyNode(nombre, infected, isolated) {

  if (!cy) return


  const node = cy.getElementById(nombre)


  if (!node || !node.length)
    return


  node.removeClass('infected isolated')


  if (isolated) {


    node.addClass('isolated')


  } else if (infected) {


    node.addClass('infected')


    // efecto de propagación
    node.animate(
      {
        style: {
          width: 55,
          height: 55
        }
      },
      {
        duration: 300,
        complete: function () {

          node.animate({
            style: {
              width: 38,
              height: 38
            }
          }, {
            duration: 300
          })

        }
      }
    )

  }

}

// ── ECHARTS ───────────────────────────────────────────────
function initCharts() {
  ecInfectados = echarts.init(chartInfectados.value, 'dark')
  ecPatch = echarts.init(chartPatch.value, 'dark')
  ecIntenciones = echarts.init(chartIntenciones.value, 'dark')

  const baseOpt = {
    backgroundColor: 'transparent',
    grid: { left: 44, right: 16, top: 16, bottom: 36 },
    xAxis: { type: 'category', data: [], axisLabel: { color: '#94a3b8', fontSize: 10 } },
    yAxis: { type: 'value', axisLabel: { color: '#94a3b8', fontSize: 10 }, splitLine: { lineStyle: { color: '#1e293b' } } },
    tooltip: { trigger: 'axis' },
  }

  ecInfectados.setOption({
    ...baseOpt,
    series: [{ name: 'Infectados', type: 'line', data: [], smooth: true, itemStyle: { color: '#ef4444' }, areaStyle: { color: 'rgba(239,68,68,0.15)' } }],
  })

  ecPatch.setOption({
    ...baseOpt,
    series: [{ name: 'Patch avg', type: 'line', data: [], smooth: true, itemStyle: { color: '#22c55e' }, areaStyle: { color: 'rgba(34,197,94,0.15)' } }],
  })

  ecIntenciones.setOption({
    backgroundColor: 'transparent',
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    legend: { data: ['spread', 'patch', 'isolate', 'normal'], textStyle: { color: '#94a3b8', fontSize: 10 }, top: 4 },
    grid: { left: 44, right: 16, top: 36, bottom: 36 },
    xAxis: { type: 'category', data: [], axisLabel: { color: '#94a3b8', fontSize: 10 } },
    yAxis: { type: 'value', axisLabel: { color: '#94a3b8', fontSize: 10 }, splitLine: { lineStyle: { color: '#1e293b' } } },
    series: [
      { name: 'spread', type: 'bar', stack: 'total', data: [], itemStyle: { color: '#ef4444' } },
      { name: 'patch', type: 'bar', stack: 'total', data: [], itemStyle: { color: '#22c55e' } },
      { name: 'isolate', type: 'bar', stack: 'total', data: [], itemStyle: { color: '#475569' } },
      { name: 'normal', type: 'bar', stack: 'total', data: [], itemStyle: { color: '#1e293b' } },
    ],
  })
}

// ── POLLING ───────────────────────────────────────────────
let lastRowCount = 0

function startPolling() {
  pollingActive.value = true
  pollTimer = setInterval(pollCSV, 2000)
  pollCSV()
}

async function pollCSV() {
  try {
    const rawRows = await fetchCSV(`${BASE}/log_eventos.csv`)
    const rows = rawRows.map(cleanRow)

    if (rows.length <= lastRowCount) return

    const nuevas = rows.slice(lastRowCount)
    lastRowCount = rows.length

    nuevas.forEach(procesarEvento)
    eventos.value = rows
    updateCharts(rows)
  } catch (e) {
    console.warn('Poll error', e)
  }
}

function procesarEvento(ev) {


  const nodo = ev.nodo
  const evento = ev.evento
  const desde = ev.desde



  if (!nodo || nodo === "-")
    return



  // =========================
  // INFECCION
  // =========================

  if (evento === "Infeccion_Exitosa") {


    if (nodoEstado.value[nodo]) {

      nodoEstado.value[nodo].infected = true

    }


    updateCyNode(
      nodo,
      true,
      false
    )



    // marcar camino de ataque

    if (desde && desde !== "-") {


      let edge =
        cy.getElementById(
          `${desde}-${nodo}`
        )



      // si la conexión está invertida

      if (!edge.length) {

        edge =
          cy.getElementById(
            `${nodo}-${desde}`
          )

      }



      if (edge.length) {

        edge.addClass("attack")


      }


    }


  }





  // =========================
  // AISLAMIENTO
  // =========================


  if (
    evento === "AISLADO_EMERGENCIA" ||
    evento === "AISLADO" ||
    evento === "Aislamiento_Contencion"
  ) {


    if (nodoEstado.value[nodo]) {


      nodoEstado.value[nodo].isolated = true

      nodoEstado.value[nodo].infected = true


    }



    updateCyNode(
      nodo,
      true,
      true
    )


  }


}

function updateCharts(rows) {
  // eje X: ciclos únicos ordenados
  const ciclosSet = [...new Set(rows.map(r => r.ciclo))].sort((a, b) => parseInt(a) - parseInt(b))

  // infectados: último valor de infectados_total por ciclo
  const infectSerie = ciclosSet.map(c => {
    const filasC = rows.filter(r => r.ciclo === c && r.infectados_total && r.infectados_total !== '-')
    if (!filasC.length) return null
    return parseInt(filasC[filasC.length - 1].infectados_total)
  })

  // patch avg: promedio de patch_lv en filas PARCHEO por ciclo
  const patchRows = rows.filter(r => r.evento === 'PARCHEO')
  const patchCiclos = [...new Set(patchRows.map(r => r.ciclo))].sort((a, b) => parseInt(a) - parseInt(b))
  const patchSerie = patchCiclos.map(c => {
    const vals = patchRows.filter(r => r.ciclo === c).map(r => parseInt(r.patch_lv)).filter(v => !isNaN(v))
    return vals.length ? Math.round(vals.reduce((a, b) => a + b, 0) / vals.length) : 0
  })

  // intenciones por ciclo
  const spreadSerie = ciclosSet.map(c => rows.filter(r => r.ciclo === c && r.intencion === 'spread').length)
  const patchISerie = ciclosSet.map(c => rows.filter(r => r.ciclo === c && r.intencion === 'patch').length)
  const isolateSerie = ciclosSet.map(c => rows.filter(r => r.ciclo === c && (r.intencion === 'isolated' || r.intencion === 'isolate')).length)
  const normalSerie = ciclosSet.map(c => rows.filter(r => r.ciclo === c && r.intencion === 'normal').length)

  ecInfectados.setOption({ xAxis: { data: ciclosSet }, series: [{ data: infectSerie }] })
  ecPatch.setOption({ xAxis: { data: patchCiclos }, series: [{ data: patchSerie }] })
  ecIntenciones.setOption({
    xAxis: { data: ciclosSet },
    series: [
      { data: spreadSerie },
      { data: patchISerie },
      { data: isolateSerie },
      { data: normalSerie },
    ],
  })
}

// ── CSV HELPER ────────────────────────────────────────────
function fetchCSV(path) {
  return new Promise((resolve, reject) => {
    Papa.parse(path, {
      download: true,
      header: true,
      skipEmptyLines: true,
      transformHeader: h => h.trim(),
      complete: r => resolve(r.data),
      error: reject,
    })
  })
}

function rowClass(evento) {
  if (evento === 'Infeccion_Exitosa') return 'row-infected'
  if (evento?.includes('AISLADO')) return 'row-isolated'
  if (evento === 'ALERTA_CRITICA') return 'row-alert'
  if (evento === 'PARCHEO') return 'row-patch'
  return ''
}

function badgeClass(evento) {
  if (evento === 'Infeccion_Exitosa') return 'badge-red'
  if (evento?.includes('AISLADO')) return 'badge-dark'
  if (evento === 'ALERTA_CRITICA') return 'badge-orange'
  if (evento === 'PARCHEO') return 'badge-green'
  return 'badge-gray'
}
</script>

<style scoped>
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600&family=Inter:wght@400;500;600&display=swap');

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

.dashboard {
  min-height: 100vh;
  background: #0a0f1e;
  color: #e2e8f0;
  font-family: 'Inter', sans-serif;
  display: flex;
  flex-direction: column;
}

.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 24px;
  background: #0d1526;
  border-bottom: 1px solid #1e293b;
}

.header-tag {
  font-family: 'JetBrains Mono', monospace;
  font-size: 10px;
  color: #f97316;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  display: block;
  margin-bottom: 2px;
}

.header-title {
  font-size: 18px;
  font-weight: 600;
  letter-spacing: -0.02em;
  color: #f1f5f9;
}

.header-stats {
  display: flex;
  align-items: center;
  gap: 24px;
}

.stat {
  text-align: center;
}

.stat-value {
  display: block;
  font-family: 'JetBrains Mono', monospace;
  font-size: 22px;
  font-weight: 600;
  color: #f1f5f9;
  line-height: 1;
}

.stat-label {
  display: block;
  font-size: 10px;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  margin-top: 2px;
}

.stat.danger .stat-value {
  color: #ef4444;
}

.stat.warn .stat-value {
  color: #f97316;
}

.pulse-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
}

.pulse-dot.active {
  background: #22c55e;
  box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.3);
  animation: pulse 1.5s infinite;
}

.pulse-dot.inactive {
  background: #334155;
}

@keyframes pulse {

  0%,
  100% {
    box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.3)
  }

  50% {
    box-shadow: 0 0 0 6px rgba(34, 197, 94, 0.1)
  }
}

.map-section {
  padding: 16px 24px 8px;
}

.section-label {
  font-family: 'JetBrains Mono', monospace;
  font-size: 10px;
  color: #475569;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  margin-bottom: 8px;
}

.cy-container {
  width: 100%;
  height: 300px;
  background: #0d1526;
  border: 1px solid #1e293b;
  border-radius: 8px;
}

.legend {
  display: flex;
  gap: 16px;
  margin-top: 8px;
  flex-wrap: wrap;
}

.leg-item {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11px;
  color: #64748b;
}

.dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  display: inline-block;
}

.dot.square {
  border-radius: 2px;
}

.charts-section {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr 1fr;
  gap: 12px;
  padding: 8px 24px 24px;
}

.chart-card {
  background: #0d1526;
  border: 1px solid #1e293b;
  border-radius: 8px;
  padding: 12px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.chart-label {
  font-family: 'JetBrains Mono', monospace;
  font-size: 10px;
  color: #475569;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.chart-box {
  height: 180px;
}

.events-card {
  overflow: hidden;
}

.events-table-wrap {
  height: 180px;
  overflow-y: auto;
  scrollbar-width: thin;
  scrollbar-color: #1e293b transparent;
}

.events-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 11px;
  font-family: 'JetBrains Mono', monospace;
}

.events-table th {
  position: sticky;
  top: 0;
  background: #0d1526;
  color: #475569;
  text-align: left;
  padding: 4px 6px;
  font-size: 10px;
  text-transform: uppercase;
  border-bottom: 1px solid #1e293b;
}

.events-table td {
  padding: 4px 6px;
  color: #94a3b8;
  border-bottom: 1px solid #0f172a;
}

.row-infected td {
  background: rgba(239, 68, 68, 0.07);
}

.row-isolated td {
  background: rgba(30, 41, 59, 0.5);
}

.row-alert td {
  background: rgba(249, 115, 22, 0.1);
}

.row-patch td {
  background: rgba(34, 197, 94, 0.06);
}

.badge {
  display: inline-block;
  padding: 1px 6px;
  border-radius: 3px;
  font-size: 9px;
  font-weight: 600;
  letter-spacing: 0.05em;
}

.badge-red {
  background: rgba(239, 68, 68, 0.2);
  color: #f87171;
}

.badge-dark {
  background: rgba(15, 23, 42, 0.8);
  color: #94a3b8;
}

.badge-orange {
  background: rgba(249, 115, 22, 0.2);
  color: #fb923c;
}

.badge-green {
  background: rgba(34, 197, 94, 0.2);
  color: #4ade80;
}

.badge-gray {
  background: rgba(51, 65, 85, 0.5);
  color: #64748b;
}
</style>