/*
 * Tape.ino - Streaming de cinta virtual (CVS1) al FPGA del MSXnano/MSXimus.
 * Modulo anadido al firmware UNAPI de ducasp (Arduino concatena los .ino).
 *
 * Cadena: .tsx (descargado o subido desde el MSX) -> tsx2cvs (conversor C++
 * verificado byte-exacto contra tsx2rom) -> UART1 -> FPGA pin 26 ->
 * tape_uart.v (FIFO 2KB) -> cas_stream.v (KCS) -> BIOS del MSX (RUN"CAS:").
 *
 * FLOW CONTROL: el FPGA saca RTR (pin 32, activo-alto = "sigue"). Baja al
 * llenarse el FIFO a 3/4 (1536/2047) -> quedan ~511 bytes de margen. Aqui
 * mandamos rafagas de <=64 bytes tras comprobar RTR; con el buffer TX del
 * ESP (~128B) el peor caso en vuelo es ~192 bytes < 511 -> IMPOSIBLE
 * desbordar si el cableado es correcto.
 *
 * PINES (defines): C6 -> TX1=GPIO20, RTR=GPIO23 (header de la C6-LCD-1.3;
 * NO usar 12/13 = USB-JTAG). S3 -> ajustar defines al montarlo.
 *
 * El disparo (PLAY) llegara de la fase de catalogo (comando UNAPI custom /
 * subida desde SD). Este modulo expone la API y no toca el parser de ducasp.
 */

#include "tsx2cvs.h"
#include <vector>

#ifndef TAPE_TX_PIN
#define TAPE_TX_PIN  20      // C6: GPIO20 -> FPGA pin 26 (datos CVS1)
#endif
#ifndef TAPE_RTR_PIN
#define TAPE_RTR_PIN 23      // C6: GPIO23 <- FPGA pin 32 (1 = enviar)
#endif
#define TAPE_BAUD    115200
#define TAPE_CHUNK   64      // rafaga maxima tras ver RTR alto

// ---------------------------------------------------------------------------
// MODELO DE CONCURRENCIA (C6 mono-nucleo, FreeRTOS con time-slicing)
// ---------------------------------------------------------------------------
// Hay dos contextos que tocan este estado: (A) la tarea de enlace UNAPI, que
// corre en loop() y llama a tapePlay/tapeStop; (B) tapeFeedTask, una tarea
// aparte (prioridad 1) que bombea el stream. Ambas a prioridad 1 -> el tick
// puede intercalarlas en cualquier punto.
//
// Regla de oro para evitar carreras / locks colgados / use-after-free:
//   - NUNCA se mata la tarea desde fuera (vTaskDelete de OTRA tarea deja
//     tomado el mutex del UART si la matamos dentro de Serial1.write/flush, y
//     el siguiente uso del UART se cuelga para siempre). En su lugar se pide
//     parada COOPERATIVA (g_tapeStopReq) y la tarea sale ELLA MISMA en un punto
//     donde no posee ningun lock.
//   - La tarea es la UNICA duena de su ciclo de vida: libera el buffer y se
//     autodestruye con vTaskDelete(nullptr). NO escribe g_tapeTask (asi no
//     puede pisar el handle de una tarea nueva) y pone g_tapeBusy=false EL
//     ULTIMO (mientras siga true, tapePlay rechaza reentradas y nadie mas toca
//     g_tapeStream).
//   - tapeStop() pide la parada y ESPERA a que g_tapeBusy baje (join), sin
//     tocar el buffer: lo libera la propia tarea.
// Con esto g_tapeStream solo lo toca UN contexto a la vez (handoff por el flag
// busy), sin necesidad de mutex.
// ---------------------------------------------------------------------------
static std::vector<uint8_t> g_tapeStream;    // stream CVS1 en RAM
static volatile size_t      g_tapePos     = 0;
static volatile bool        g_tapeBusy    = false;  // true de tapePlay a teardown
static volatile bool        g_tapeStopReq = false;  // peticion de parada cooperativa
static TaskHandle_t         g_tapeTask    = nullptr; // lo escribe SOLO tapePlay/Stop

