<template>
  <div id="app" class="container-fluid p-4 bg-light min-vh-100">
    <header class="mb-4 p-3 bg-dark text-white rounded shadow-sm d-flex justify-content-between align-items-center">
      <div>
        <h1 class="h3 mb-0">🛡️ Dashboard de Ciberseguridad e Infección de Redes</h1>
        <p class="text-muted small mb-0">Monitoreo de agentes inteligentes y análisis de escenarios GAMA</p>
      </div>
      <div class="d-flex gap-3 align-items-center">
        <div v-if="listaSimulaciones.length > 0" class="text-end">
          <label class="form-label text-white small mb-1 d-block">Seleccionar Simulación/Escenario:</label>
          <select v-model="simulacionSeleccionada" class="form-select form-select-sm bg-secondary text-white border-0">
            <option v-for="sim in listaSimulaciones" :key="sim" :value="sim">
              Simulación #{{ sim }}
            </option>
          </select>
        </div>
        <button class="btn btn-primary btn-sm" @click="procesarDatos">🔄 Recargar Logs</button>
      </div>
    </header>

    <div class="row mb-4">
      <div class="col-12">
        <div class="card shadow-sm p-3">
          <h5 class="card-title h6 text-secondary">Cargar archivos de Log de GAMA (.csv)</h5>
          <div class="row g-2">
            <div class="col-md-6">
              <label class="small text-muted">Log General:</label>
              <input type="file" @change="cargarLogGeneral" class="form-control form-control-sm" accept=".csv" />
            </div>
            <div class="col-md-6">
              <label class="small text-muted">Log de Eventos:</label>
              <input type="file" @change="cargarLogEventos" class="form-control form-control-sm" accept=".csv" />
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="row g-3 mb-4">
      <div class="col-md-3">
        <div class="card border-start border-danger border-4 shadow-sm p-3 bg-white">
          <div class="text-muted small text-uppercase font-weight-bold">Total Infectados (Máx)</div>
          <div class="h3 font-weight-bold text-danger my-1">{{ kpis.maxInfectados }}</div>
          <div class="text-muted small">En la simulación seleccionada</div>
        </div>
      </div>
      <div class="col-md-3">
        <div class="card border-start border-success border-4 shadow-sm p-3 bg-white">
          <div class="text-muted small text-uppercase font-weight-bold">Nodos Estables (Final)</div>
          <div class="h3 font-weight-bold text-success my-1">{{ kpis.finalSanos }}</div>
          <div class="text-muted small">Equipos libres de malware</div>
        </div>
      </div>
      <div class="col-md-3">
        <div class="card border-start border-primary border-4 shadow-sm p-3 bg-white">
          <div class="text-muted small text-uppercase font-weight-bold">Eficiencia Firewall</div>
          <div class="h3 font-weight-bold text-primary my-1">{{ (kpis.firewall * 100).toFixed(0) }}%</div>
          <div class="text-muted small">Fuerza de mitigación asignada</div>
        </div>
      </div>
      <div class="col-md-3">
        <div class="card border-start border-warning border-4 shadow-sm p-3 bg-white">
          <div class="text-muted small text-uppercase font-weight-bold">Total Eventos Críticos</div>
          <div class="h3 font-weight-bold text-warning my-1">{{ filtradosEventos.length }}</div>
          <div class="text-muted small">Infecciones registradas pasadas</div>
        </div>
      </div>
    </div>

    <div class="row g-4 mb-4">
      <div class="col-md-8">
        <div class="card shadow-sm p-3 bg-white h-100">
          <h5 class="card-title h6 border-bottom pb-2">📈 Curva de Infección Temporal</h5>
          <div class="chart-container" style="position: relative; height:300px;">
            <canvas id="canvasLineal"></canvas>
          </div>
        </div>
      </div>
      <div class="col-md-4">
        <div class="card shadow-sm p-3 bg-white h-100">
          <h5 class="card-title h6 border-bottom pb-2">📊 Estado Final de la Red</h5>
          <div class="chart-container" style="position: relative; height:300px;">
            <canvas id="canvasPastel"></canvas>
          </div>
        </div>
      </div>
    </div>

    <div class="row mb-5">
      <div class="col-12">
        <div class="card shadow-sm">
          <div class="card-header bg-dark text-white d-flex justify-content-between align-items-center">
            <h5 class="mb-0 h6">📄 Informe Final Ejecutivo Automatizado</h5>
            <button class="btn btn-success btn-sm" @click="mostrarInforme = !mostrarInforme">
              {{ mostrarInforme ? 'Ocultar Informe' : 'Generar e Imprimir Informe' }}
            </button>
          </div>
          <div v-if="mostrarInforme" class="card-body bg-white p-4 animate__animated animate__fadeIn">
            <div id="seccion-informe-imprimible">
              <div class="text-center mb-4 border-bottom pb-3">
                <h4>REPORTE DE SIMULACIÓN DE PROPAGACIÓN DE MALWARE</h4>
                <p class="text-muted mb-0">Análisis del Escenario de Simulación #{{ simulacionSeleccionada }}</p>
                <small class="text-muted">Generado automáticamente por el Sistema Colaborativo de Redes</small>
              </div>

              <h5>1. Resumen Ejecutivo</h5>
              <p>
                Durante el análisis del escenario actual con una fuerza de protección perimetral (Firewall) configurada al 
                <strong>{{ (kpis.firewall * 100).toFixed(1) }}%</strong>, se observó que la red alcanzó un pico máximo de 
                <strong>{{ kpis.maxInfectados }}</strong> dispositivos comprometidos simultáneamente. Al concluir el ciclo temporal de la simulación, 
                permanecieron un total de <strong>{{ kpis.finalSanos }}</strong> dispositivos sanos y aislados.
              </p>

              <h5 class="mt-4">2. Historial Analítico de Eventos Registrados</h5>
              <div class="table-responsive">
                <table class="table table-striped table-sm text-center align-middle small">
                  <thead class="table-dark">
                    <tr>
                      <th>Ciclo GAMA</th>
                      <th>Nombre de Agente Computador</th>
                      <th>Acción / Incidente</th>
                      <th>Estado Crítico</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(ev, index) in filtradosEventos" :key="index">
                      <td>{{ ev.ciclo }}</td>
                      <td><code>{{ ev.nodo }}</code></td>
                      <td>{{ ev.evento }}</td>
                      <td><span class="badge bg-danger">Comprometedora</span></td>
                    </tr>
                    <tr v-if="filtradosEventos.length === 0">
                      <td colspan="4" class="text-muted py-3">No hay registros de infecciones aisladas para esta simulación.</td>
                    </tr>
                  </tbody>
                </table>
              </div>

              <h5 class="mt-4">3. Conclusiones Tecnológicas y Recomendaciones</h5>
              <ul>
                <li>A mayor tasa de probabilidad de infección base, los tiempos de mitigación del Firewall deben ajustarse reduciendo el <code>cooldown</code> de respuesta de parches.</li>
                <li>Los nodos periféricos conectados directamente al nodo externo (Internet) requieren una tasa de inmunización perimetral un 25% más elevada que la media global de la arquitectura GIS cargada.</li>
              </ul>
            </div>
            <div class="text-end mt-3 d-print-none">
              <button class="btn btn-outline-dark btn-sm" @click="imprimirInforme">🖨️ Descargar PDF / Imprimir</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Chart from 'chart.js/auto';

