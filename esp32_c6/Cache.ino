// ============================================================================
//  Cache.ino — descarga a CACHÉ en la FFat del propio C6, y servida a trozos
//              al MSX cuando ÉL la pide.
//
//  POR QUÉ EXISTE
//  ---------------------------------------------------------------------------
//  Hasta ahora el File-Hunter bajaba en FLUJO: el servidor empuja, el ESP
//  reenvía y el MSX tiene que seguir ese ritmo. Pero el MSX se para a escribir
//  cada sector en su SD y a buscar cluster libre en la FAT, y en esas pausas
//  algo se rompe: descargas que mueren a los 64 KB, a los 192, de forma
//  VARIABLE (medido en placa el 31/08/2026 — la variabilidad es justo lo que
//  descarta un fallo de lógica y señala un problema de ritmos).
//
//  Aquí se invierte quién manda:
//
//    ANTES:  servidor -> ESP -> MSX     (el MSX es esclavo del ritmo ajeno)
//    AHORA:  servidor -> ESP -> FFat    fase 1, el MSX ni participa
//            FFat -> MSX                fase 2, el MSX PIDE cuando puede
//
//  En la fase 2 no hay nada que desbordar ni que expire: si el MSX tarda dos
//  segundos en asignar un cluster, el ESP simplemente espera la siguiente
//  petición. Eso no mueve el problema de sitio: elimina la clase de problema.
//
//  POR QUÉ FFat Y NO LA microSD DEL C6
//  ---------------------------------------------------------------------------
//  La partición ffat ya existe, ya está montada y ya se usa (certificados,
//  known_hosts). Son 1,19 MB — de sobra para el catálogo salvo las ROMs de
//  2 MB. Usarla no añade driver, ni cableado, ni una tarjeta más que se pueda
//  desmontar. Si algún día hacen falta los 2 MB, app0 tiene ~1 MB sin usar que
//  se le puede pasar en partitions.csv.
//
//  CLIENTE HTTP PROPIO
//  ---------------------------------------------------------------------------
//  Deliberadamente NO se reutiliza el `http`/`client` estáticos del fichero
//  principal: los usa TCPIP_HTTP_OPEN/RECEIVE y compartirlos haría que una
//  descarga en curso y una petición del MSX se pisaran. La API del File-Hunter
//  va por HTTP plano en el puerto 80, así que basta un WiFiClient normal.
// ============================================================================

#define CACHE_PATH      "/fhcache.bin"
#define CACHE_SLICE     4096      // bytes por pasada de cacheTask(): acotado para
                                  // no secuestrar el loop() (la pantalla y el
                                  // enlace del MSX tienen que seguir vivos)
#define CACHE_MAX_READ  1024      // tope por peticion del MSX (MAX_CMD_DATA_LEN
                                  // son 2148, pero el MSX lee de 512 en 512)
#define CACHE_UA        "MSXnano/1.9"   // identidad del proyecto (ver cacheStart)
#define CACHE_SELFTEST  0              // auto-test al arrancar (build temporal)
void cacheSelfTest(void);              // implementado al final de este fichero

enum CacheState {
  CACHE_IDLE = 0,   // sin nada
  CACHE_DL   = 1,   // bajando
  CACHE_DONE = 2,   // completa y verificada
  CACHE_ERR  = 3    // falló (el motivo, en g_cErr)
};

static uint8_t     g_cState = CACHE_IDLE;
static uint32_t    g_cGot   = 0;    // bytes ya escritos en FFat
static uint32_t    g_cTotal = 0;    // Content-Length (0 = desconocido)
static uint8_t     g_cErr   = 0;    // código UNAPI del fallo
static int         g_cCode  = 0;    // ultimo codigo HTTP, para diagnosticar
static File        g_cFile;
static HTTPClient  g_cHttp;
static WiFiClient  g_cClient;
static WiFiClient *g_cStream = NULL;

