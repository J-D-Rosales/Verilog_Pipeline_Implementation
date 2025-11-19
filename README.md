*Pipeline Processor* en Verilog 2001. Este README incluirá las siguientes secciones:

1. **Descripción del Proyecto**: Una breve explicación del objetivo del pipeline y su funcionalidad.
2. **Estructura del Proyecto**: Descripción de los módulos principales que componen el pipeline.
3. **Requisitos**: Herramientas necesarias para compilar y simular el proyecto.
4. **Instalación**: Cómo configurar el entorno para ejecutar el proyecto.
5. **Uso**: Cómo ejecutar y probar el pipeline, incluyendo ejemplos de testbenches.
6. **Contribuciones**: Cómo puedes contribuir al proyecto.

Aquí te dejo un ejemplo de cómo se podría estructurar este README:

---

# Pipeline Processor en Verilog 2001

Este proyecto implementa un pipeline de procesamiento en Verilog 2001, utilizado en la simulación y diseño de un procesador simple con múltiples etapas. El objetivo es demostrar el funcionamiento de un pipeline típico con las etapas de IF (Instruction Fetch), ID (Instruction Decode), EX (Execute), MEM (Memory), y WB (Write Back), junto con mecanismos de control de hazards y forwarding.

## Descripción

El diseño incluye varios módulos de Verilog, como:

* **Datapath**: Maneja la ejecución de las instrucciones.
* **Controller**: Controla las señales de control y la operación del pipeline.
* **Hazard Unit**: Gestiona los riesgos de datos en el pipeline (forwarding y stalling).
* **Testbenches**: Archivos para realizar pruebas unitarias y verificar el correcto funcionamiento del pipeline.

## Estructura del Proyecto

El proyecto está compuesto por los siguientes módulos:

### 1. **Datapath (`datapath.v`)**

Este módulo define las señales y operaciones principales del datapath del procesador, como el ALU, los registros y la memoria. Gestiona las operaciones de lectura y escritura de datos y las señales de control de las etapas del pipeline.

#### Entradas:

* `clk`, `reset`
* Señales de control como `RegWrite`, `ALUSrc`, `PCSrc`, etc.

#### Salidas:

* `PCF` (Program Counter)
* `ZeroE`
* `WriteData`, `DataAdr`, `MemWrite`

### 2. **Controlador (`controller.v`)**

El controlador genera señales de control basadas en las instrucciones que se están ejecutando en el pipeline. Determina el comportamiento de las unidades del procesador, como la ALU, la memoria y los registros.

### 3. **Unidad de Riesgo (`hazard_unit.v`)**

Este módulo maneja los riesgos de datos en el pipeline. Utiliza *forwarding* para resolver dependencias de datos y *stalls* para evitar que datos incorrectos sean procesados.

### 4. **Testbench (`testbench.v`, `tb_sanity.v`)**

Se incluyen testbenches para verificar el funcionamiento del pipeline. El archivo `testbench.v` instancia el procesador y genera los estímulos necesarios para probar el datapath, mientras que `tb_sanity.v` se enfoca en realizar pruebas de sanidad del sistema.

### 5. **Otros Módulos de Soporte**

* **`t_debug.v`**: Módulo para depurar el comportamiento del sistema.
* **`pipeline.v`**: Módulo que conecta las distintas unidades del pipeline, como la memoria, la ALU y las señales de control.

## Requisitos

* **Verilog 2001** compatible con tu simulador.
* Herramienta de simulación como **Vivado** o **ModelSim** para ejecutar los archivos de prueba.

## Instalación

Para ejecutar el proyecto en tu entorno, sigue estos pasos:

1. Clona el repositorio del proyecto.
2. Asegúrate de tener instalado un simulador compatible con Verilog 2001.
3. Agrega los archivos de Verilog a tu proyecto de simulación.
4. Configura el entorno de simulación según sea necesario.

## Uso

1. **Compilación y Simulación**: Para simular el diseño, utiliza las herramientas de simulación como Vivado o ModelSim. Asegúrate de que todos los archivos estén correctamente incluidos en tu proyecto.

2. **Ejecuta los Testbenches**: Para verificar que el pipeline funciona correctamente, ejecuta los archivos de testbench (`testbench.v` y `tb_sanity.v`). Estos proporcionan estímulos para las distintas etapas del pipeline y validan su comportamiento.

   ```bash
   # Para Vivado:
   vivado -mode batch -source run_simulation.tcl

   # Para ModelSim:
   vsim work.testbench
   run -all
   ```

## Contribuciones

Si deseas contribuir al proyecto, por favor sigue estos pasos:

1. Haz un fork del repositorio.
2. Crea una nueva rama (`git checkout -b feature/nueva-caracteristica`).
3. Realiza tus cambios y haz un commit.
4. Envía un Pull Request.

---
ncionalidades o módulos si lo consideras necesario. ¿Te gustaría añadir algo más o hacer alguna modificación?
