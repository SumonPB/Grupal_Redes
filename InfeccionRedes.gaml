model InfeccionRedesGIS

species sala {
	string nombre;
}

global {
	file nodos_file <- file("../includes/nodos.shp");
	file conexiones_file <- file("../includes/conexiones.shp");
	file salas_file <- file("../includes/sala.shp");
	geometry shape <- envelope(salas_file);
	float firewall_strength <- 0.7;
	int cooldown_min <- 3;
	int cooldown_max <- 8;

	init {

	// =========================
	// SALAS
	// =========================
		create sala from: salas_file {
			nombre <- string(read("nombre"));
		}

		// =========================
		// NODOS (FIX CRÍTICO)
		// =========================
		create computer from: nodos_file {
			id <- int(read("id")); // store numeric id as int
			nombre <- string(read("nombre"));
			string tipoNodo <- string(read("tipo"));

			// assign agent location from the shapefile geometry
			geometry geom <- location;
			location <- geom;
			is_server <- (tipoNodo = "server");
			is_internet <- (tipoNodo = "internet");
			is_firewall <- (tipoNodo = "firewall");
			is_switch <- (tipoNodo = "switch");
			infected <- false;
			secured <- false;
			isolated <- false;
			patch_level <- rnd(100);
			if tipoNodo = "pc" or is_server {
				open_ports <- [445, 3389, 80];
			} else {
				open_ports <- [];
			}

			write "NODE LOADED RAW ID: " + string(id);
			write "NODE LOC: " + string(location);
		}
		// =========================
		// CONEXIONES (FIX DEFINITIVO)
		// =========================
create connection from: conexiones_file {

	int o <- int(read("origen"));
	int d <- int(read("destino"));

	list<computer> so <- computer where each.id = o;
	list<computer> de <- computer where each.id = d;

	if !empty(so) and !empty(de) {

		source <- first(so);
		target <- first(de);
		// store the raw geometry from the shapefile into the agent
		geom <- geometry;

		write "LINK OK: " + string(o) + " -> " + string(d);
		if source != nil {
			if target != nil {
				write "  SRC LOC: " + string(source.location) + " | TGT LOC: " + string(target.location);
			} else {
				write "  SRC LOC: " + string(source.location) + " | TGT LOC: nil";
			}
		} else {
			write "  SRC LOC: nil | TGT LOC: " + (target != nil ? string(target.location) : "nil");
		}
	}
	else {

		write "CONEXION INVALIDA: " + string(o) + " -> " + string(d);
	}
}
		write "Nodos: " + length(computer);
		write "Links: " + length(connection);
	}

}

// =====================================================
// COMPUTADORAS
// =====================================================
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

	reflex spread when: infected {
		if cooldown > 0 {
			return;
		}

		list<connection> outs <- connection where each.source = self;
		if empty(outs) {
			return;
		}

		connection c <- one_of(outs);
		computer target_node <- c.target;
		float p <- 0.6;
		if 445 in target_node.open_ports {
			p <- p * (1.0 - patch_level / 150.0);
		}

		if flip(p) {
			target_node.infected <- true;
			write "INFECTADO: " + target_node.nombre;
		}

		cooldown <- rnd(5) + 2;
	}

	aspect default {
		if is_firewall {
			draw square(5000) color: #blue;
		} else if is_switch {
			draw square(5000) color: #gray;
		} else if is_internet {
			draw square(5000) color: #yellow;
		} else if infected {
			draw circle(5000) color: #red;
		} else {
			draw circle(5000) color: #green;
		}

		draw string(nombre) at: location + {0, 5};
	} }

	// =====================================================
// CONEXIONES
// =====================================================
species connection {
	computer source;
	computer target;
	geometry geom;

	aspect default {
		// Draw connections more visibly for debugging: prefer stored geometry
		if geom != nil {
			draw line(geom) color: #red width: 3;
		} else if source != nil and target != nil {
			draw line([source.location, target.location]) color: #red width: 3;
		}
	}

}

// =====================================================
// EXPERIMENTO
// =====================================================
experiment LAN type: gui {
	output {
		display network_display {
			species connection;
			species computer;
		}

		monitor "INF" value: length(computer where each.infected);
	}

}