// ---- cierra el lado de red, deje o no la caché utilizable --------------------
static void cacheCloseNet(void) {
  if (g_cStream) g_cStream = NULL;
  g_cHttp.end();
  if (g_cFile) g_cFile.close();
}

// ---- borra la caché y vuelve a reposo --------------------------------------
void cacheFree(void) {
  cacheCloseNet();
  if (FFat.exists(CACHE_PATH)) FFat.remove(CACHE_PATH);
  g_cState = CACHE_IDLE;
  g_cGot = g_cTotal = 0;
  g_cErr = 0;
}

// ---- arranca una descarga a caché ------------------------------------------
// Devuelve enseguida: lo que tarde lo va bombeando cacheTask() desde el loop().
// Así el MSX puede preguntar el estado mientras tanto, que es todo el objetivo.
byte cacheStart(const char *url) {
  cacheFree();                       // una caché a la vez; la anterior se tira

  WaitConnectionIfNeeded(false);
  if (WiFi.status() != WL_CONNECTED) return UNAPI_ERR_NO_NETWORK;

  if (!g_cHttp.begin(g_cClient, url)) return UNAPI_ERR_NO_CONN;

  // IDENTIDAD: el mismo User-Agent que manda el MSX en fh1_req2. No es un
  // adorno: api.file-hunter.com mira el UA y al "ESP32HTTPClient" por defecto
  // le contesta 307 -> https://www.file-hunter.com/read.me (medido 31/08/2026).
  // Ademas ese redirect es a HTTPS, que este cliente en claro no puede seguir.
  // Con el UA del proyecto responde 200 directo: la peticion es la MISMA que
  // hacia el Z80, solo que ahora la lanza el ESP.
  g_cHttp.setUserAgent(CACHE_UA);
  g_cHttp.setConnectTimeout(10000);
  g_cHttp.setTimeout(15000);
  g_cHttp.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);

  int code = g_cHttp.GET();
  g_cCode = code;                    // se guarda para poder DIAGNOSTICAR: un
                                     // "error 3" a secas no dice si fue el
                                     // servidor, la red o el fichero.
  if (code != HTTP_CODE_OK) { g_cHttp.end(); return UNAPI_ERR_NO_DATA; }

  int len = g_cHttp.getSize();       // -1 si viene en chunks
  g_cTotal = (len > 0) ? (uint32_t)len : 0;

  // Comprobar que cabe ANTES de empezar: mejor un "no" limpio ahora que un
  // fichero a medias y una FFat llena a la mitad de la descarga.
  if (g_cTotal && g_cTotal > FFat.freeBytes()) {
    g_cHttp.end();
    return UNAPI_ERR_BUFFER;
  }

  g_cFile = FFat.open(CACHE_PATH, FILE_WRITE);
  if (!g_cFile) { g_cHttp.end(); return UNAPI_ERR_BUFFER; }

  g_cStream = g_cHttp.getStreamPtr();
  g_cGot    = 0;
  g_cErr    = 0;
  g_cState  = CACHE_DL;
  return UNAPI_ERR_OK;
}

// ---- arranca la descarga de un item del File-Hunter -------------------------
// El MSX manda solo {tipo, indice, texto buscado} y la URL la monta AQUI. Asi el
// Z80 se ahorra construir la peticion HTTP entera, que es justo lo que hay que
// recortar: al menu con File-Hunter le quedan 11 bytes hasta SD_BUF.
byte cacheStartFH(uint8_t tipo, uint8_t idx, const char *query) {
  String u = "http://api.file-hunter.com/MSXnano.php?base=1BA0&type=";
  u += (tipo == 2) ? "dsk" : "rom";
  u += "&msx=&char=";
  for (const char *p = query; *p; ++p) u += (*p == ' ') ? '+' : *p;   // como .f2_q
  u += "&download=";
  u += idx;
  return cacheStart(u.c_str());
}

