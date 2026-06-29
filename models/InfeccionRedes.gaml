model InfeccionRedesGIS

species sala {
    string nombre;
    aspect default {
        draw shape color: #transparent border: #black;
    }
}

global {
    file nodos_file <- file("../includes/nodos.shp");
    file conexiones_file <- file("../includes/conexiones.shp");
    file salas_file <- file("../includes/sala.shp");
    geometry shape <- envelope(salas_file);
    
    // Parámetros configurables por escenario
    float firewall_strength <- 0.7;
    int cooldown_min <- 3;
    int cooldown_max <- 8;
    float prob_infeccion_base <- 0.6;
    
    // Control de múltiples simulaciones (Batch / Escenarios)
    int id_simulacion <- 1;
    string nombre_escenario <- "Predeterminado";

    init {
        // Cargar capas GIS
        create sala from: salas_file {
            nombre <- string(read("nombre"));
        }

        create computer from: nodos_file {
            id <- int(read("id")); 
            nombre <- string(read("nombre"));
            string tipoNodo <- string(read("tipo"));

            geometry geom <- location;
            location <- geom;
            is_server <- (tipoNodo = "server");
            is_internet <- (tipoNodo = "internet");
            is_firewall <- (tipoNodo = "firewall");
            is_switch <- (tipoNodo = "switch");
            infected <- is_internet; // El nodo internet empieza infectado
            secured <- false;
            isolated <- false;
            patch_level <- rnd(100);
            
            if tipoNodo = "pc" or is_server {
                open_ports <- [445, 3389, 80];
            } else {
                open_ports <- [];
            }
        }

        create connection from: conexiones_file {
            int o <- int(read("origen"));
            int d <- int(read("destino"));

            list<computer> so <- computer where each.id = o;
            list<computer> de <- computer where each.id = d;

            if !empty(so) and !empty(de) {
                source <- first(so);
                target <- first(de);
                geom <- geometry;
            }
        }
        
        // Determinar dinámicamente el ID de simulación para no sobreescribir datos históricos
        if (file_exists("../includes/log_general.csv")) {
            file f <- csv_file("../includes/log_general.csv", ",");
            matrix m <- matrix(f);
            if (m != nil and length(m) > 0 and rows_idx(m) > 1) {
                // Leer la última fila, primera columna (donde guardaremos el id_simulacion)
                id_simulacion <- int(m[0, rows_idx(m) - 1]) + 1;
            }
        }
        
        // Escribir encabezados ÚNICAMENTE si el archivo es nuevo o está vacío
        if (!file_exists("../includes/log_general.csv") or length(matrix(csv_file("../includes/log_general.csv", ","))) = 0) {
            save ["id_simulacion", "escenario", "ciclo", "infectados", "sanos", "firewall_strength", "prob_infeccion"] 
            to: "../includes/log_general.csv" format: "csv" rewrite: true;
        }
        if (!file_exists("../includes/log_eventos.csv") or length(matrix(csv_file("../includes/log_eventos.csv", ","))) = 0) {
            save ["id_simulacion", "escenario", "ciclo", "nodo", "evento"] 
            to: "../includes/log_eventos.csv" format: "csv" rewrite: true;
        }
    }

    // Guardado de logs periódicos paso a paso (Acumulativo: rewrite es FALSE)
    reflex guardar_log_general when: (cycle % 5 = 0) {
        int total_inf <- length(computer where each.infected);
        int total_san <- length(computer where !each.infected);
        
        save [id_simulacion, nombre_escenario, cycle, total_inf, total_san, firewall_strength, prob_infeccion_base] 
        to: "../includes/log_general.csv" format: "csv" rewrite: false;
    }
}

species computer {
    int id;
    string nombre;
    bool is_server <- false;
    bool is_internet <- false;
    bool is_firewall <- false;
    bool is_switch <- false;
    bool infected <- false;
    bool secured <- false;
    bool isolated <- false;
    list<int> open_ports <- [];
    int patch_level <- 0;
    int cooldown <- 0;

    reflex activity {
        if cooldown > 0 {
            cooldown <- cooldown - 1;
        }
    }

    reflex spread when: infected and !isolated {
        if cooldown > 0 { return; }

        list<connection> outs <- connection where each.source = self;
        if empty(outs) { return; }

        connection c <- one_of(outs);
        computer target_node <- c.target;
        
        if (target_node != nil and !target_node.infected and !target_node.isolated) {
            float p <- prob_infeccion_base;
            
            // Si pasa por un firewall, la fuerza del firewall mitiga la infección
            if (is_firewall) {
                p <- p * (1.0 - firewall_strength);
            }
            if (445 in target_node.open_ports) {
                p <- p * (1.0 - target_node.patch_level / 150.0);
            }

            if flip(p) {
                target_node.infected <- true;
                // Log de evento crítico acumulativo
                save [id_simulacion, nombre_escenario, cycle, target_node.nombre, "Infeccion"] 
                to: "../includes/log_eventos.csv" format: "csv" rewrite: false;
            }
        }
        cooldown <- rnd(5) + 2;
    }

    aspect default {
        if is_firewall { draw square(15) color: #blue; }
        else if is_switch { draw square(12) color: #gray; }
        else if is_internet { draw bubble(18) color: #yellow; }
        else if infected { draw circle(10) color: #red; }
        else { draw circle(10) color: #green; }
    }
}

species connection {
    computer source;
    computer target;
    geometry geom;

    aspect default {
        if geom != nil { draw shape color: #red width: 2; }
        else if source != nil and target != nil {
            draw line([source.location, target.location]) color: #orange width: 1.5;
        }
    }
}

// -----------------------------------------------------
// EXPERIMENTO 1: GUI (Para ver una sola simulación en vivo)
// -----------------------------------------------------
experiment LAN type: gui {
    output {
        display network_display {
            species sala;
            species connection;
            species computer;
        }
        monitor "Total Infectados" value: length(computer where each.infected);
    }
}

// -----------------------------------------------------
// EXPERIMENTO 2: BATCH (Para simular los Escenarios Predefinidos en cadena)
// -----------------------------------------------------
experiment EscenariosPredefinidos type: batch repeat: 3 until: (cycle >= 150) {
    // Definimos las variaciones automáticas de parámetros por escenario
    parameter "Fuerza del Firewall" var: firewall_strength among: [0.2, 0.5, 0.9];
    parameter "Probabilidad de Infección" var: prob_infeccion_base among: [0.4, 0.7];
    
    // Un método reflex dentro del batch para cambiar etiquetas antes de cada corrida
    method explore;
}