// ---- estado para la pantalla (Display.ino puede consultarlos) ----
bool   tapeBusy()     { return g_tapeBusy; }
size_t tapeTotal()    { return g_tapeStream.size(); }
size_t tapeSent()     { return g_tapePos; }

static void tapeFeedTask(void*)
{
    // Sale al terminar el stream O cuando tapeStop() pide parada. La condicion
    // se comprueba en los limites del bucle (nunca con un lock del UART tomado).
    while (g_tapePos < g_tapeStream.size() && !g_tapeStopReq) {
        if (digitalRead(TAPE_RTR_PIN)) {
            size_t n = g_tapeStream.size() - g_tapePos;
            if (n > TAPE_CHUNK) n = TAPE_CHUNK;
            Serial1.write(g_tapeStream.data() + g_tapePos, n);
            Serial1.flush();               // esperar a que salga (no acumular
            g_tapePos += n;                // en vuelo mas alla del chunk)
        } else {
            vTaskDelay(pdMS_TO_TICKS(5));  // FPGA lleno: la cinta consume a
        }                                  // ~110B/s, sobra con re-mirar cada 5ms
    }
    // Teardown (aqui NO se posee ningun lock): liberar el buffer y avisar. El
    // orden importa: busy=false debe ser lo ULTIMO antes de autodestruirse, y
    // NO tocamos g_tapeTask (podria apuntar ya a una tarea nueva).
    g_tapeStream.clear();
    g_tapeStream.shrink_to_fit();
    g_tapePos  = 0;
    g_tapeBusy = false;
    vTaskDelete(nullptr);                  // vTaskDelete(NULL) = "esta tarea"
}

// Inicializar UART1 + RTR. Llamar una vez desde setup() (tras displaySetup()).
void tapeSetup()
{
    pinMode(TAPE_RTR_PIN, INPUT_PULLDOWN);   // sin cable -> 0 -> no envia
    Serial1.begin(TAPE_BAUD, SERIAL_8N1, -1 /*rx: no usado*/, TAPE_TX_PIN);
}

// Reproducir un .tsx/.cas que YA esta en memoria: convierte a CVS1 y arranca
// la tarea de streaming. Devuelve nullptr si OK o el mensaje de error.
const char* tapePlay(const uint8_t* tapefile, size_t len)
{
    if (g_tapeBusy) return "ya hay una cinta reproduciendose";
    const char* err = tsx2cvs(tapefile, len, g_tapeStream);
    if (err) { g_tapeStream.clear(); return err; }
    g_tapePos     = 0;
    g_tapeStopReq = false;               // limpiar una peticion de parada rancia
    g_tapeBusy    = true;
    // prioridad baja: el enlace UNAPI (loop) manda; la cinta tiene 18s de buffer
    if (xTaskCreate(tapeFeedTask, "tapefeed", 3072, nullptr, 1, &g_tapeTask) != pdPASS) {
        g_tapeBusy = false;
        g_tapeStream.clear();
        return "sin memoria para la tarea de cinta";
    }
    return nullptr;
}

// Cancelar la reproduccion (p.ej. el usuario vuelve al menu). Parada COOPERATIVA:
// pide a la tarea que salga y espera a que lo confirme (join por g_tapeBusy). No
// libera el buffer aqui: lo hace la propia tarea en su teardown.
void tapeStop()
{
    if (!g_tapeBusy) return;             // nada corriendo
    g_tapeStopReq = true;
    // esperar a que la tarea salga sola. Peor caso ~= una rafaga (flush de 64B
    // a 115200 ~5.5ms) antes de que compruebe el flag en el limite del bucle.
    while (g_tapeBusy) vTaskDelay(pdMS_TO_TICKS(2));
    g_tapeStopReq = false;
    g_tapeTask    = nullptr;             // la tarea ya se autodestruyo (join hecho)
}