// ---- bombea la descarga; se llama desde loop() -----------------------------
void cacheTask(void) {
#if CACHE_SELFTEST
  cacheSelfTest();
#endif
  if (g_cState != CACHE_DL) return;

  if (WiFi.status() != WL_CONNECTED) {
    g_cErr = UNAPI_ERR_NO_NETWORK; g_cState = CACHE_ERR; cacheCloseNet(); return;
  }

  static uint8_t buf[512];
  uint32_t moved = 0;

  while (moved < CACHE_SLICE) {
    int avail = g_cStream ? g_cStream->available() : 0;
    if (avail <= 0) break;                       // nada listo: volvemos en la
                                                 // siguiente vuelta del loop
    int n = g_cStream->readBytes(buf, (avail > (int)sizeof(buf)) ? sizeof(buf) : avail);
    if (n <= 0) break;
    if (g_cFile.write(buf, n) != (size_t)n) {    // FFat llena o error de flash
      g_cErr = UNAPI_ERR_BUFFER; g_cState = CACHE_ERR; cacheCloseNet(); return;
    }
    g_cGot += n;
    moved  += n;
  }

  // ¿terminado? Dos criterios: llegar al Content-Length, o que se cierre la
  // conexión sin datos pendientes. Con Content-Length conocido se EXIGE
  // llegar a él: una conexión cortada a medias es un error, no un final.
  bool sinDatos = (!g_cStream) || (g_cStream->available() == 0);
  bool cerrada  = (!g_cHttp.connected());

  if (g_cTotal && g_cGot >= g_cTotal) {
    g_cFile.flush(); cacheCloseNet(); g_cState = CACHE_DONE;
  } else if (cerrada && sinDatos) {
    if (g_cTotal == 0 && g_cGot > 0) {           // sin Content-Length: el cierre
      g_cTotal = g_cGot;                         // limpio ES el final
      g_cFile.flush(); cacheCloseNet(); g_cState = CACHE_DONE;
    } else {
      g_cErr = UNAPI_ERR_NO_DATA;                // cortada antes de tiempo
      g_cState = CACHE_ERR; cacheCloseNet();
    }
  }
}

// ---- estado para el MSX: 9 bytes -------------------------------------------
//   [0]   estado (0 reposo / 1 bajando / 2 lista / 3 error)
//   [1]   codigo de error (solo si estado==3)
//   [2-5] bytes ya bajados   (LSB primero, como todo lo demas del protocolo)
//   [6-9] tamano total       (0 = aun desconocido)
byte cacheStat(byte *out, unsigned int *outLen) {
  out[0] = g_cState;
  out[1] = g_cErr;
  out[2] = (byte)(g_cGot        & 0xFF);
  out[3] = (byte)((g_cGot >> 8) & 0xFF);
  out[4] = (byte)((g_cGot >> 16)& 0xFF);
  out[5] = (byte)((g_cGot >> 24)& 0xFF);
  out[6] = (byte)(g_cTotal        & 0xFF);
  out[7] = (byte)((g_cTotal >> 8) & 0xFF);
  out[8] = (byte)((g_cTotal >> 16)& 0xFF);
  out[9] = (byte)((g_cTotal >> 24)& 0xFF);
  *outLen = 10;
  return UNAPI_ERR_OK;
}

// ---- sirve un trozo de la caché --------------------------------------------
// El MSX manda offset(4) + longitud(2) y recibe exactamente eso. Es una lectura
// por POSICIÓN, no un flujo: puede pedir el mismo trozo dos veces, o volver
// atrás si una escritura en su SD le salió mal, sin re-descargar nada.
byte cacheRead(uint32_t off, uint16_t len, byte *out, unsigned int *outLen) {
  *outLen = 0;
  if (g_cState != CACHE_DONE) return UNAPI_ERR_NO_DATA;
  if (len == 0 || len > CACHE_MAX_READ) return UNAPI_ERR_INV_PARAM;
  if (off >= g_cTotal) return UNAPI_ERR_NO_DATA;

  if (off + len > g_cTotal) len = (uint16_t)(g_cTotal - off);   // cola del fichero

  File f = FFat.open(CACHE_PATH, FILE_READ);
  if (!f) return UNAPI_ERR_NO_DATA;
  if (!f.seek(off)) { f.close(); return UNAPI_ERR_NO_DATA; }
  int n = f.read(out, len);
  f.close();
  if (n <= 0) return UNAPI_ERR_NO_DATA;

  *outLen = (unsigned int)n;
  return UNAPI_ERR_OK;
}

