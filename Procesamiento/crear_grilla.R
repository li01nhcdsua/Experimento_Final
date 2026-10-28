require("data.table")

# 1. ANALIZAR EL BUCKET PARA DETERMINAR EL PUNTO DE ARRANQUE INCREMENTAL
path_bucket <- "/content/buckets/b1/exp"
prefijo_busqueda <- "z635_WorkFlow_01_senior_NHC_B"

# Listamos las carpetas existentes en el bucket que cumplan con la nomenclatura
carpetas_existentes <- list.dirs(path_bucket, full.names = FALSE, recursive = FALSE)
carpetas_filtradas <- carpetas_existentes[grepl(paste0("^WF", prefijo_busqueda, "[0-9]+$"), carpetas_existentes)]

if (length(carpetas_filtradas) > 0) {
  # Extraemos la parte numérica (los últimos dígitos del nombre de la carpeta)
  numeros <- as.numeric(gsub(paste0("^WF", prefijo_busqueda), "", carpetas_filtradas))
  proximo_id <- max(numeros, na.rm = TRUE) + 1
} else {
  # Si el bucket está vacío o es la primera corrida con este formato, arrancamos en 1
  proximo_id <- 1
}

cat("=== Sistema de Incremento Dinámico ===\n")
cat("Próximo ID numérico disponible para asignar:", proximo_id, "\n\n")

# 2. DEFINIR LA GRILLA DE EXPERIMENTOS (Combinación Exponencial Completa)

# Se usaron las semillas ( 100057, 100069, 200003 )
#grilla <- data.frame(
#  arbolitos = c( 20, 20, 40 ),  # Exploramos más volumen de bosque
#  hojas     = c( 16, 16, 20 ),  # Exploramos más profundidad de ramas
#  min_datos = c( 100, 100, 150 ),  # Mantenemos el freno de regularización exitoso
#  mtry      = c( 0.2, 0.2, 0.6 )   # Mantenemos la alta visibilidad de variables
#)

# Se usaron las semillas ( 100049, 100049, 100049 )
grilla <- data.frame(
  arbolitos = c( 24, 40, 40 ),  # Exploramos más volumen de bosque
  hojas     = c( 20, 28, 20 ),  # Exploramos más profundidad de ramas
  min_datos = c( 150, 200, 150 ),  # Mantenemos el freno de regularización exitoso
  mtry      = c( 0.6, 0.6, 0.45 )   # Mantenemos la alta visibilidad de variables
)

# 3. LEER EL ARCHIVO BASE (Asegurate que tu script exportado se llame 'script_base.R')
if(!file.exists("script_base.R")) {
  stop("ERROR Crítico: No se encuentra el archivo 'script_base.R' en el directorio actual.")
}
lineas_base <- readLines("script_base.R")

# Inicializamos el vector para almacenar las líneas de ejecución de la Parte 2
lineas_orquestador <- c("#!/bin/bash", "")

# 4. ITERACIÓN Y GENERACIÓN EN CASCADA
for(i in 1:nrow(grilla)) {
  
  # Asignamos las variables de la fila actual de la grilla
  v_arb  <- grilla$arbolitos[i]
  v_hoj  <- grilla$hojas[i]
  v_dat  <- grilla$min_datos[i]
  v_mtr  <- grilla$mtry[i]
  
  # Construimos la nomenclatura exacta incremental solicitada (ej. z635_WorkFlow_01_senior_NHC001)
  id_incremental <- sprintf("%s%03d", prefijo_busqueda, proximo_id)
  
  # Clonamos la plantilla base para alterar sus parámetros internos
  lineas_nuevas <- lineas_base
  
  # Modificación Quirúrgica de Parámetros en el Script R mediante RegEx
  lineas_nuevas <- gsub('PARAM\\$experimento <- .*', paste0('PARAM$experimento <- "', id_incremental, '"'), lineas_nuevas)
  lineas_nuevas <- gsub('PARAM\\$FE_rf\\$arbolitos= .*', paste0('PARAM$FE_rf$arbolitos= ', v_arb), lineas_nuevas)
  lineas_nuevas <- gsub('PARAM\\$FE_rf\\$hojas_por_arbol= .*', paste0('PARAM$FE_rf$hojas_por_arbol= ', v_hoj), lineas_nuevas)
  lineas_nuevas <- gsub('PARAM\\$FE_rf\\$datos_por_hoja= .*', paste0('PARAM$FE_rf$datos_por_hoja= ', v_dat), lineas_nuevas)
  lineas_nuevas <- gsub('PARAM\\$FE_rf\\$mtry_ratio= .*', paste0('PARAM$FE_rf$mtry_ratio= ', v_mtr), lineas_nuevas)
  
  # Escribimos físicamente el archivo .R individual aislado
  nombre_archivo_salida <- paste0("run_", id_incremental, ".R")
  writeLines(lineas_nuevas, nombre_archivo_salida)
  
  # Agregamos la orden de ejecución al orquestador externo de Bash
  lineas_orquestador <- c(lineas_orquestador, paste0("Rscript ", nombre_archivo_salida))
  
  cat("Fabricado con éxito:", nombre_archivo_salida, 
      " -> [Arboles:", v_arb, "| Hojas:", v_hoj, "| MinData:", v_dat, "| Mtry:", v_mtr, "]\n")
  
  # Avanzamos el contador numérico para el siguiente experimento de la lista
  proximo_id <- proximo_id + 1
}

# 5. GUARDAR EL ARCHIVO ORQUESTADOR AUTOMÁTICAMENTE
writeLines(lineas_orquestador, "run_experimentos.sh")
cat("\n[OK] ¡Orquestador 'run_experimentos.sh' generado con todas las combinaciones exponenciales!\n")