export default {
  name: 'App',
  data() {
    return {
      datosRawGeneral: [],
      datosRawEventos: [],
      listaSimulaciones: [],
      simulacionSeleccionada: null,
      mostrarInforme: false,
      instanciaGraficoLinea: null,
      instanciaGraficoPastel: null,
      kpis: {
        maxInfectados: 0,
        finalSanos: 0,
        firewall: 0
      }
    };
  },
  computed: {
    // Filtrar los datos en tiempo real según la simulación elegida en el combobox
    filtradosGeneral() {
      if (!this.simulacionSeleccionada) return [];
      return this.datosRawGeneral.filter(d => d.id_simulacion === this.simulacionSeleccionada);
    },
    filtradosEventos() {
      if (!this.simulacionSeleccionada) return [];
      return this.datosRawEventos.filter(d => d.id_simulacion === this.simulacionSeleccionada);
    }
  },
  watch: {
    simulacionSeleccionada() {
      this.recalcularDashboard();
    }
  },
  mounted() {
    this.procesarDatos();
  },
  methods: {
    async procesarDatos() {
      // Intentar cargar por defecto si están servidos localmente en la carpeta pública
      try {
        const resGen = await fetch('/log_general.csv');
        const txtGen = await resGen.text();
        this.parsearCSVGeneral(txtGen);

        const resEv = await fetch('/log_eventos.csv');
        const txtEv = await resEv.text();
        this.parsearCSVEventos(txtEv);
      } catch (e) {
        console.warn("No se pudieron autofetchear los archivos CSV de la raíz, usa el cargador manual en pantalla.", e);
      }
    },
    cargarLogGeneral(e) {
      const file = e.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = (evt) => this.parsearCSVGeneral(evt.target.result);
      reader.readAsText(file);
    },
    cargarLogEventos(e) {
      const file = e.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = (evt) => this.parsearCSVEventos(evt.target.result);
      reader.readAsText(file);
    },
    parsearCSVGeneral(texto) {
      const lineas = texto.split('\n').map(l => l.trim()).filter(l => l.length > 0);
      if (lineas.length <= 1) return;

      const datos = [];
      const simSet = new Set();

      // Saltarse encabezado
      for (let i = 1; i < lineas.length; i++) {
        const columnas = lineas[i].split(',');
        if (columnas.length < 5) continue;

        const idSim = parseInt(columnas[0]);
        simSet.add(idSim);

        datos.push({
          id_simulacion: idSim,
          escenario: columnas[1],
          ciclo: parseInt(columnas[2]),
          infectados: parseInt(columnas[3]),
          sanos: parseInt(columnas[4]),
          firewall: parseFloat(columnas[5] || 0)
        });
      }

      this.datosRawGeneral = datos;
      this.listaSimulaciones = Array.from(simSet).sort((a,b) => a - b);
      
      if (this.listaSimulaciones.length > 0 && !this.simulacionSeleccionada) {
        this.simulacionSeleccionada = this.listaSimulaciones[0];
      } else {
        this.recalcularDashboard();
      }
    },
    parsearCSVEventos(texto) {
      const lineas = texto.split('\n').map(l => l.trim()).filter(l => l.length > 0);
      if (lineas.length <= 1) return;

      const datos = [];
      for (let i = 1; i < lineas.length; i++) {
        const columnas = lineas[i].split(',');
        if (columnas.length < 5) continue;

        datos.push({
          id_simulacion: parseInt(columnas[0]),
          escenario: columnas[1],
          ciclo: parseInt(columnas[2]),
          nodo: columnas[3],
          evento: columnas[4]
        });
      }
      this.datosRawEventos = datos;
    },
    recalcularDashboard() {
      const gen = this.filtradosGeneral;
      if (gen.length === 0) return;

      // Calcular KPIs básicos
      this.kpis.maxInfectados = Math.max(...gen.map(d => d.infectados), 0);
      const ultimoDato = gen[gen.length - 1];
      this.kpis.finalSanos = ultimoDato ? ultimoDato.sanos : 0;
      this.kpis.firewall = ultimoDato ? ultimoDato.firewall : 0;

      this.$nextTick(() => {
        this.renderizarGraficoLineal(gen);
        this.renderizarGraficoPastel(ultimoDato);
      });
    },
    renderizarGraficoLineal(datosFiltrados) {
      const ctx = document.getElementById('canvasLineal')?.getContext('2d');
      if (!ctx) return;

      if (this.instanciaGraficoLinea) this.instanciaGraficoLinea.destroy();

      const ciclos = datosFiltrados.map(d => `Ciclo ${d.ciclo}`);
      const infectados = datosFiltrados.map(d => d.infectados);
      const sanos = datosFiltrados.map(d => d.sanos);

      this.instanciaGraficoLinea = new Chart(ctx, {
        type: 'line',
        data: {
          labels: ciclos,
          datasets: [
            { label: 'Infectados 🔴', data: infectados, borderColor: '#dc3545', backgroundColor: 'rgba(220,53,69,0.1)', tension: 0.2, fill: true },
            { label: 'Sanos 🟢', data: sanos, borderColor: '#198754', backgroundColor: 'rgba(25,135,84,0.1)', tension: 0.2, fill: true }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { position: 'top' } },
          scales: { y: { beginAtZero: true } }
        }
      });
    },
    renderizarGraficoPastel(ultimoDato) {
      const ctx = document.getElementById('canvasPastel')?.getContext('2d');
      if (!ctx) return;

      if (this.instanciaGraficoPastel) this.instanciaGraficoPastel.destroy();

      const inf = ultimoDato ? ultimoDato.infectados : 0;
      const san = ultimoDato ? ultimoDato.sanos : 0;

      this.instanciaGraficoPastel = new Chart(ctx, {
        type: 'pie',
        data: {
          labels: ['Infectados Total', 'Sanos Total'],
          datasets: [{
            data: [inf, san],
            backgroundColor: ['#dc3545', '#198754'],
            hoverOffset: 4
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { position: 'bottom' } }
        }
      });
    },
    imprimirInforme() {
      window.print();
    }
  }
};
</script>

<style scoped>
.chart-container {
  width: 100%;
}
@media print {
  .d-print-none {
    display: none !important;
  }
}
</style>