// ============================================================================
//  AUTO-TEST — build temporal, se apaga poniendo CACHE_SELFTEST a 0
// ---------------------------------------------------------------------------
//  Responde la unica pregunta pendiente: ¿sabe el ESP bajarse un fichero
//  entero a su ritmo, sin que nadie le marque el paso? Se baja solo al
//  arrancar y pinta el avance en la pantallita.
//
//  Se hace AQUI y no desde el MSX porque en el MSX no cabe: al menu con
//  File-Hunter le quedan 11 bytes hasta SD_BUF, y la rutina de prueba pedia
//  330. Esto no gasta ni un byte del Z80.
//
//  El fichero (128 KB, Content-Length conocido) es del mismo servidor y del
//  mismo tamano que las descargas que fallaban, asi que el test es del caso
//  real y no de un caso de laboratorio.
// ============================================================================
#define CACHE_TEST_URL  "http://api.file-hunter.com/MSXnano.php" \
                        "?base=1BA0&type=rom&msx=&char=nemesis&download=0"
#define CACHE_TEST_HOLD 120000UL   // ms que el resultado se queda en pantalla

#if CACHE_SELFTEST
static uint8_t  g_stPhase = 0;     // 0=esperando WiFi 1=bajando 2=OK 3=error
static uint32_t g_stT0 = 0, g_stMs = 0, g_stDone = 0, g_stReady = 0;

void cacheSelfTest(void) {
  if (g_stPhase >= 2) return;

  if (g_stPhase == 0) {
    if (WiFi.status() != WL_CONNECTED) { g_stReady = 0; return; }
    if (!g_stReady) { g_stReady = millis(); return; }   // dar aire tras asociarse
    if (millis() - g_stReady < 4000) return;
    g_stT0 = millis();
    byte r = cacheStart(CACHE_TEST_URL);
    if (r != UNAPI_ERR_OK) { g_cErr = r; g_stMs = 0; g_stDone = millis(); g_stPhase = 3; }
    else                     g_stPhase = 1;
    return;
  }

  if (g_cState == CACHE_DONE) { g_stMs = millis()-g_stT0; g_stDone = millis(); g_stPhase = 2; }
  else if (g_cState == CACHE_ERR) { g_stMs = millis()-g_stT0; g_stDone = millis(); g_stPhase = 3; }
}

// ¿debe la pantalla cederme la banda? (mientras corre, y un rato tras acabar)
bool cacheTestActive(void) {
  if (g_stPhase < 2) return true;
  return (millis() - g_stDone) < CACHE_TEST_HOLD;
}

// una linea de <=20 caracteres (240 px a tamano 2)
void cacheTestStatus(char *out, unsigned int n) {
  unsigned long got = g_cGot >> 10, tot = g_cTotal >> 10;
  unsigned long s = g_stMs / 1000, d = (g_stMs % 1000) / 100;
  switch (g_stPhase) {
    case 0:  snprintf(out, n, "CACHE: esperando"); break;
    case 1:  snprintf(out, n, "CACHE %luK/%luK", got, tot); break;
    case 2:  snprintf(out, n, "OK %luK %lu.%lus", tot, s, d); break;
    default:
      if (got == 0 && g_cCode != 200) snprintf(out, n, "ERR HTTP %d", g_cCode);
      else                            snprintf(out, n, "ERR %u a %luK", (unsigned)g_cErr, got);
      break;
  }
}
#endif
