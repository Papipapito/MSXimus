/*
 * Display.ino - Pantalla de estado (WiFi + Sistema + Turbo) para MSXimus/MSXnano en la
 * Waveshare ESP32-C6-LCD-1.3 (ST7789V2 240x240 SPI). Modulo AÑADIDO al firmware
 * UNAPI de ducasp. Arduino concatena los .ino: llamar displaySetup() en setup()
 * y displayTask() en loop() del .ino principal.
 *
 * Libreria: "GFX Library for Arduino" (moononournation) -> Arduino_GFX.
 * PINES LCD: SCLK=7 MOSI=6 CS=14 DC=15 RST=21 BL=22 (no tocan UART 16/17).
 *
 * TURBO: lee un GPIO que el FPGA pone a 1 en modo turbo (pin del FPGA -> TURBO_PIN).
 *        Mientras no este cableado, INPUT_PULLDOWN lo lee 0 -> muestra "Normal".
 */

#include <Arduino_GFX_Library.h>
#include <WiFi.h>
#include <time.h>
#include "UNAPIESP.h"     // ESPConfig, FIRMWARETYPE (guarda de inclusion)

#define LCD_SCK   7
#define LCD_MOSI  6
#define LCD_CS    14
#define LCD_DC    15
#define LCD_RST   21
#define LCD_BL    22

// Titulo del LCD. NEUTRO a proposito ("MSX" a secas, decision Albert 27/07):
// este firmware es COMUN al MSXimus y al MSXnano — la version del core no es
// cosa del ESP. Quien quiera personalizarlo: cambiar este define.
#define DEVICE_NAME    "MSX"
#define TURBO_PIN 3       // GPIO libre del C6 (header) cableado al pin de turbo del FPGA

// Colores RGB565
#define COL_BLACK    0x0000
#define COL_WHITE    0xFFFF
#define COL_RED      0xF800
#define COL_GREEN    0x07E0
#define COL_CYAN     0x07FF
#define COL_YELLOW   0xFFE0
#define COL_ORANGE   0xFD20
#define COL_DGREEN   0x03E0
#define COL_DGREY    0x2104
#define COL_DARKGREY 0x7BEF

// Globales del firmware de ducasp (definidas en el .ino principal)
extern const char chVer[4];
extern bool bSNTPOK;
extern ESPConfig stDeviceConfiguration;      // .iGMT = offset horario en HORAS (lo setea el menu WiFi)
extern volatile uint32_t g_lastUartMs;       // ultima actividad del enlace MSX<->ESP

static Arduino_DataBus *lcd_bus = new Arduino_HWSPI(LCD_DC, LCD_CS, LCD_SCK, LCD_MOSI);
static Arduino_GFX *gfx = new Arduino_ST7789(lcd_bus, LCD_RST, 0, true, 240, 240, 0, 0, 0, 0);
static bool lcd_ok = false;

static void fmtUptime(char *buf, uint32_t ms)
{
    uint32_t s = ms / 1000;
    sprintf(buf, "%02lu:%02lu:%02lu", (unsigned long)(s / 3600),
            (unsigned long)((s % 3600) / 60), (unsigned long)(s % 60));
}

void displaySetup()
{
    pinMode(LCD_BL, OUTPUT);
    digitalWrite(LCD_BL, HIGH);
    pinMode(TURBO_PIN, INPUT_PULLDOWN);      // 0 si no esta cableado -> "Normal"

    if (!gfx->begin()) { lcd_ok = false; return; }
    lcd_ok = true;

    gfx->fillScreen(COL_BLACK);
    gfx->setTextColor(COL_CYAN);
    gfx->setTextSize(2);
    gfx->setCursor(6, 6);
    gfx->print(DEVICE_NAME);
    gfx->drawFastHLine(0, 28, 240, COL_DARKGREY);
    gfx->drawFastHLine(0, 108, 240, COL_DARKGREY);
    gfx->drawFastHLine(0, 152, 240, COL_DARKGREY);
}

void displayTask()
{
    if (!lcd_ok) return;
    uint32_t now = millis();

    // Arranca SNTP en cuanto hay WiFi, para que el reloj de la pantalla salga sin
    // depender de que el MSX pida la hora (bSNTPOK solo se activa via peticion del MSX).
    static bool s_wasConn = false;
    bool s_conn = (WiFi.status() == WL_CONNECTED);
    if (s_conn && !s_wasConn) configTime(0, 0, "pool.ntp.org");
    s_wasConn = s_conn;

    // ---------- Indicador de actividad MSX<->ESP (punto arriba-dcha) ----------
    static uint32_t t_act = 0;
    static int8_t   act_last = -1;
    if (now - t_act >= 150) {
        t_act = now;
        int8_t act = (now - g_lastUartMs < 250) ? 1 : 0;   // trafico UART reciente
        if (act != act_last) {
            act_last = act;
            gfx->fillCircle(228, 13, 6, act ? COL_GREEN : COL_DGREY);
            gfx->drawCircle(228, 13, 6, COL_DARKGREY);
        }
    }

    // ---------- Bloque WiFi (size 2), repinta SOLO si cambia ----------
    static uint32_t t_wifi = 0;
    if (now - t_wifi >= 1000) {
        t_wifi = now;
        static int8_t last_conn = -1;
        static String last_ssid = "\x01";
        static long   last_rssi = 0x7fffffff;

        bool   conn = (WiFi.status() == WL_CONNECTED);
        String ssid = conn ? WiFi.SSID() : String("");
        long   rssi = conn ? WiFi.RSSI() : 0;

        if (!((int8_t)conn == last_conn && ssid == last_ssid && rssi == last_rssi)) {
            last_conn = conn; last_ssid = ssid; last_rssi = rssi;
            gfx->fillRect(0, 32, 240, 74, COL_BLACK);      // zona WiFi (y32..106)
            gfx->setTextSize(2);
            if (conn) {
                gfx->setTextColor(COL_GREEN); gfx->setCursor(6, 34); gfx->println("Conectado");
                gfx->setTextColor(COL_WHITE);
                gfx->setCursor(6, 58); gfx->print("SSID:"); gfx->println(ssid);
                gfx->setCursor(6, 82); gfx->print("RSSI:"); gfx->print(rssi); gfx->println("dBm");
            } else {
                gfx->setTextColor(COL_RED);    gfx->setCursor(6, 34); gfx->println("Sin WiFi");
                gfx->setTextColor(COL_DARKGREY); gfx->setCursor(6, 70); gfx->println("Pulsa W en el menu");
            }
        }
    }

    // ---------- Barra TURBO, repinta solo si cambia ----------
    static uint32_t t_turbo = 0;
    static int8_t   last_turbo = -1;
    if (now - t_turbo >= 400) {
        t_turbo = now;
        int8_t turbo = digitalRead(TURBO_PIN) ? 1 : 0;
        if (turbo != last_turbo) {
            last_turbo = turbo;
            if (turbo) {
                gfx->fillRect(6, 114, 228, 32, COL_ORANGE);
                gfx->setTextColor(COL_BLACK);
                gfx->setTextSize(2); gfx->setCursor(16, 122); gfx->print("TURBO 5.37MHz");
            } else {
                gfx->fillRect(6, 114, 228, 32, COL_DGREY);
                gfx->setTextColor(COL_DGREEN);
                gfx->setTextSize(2); gfx->setCursor(16, 122); gfx->print("Normal 3.58MHz");
            }
        }
    }

    // ---------- Barra inferior (size 2): Uptime, Temp, Hora -- llena la zona bajo el turbo, cada 3s ----------
    static uint32_t t_sys = 0;
    if (now - t_sys >= 3000) {
        t_sys = now;
        char up[12]; fmtUptime(up, now);
        float temp = temperatureRead();

        gfx->fillRect(0, 156, 240, 84, COL_BLACK);   // zona bajo la barra de turbo (y156..240)
        gfx->setTextSize(2);                          // el doble de grande; 3 lineas repartidas
        gfx->setTextColor(COL_WHITE);
        gfx->setCursor(6, 160); gfx->print("Uptime "); gfx->println(up);
        gfx->setCursor(6, 190); gfx->print("Temp ");   gfx->print(temp, 0); gfx->println(" C");
        // Reloj: hora REAL del sistema (SNTP en background al conectar WiFi), sin depender de bSNTPOK.
        gfx->setCursor(6, 220);
        {
            time_t tnow = time(nullptr);
            if (tnow > 1700000000) {   // epoch > 2023-11 => SNTP ya sincronizo, hora valida
                time_t t = tnow + (time_t)stDeviceConfiguration.iGMT * 3600;   // hora LOCAL via iGMT
                struct tm tmv; gmtime_r(&t, &tmv);
                char hs[16]; strftime(hs, sizeof(hs), "%H:%M  %d/%m/%y", &tmv);   // size2: hora + fecha corta
                gfx->print(hs);
            } else {
                gfx->setTextColor(COL_DARKGREY);
                gfx->print((WiFi.status() == WL_CONNECTED) ? "Sincronizando" : "Sin WiFi");
            }
        }
    }
}
