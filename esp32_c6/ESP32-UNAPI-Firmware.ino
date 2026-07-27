/*
ESP32-UNAPI-Firmware.ino
    ESP32 UNAPI Implementation.
    Revision 1.0

Requires Arduino IDE and ESP32 libraries

Copyright (c) 2019 - 2026 Oduvaldo Pavan Junior ( ducasp@ gmail.com )
Copyright (c) 2026 - Leo Manes ( https://github.com/leomanes )
All rights reserved.

HTTP functionality
Copyright (c) 2025 Jeroen Taverne
All rights reserved.

If you integrate this on your hardware, please consider the 
possibility of sending one piece of it as a thank you to the author :)
Of course this is not mandatory, if you like the idea, contact the
author in the e-mail address above.

This file, that is part of ESP32 UNAPI Firmware program, is free
software: you can redistribute it and/or modify it under the terms
of the GNU Lesser General Public License as published by the Free
Software Foundation, either version 2.1 of the License, or (at your
option) any later version.

This file is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this file.  If not, see <https://www.gnu.org/licenses/>

v0.1
    - Initial ESP32 support, no HTTPS, no firmware update

v0.2 (Merging with Leo Manes ESP32 Port)
    - HTTPS with TLS 1.2 by Leo Manes (WiFiClientSecure / mbedTLS)
    - Changed LittleFS to FFat (APP:I set to 3MB / OTA:above 1.5MB for now)
    - Added missing WiFiClientSecure include
    - Fixed Update.begin() parameters (U_SPIFFS instead of U_FS)
    - Fixed IPAddress comparisons
    - Added online led (blue using the onboard WS2812)

v0.3
    - Added SSH client support via libssh-esp32 library
    - New functions: TCPIP_SSH_OPEN, TCPIP_SSH_CLOSE, TCPIP_SSH_STATE,
      TCPIP_SSH_SEND, TCPIP_SSH_RCV, TCPIP_SSH_TERM_TYPE, TCPIP_SSH_WIN_SIZE
    - Secondary capabilities bit 10 set (SSH client)
*/
#include "UNAPIESP.h"
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <Update.h>
#include <HTTPClient.h>
#include <HTTPUpdate.h>
#include "libssh_esp32.h"
#include <libssh/libssh.h>
#include <FFat.h>
#include <Ticker.h>
#include <time.h>
#include <EEPROM.h>
#include "HTTPClient.h"
#include "mbedtls/md.h"
#include <base64.h>
#include <esp_wifi.h>
#include <lwip/sockets.h>

#define HTTP_PACKET_SIZE 2048
SET_LOOP_TASK_STACK_SIZE(65536); // 64KB stack — best balance for DRAM vs headroom
WiFiClientSecure *TClient1;
static char *g_caPem = NULL;
static size_t g_caPemLen = 0;
static uint8_t *g_caBundle = NULL;
static size_t g_caBundleLen = 0;
unsigned char bTLSInUse = 0;
unsigned char uchTLSHost[256];
bool bHasHostName = false;

const char chVer[4] = "1.0";
byte btConnections[4] = {CONN_CLOSED,CONN_CLOSED,CONN_CLOSED,CONN_CLOSED};
bool btSSHFilter[4] = {false,false,false,false};
//UDP Objects
WiFiUDP Udp1, Udp2, Udp3, Udp4;
//TCP Connection Objects
WiFiClient * ClientList[4] = {NULL, NULL, NULL, NULL};
//Passive TCP Connection Objects
WiFiServer * ServerList[4] = {NULL, NULL, NULL, NULL};
byte btUDPConnections[4] = {CONN_CLOSED,CONN_CLOSED,CONN_CLOSED,CONN_CLOSED};
byte btIsTransient[4] = {0,0,0,0};
unsigned int uiLocalPorts[4] = {0,0,0,0};
unsigned int uiRemotePorts[4] = {0,0,0,0};
unsigned int uiListenPorts[4] = {0,0,0,0};
static byte btIPConnection1[4] = {0,0,0,0};
static byte btIPConnection2[4] = {0,0,0,0};
static byte btIPConnection3[4] = {0,0,0,0};
static byte btIPConnection4[4] = {0,0,0,0};
IPAddress externalIP,DNSQueryIP;
bool bIPAutomatic = true;
bool bDNSAutomatic = true;
bool bSerialUpdateInProgress = false;
// True when RS232 update is a CERT update (Y/z/E flow)
// rather than a firmware update (Z/z/E flow). The cert path streams bytes
// to a file on FFat instead of using Update.begin/write/end, because the
// ESP8266 reference's certs.bin is a LittleFS partition image which is
// neither format-compatible with our FFat partition nor with mbedTLS.
bool bSerialCertUpdateInProgress = false;
File g_certUploadFile;
unsigned char ucReceivedCommand = NO_COMMAND;
unsigned char ucLastCmd, ucLastResponse;
unsigned int uiLastDataSize;
unsigned char *ucLastData;
ESPConfig stDeviceConfiguration;
volatile uint32_t g_lastUartMs = 0;   // ultima actividad UART MSX<->ESP (para el indicador de Display.ino)
static byte btState = RX_PARSER_IDLE;
byte btReadyRetries;
byte btReceivedCommand;
bool bWiFiOn = false;
Ticker tickerRadioOff;
// Set from Ticker (esp_timer task) context; consumed in loop() to keep WiFi
// stack calls on the Arduino main task.
volatile bool bDisableRadioPending = false;
unsigned long longTimeOut;
unsigned long longReadyTimeOut;
struct tm timeinfo;
bool bSNTPOK = false;
bool bHoldConnection = false;
time_t now;
bool bSkipStateCheck = false;
// HTTP globals
static bool http_connected = false;
static HTTPClient http;
static WiFiClient client;
static WiFiClient *stream = NULL;
static unsigned int http_chunk_size = 0;
static unsigned int http_chunk_header_idx = 0;
static unsigned long longTimeOut2;
uint8_t buffer[1024];
static bool bRS232UpdateAllowed = false;
static byte shaResult[32];
static bool bShaOk = false;
static bool bHTTPTransfer = false;

// SSH globals
static ssh_session sshSessions[4] = {NULL, NULL, NULL, NULL};
static ssh_channel sshChannels[4] = {NULL, NULL, NULL, NULL};
static uint8_t sshTermType = TERM_VT52;
static uint8_t sshWinRow = 24;
static uint8_t sshWinCol = 40;

// SSH keyboard-interactive authentication state
static bool    sshKbdIntActive[4]         = {false, false, false, false};
static byte    sshSubsystems[4]           = {0, 0, 0, 0};
#define SSH_CHALLENGE_BUF_SIZE 512
static byte    sshChallengeData[4][SSH_CHALLENGE_BUF_SIZE];
static unsigned int sshChallengeDataLen[4] = {0, 0, 0, 0};
static byte    sshChallengePrompts[4]      = {0, 0, 0, 0};
static byte    sshChallengeEchoFlags[4]    = {0, 0, 0, 0};

// SSH host key verification state (per-slot)
static uint8_t   sshPendingHash[4][SSH_KNOWN_HOST_HASH_SIZE];
static bool      sshPendingHashValid[4]    = {false, false, false, false};
static uint8_t   sshPendingAuthType[4];     // 0=pwd, 1=pubkey, 2=kbd-int, 3=anon
static char      sshPendingUser[4][SSH_CRED_USER_MAX];
static uint8_t   sshPendingSecret[4][SSH_CRED_SECRET_MAX];
static uint16_t  sshPendingSecretLen[4];
static bool      sshPendingValid[4]         = {false, false, false, false};

// SSH key pair management
static ssh_key g_sshKeyPair = NULL;
static bool    g_sshKeyLoaded = false;

// Chunked export state
static uint8_t *g_exportBuf = NULL;
static size_t   g_exportLen = 0;
static size_t   g_exportOff = 0;


// Chunked import state
static uint8_t *g_importBuf = NULL;
static size_t   g_importLen = 0;

// ======================== Helper Functions ========================
void WaitConnectionIfNeeded(bool bFastReturn);
void DisableRadio();
void RadioUpdateStatus();
void ScheduleTimeoutCheck();
bool CacheCertificates();
void CertificatesHash(size_t certsSize, unsigned char * certBuff);

static inline void wifiLedSet(bool on) {
#ifdef USE_WIFI_LED
  if (WIFI_LED_RGB)
    // blue at 50% = connected (R=0, G=0, B=128)
    rgbLedWrite(WIFI_LED_PIN, 0, 0, on ? 128 : 0);
  else
    digitalWrite(WIFI_LED_PIN, on ? WIFI_LED_ON : !WIFI_LED_ON);
#endif
}

static inline void wifiLedInit() {
#ifdef USE_WIFI_LED
  if (!WIFI_LED_RGB)
    pinMode(WIFI_LED_PIN, OUTPUT);
  wifiLedSet(false);
#endif
}

static byte http_open(const char *url) {
  http_close();

  WaitConnectionIfNeeded(false);

  if (WiFi.status() != WL_CONNECTED) {
    return http_close(UNAPI_ERR_NO_NETWORK);
  }

  if (!http.begin(client, url)) {
    return http_close(UNAPI_ERR_NO_CONN);
  }

  if (http.GET() != HTTP_CODE_OK) {
    return http_close(UNAPI_ERR_NO_DATA);
  }

  http_connected = true;
  stream = http.getStreamPtr();
  http_chunk_size = 0;
  http_chunk_header_idx = 0;

  return UNAPI_ERR_OK;
}

static byte http_receive(byte *btCommandData, unsigned int *uiCmdDataLen, bool read_text) {
  static char http_chunk_header[8];
  unsigned int idx = 0;

  while (1) {
    if (WiFi.status() != WL_CONNECTED) {
      *uiCmdDataLen = idx;
      return http_close(UNAPI_ERR_NO_NETWORK);
    }

    if (!http.connected() || !http_connected) {
      *uiCmdDataLen = idx;
      return http_close(UNAPI_ERR_NO_CONN);
    }

    unsigned int available = stream->available();
    while (available--) {
      uint8_t data = stream->read();
      if (http_chunk_size > 0) {
        http_chunk_size--;
        if (read_text && data == 10) {
          btCommandData[idx++] = 0;
          *uiCmdDataLen = idx;
          return UNAPI_ERR_OK;
        }
        btCommandData[idx++] = data;
        if (idx == HTTP_PACKET_SIZE) {
          *uiCmdDataLen = idx;
          return UNAPI_ERR_OK;
        }
      } else {
        if (http_chunk_header_idx > 0 && data == 10) {
          http_chunk_header[http_chunk_header_idx] = 0;
          sscanf(http_chunk_header, "%x", &http_chunk_size);
          http_chunk_header_idx = 0;
          if (http_chunk_size == 0) {
            *uiCmdDataLen = idx;
            if (idx > 0) {
              return UNAPI_ERR_OK;
            } else {
              return http_close(UNAPI_ERR_NO_DATA);
            }
          }
        } else {
          if (data > 32) {
            if (http_chunk_header_idx < sizeof(http_chunk_header)) {
              http_chunk_header[http_chunk_header_idx++] = data;
            }
          }
        }
      }
    }
  }
}

static void http_close(void) {
  http_connected = false;
  http.end();
}

static uint8_t http_close(uint8_t err) {
  http_close();
  http_connected = false;
  return err;
}

// UNAPI send helpers - Bad IP translation fixed
// Extract the 4 raw IP bytes from an IPAddress. We can't just memcpy or cast
// &ip to uint8_t* like before. arduino-esp32's IPAddress Printable so DNS responses returning
// flash-code addresses like 0x3C0E6F20 instead of real IPs.)
static inline void ipToBytes(const IPAddress& ip, uint8_t* out) {
  out[0] = ip[0];
  out[1] = ip[1];
  out[2] = ip[2];
  out[3] = ip[3];
}

unsigned char getConnStatus() {
  wl_status_t st = WiFi.status();
  switch (st) {
      case WL_CONNECTED:      return 5; // STATION_GOT_IP
      case WL_CONNECT_FAILED: return 4; // STATION_CONNECT_FAIL
      case WL_NO_SSID_AVAIL:  return 3; // STATION_NO_AP_FOUND
      case WL_DISCONNECTED:   return 1; // STATION_CONNECTING
      case WL_IDLE_STATUS:    return 0; // STATION_IDLE
      default:                return 2; //Probably wrong password, not connected but SSID is available
  }
}

// Set time via NTP, as required for x.509 validation
void setClock(bool bFastReturn = false) {
  unsigned int uiRetryCount = 20;
  if (bFastReturn)
    uiRetryCount = 8;
  configTime(0,0, "pool.ntp.org");
 
  now = time(nullptr);
  while (now < 8 * 3600 * 2) {
    delay(500);
    now = time(nullptr);
    uiRetryCount--;
    if (uiRetryCount==0)
      break;
  }

  if (now > 8 * 3600 * 2)
    bSNTPOK = true;
  else
    bSNTPOK = false;
  
  gmtime_r(&now, &timeinfo);
}

void SendResponse (unsigned char ucCmd, unsigned char ucResponse, unsigned int uiDataSize, unsigned char *ucData) {
  ucReceivedCommand = REGULAR_COMMAND;
  ucLastCmd = ucCmd;
  ucLastResponse = ucResponse;
  uiLastDataSize = uiDataSize;
  ucLastData = ucData;
  Serial.write(ucCmd);
  Serial.write(ucResponse);
  Serial.write((uint8_t)((uiDataSize>>8)&0xff));
  Serial.write((uint8_t)(uiDataSize&0xff));
  if (uiDataSize)
    Serial.write(ucData,uiDataSize);
}

void SendQuickResponse (unsigned char ucCmd, unsigned char ucResponse) {
  ucReceivedCommand = QUICK_COMMAND;
  ucLastCmd = ucCmd;
  ucLastResponse = ucResponse;
  Serial.write(ucCmd);
  Serial.write(ucResponse);
}

void saveFileConfig() {
  EEPROM.put(0,stDeviceConfiguration);
  EEPROM.commit();
}

bool validateConfigFile() {
  bool bReturn = false;
  EEPROM.get(0,stDeviceConfiguration);
  if ((stDeviceConfiguration.ucConfigFileName[0]=='E')&&(stDeviceConfiguration.ucConfigFileName[1]=='S')\
  &&(stDeviceConfiguration.ucConfigFileName[2]=='P')&&(stDeviceConfiguration.ucConfigFileName[3]=='U')\
  &&(stDeviceConfiguration.ucConfigFileName[4]=='N')&&(stDeviceConfiguration.ucConfigFileName[5]=='A')\
  &&(stDeviceConfiguration.ucConfigFileName[6]=='P')&&(stDeviceConfiguration.ucConfigFileName[7]=='I'))
    bReturn = true;

  if ((!bReturn)||(stDeviceConfiguration.ucStructVersion<3))
  {
    if (!bReturn)
    {
      stDeviceConfiguration.ucConfigFileName[0]='E';
      stDeviceConfiguration.ucConfigFileName[1]='S';
      stDeviceConfiguration.ucConfigFileName[2]='P';
      stDeviceConfiguration.ucConfigFileName[3]='U';
      stDeviceConfiguration.ucConfigFileName[4]='N';
      stDeviceConfiguration.ucConfigFileName[5]='A';
      stDeviceConfiguration.ucConfigFileName[6]='P';
      stDeviceConfiguration.ucConfigFileName[7]='I';
      stDeviceConfiguration.ucStructVersion = 3;
      stDeviceConfiguration.ucNagle = 0;
      stDeviceConfiguration.ucAlwaysOn = 0;
      stDeviceConfiguration.uiRadioOffTimer = 120;
      stDeviceConfiguration.ucAutoClock = 0;
      stDeviceConfiguration.iGMT = -3;
      stDeviceConfiguration.ucBaudRate = ESP32BAUDRATE;
      stDeviceConfiguration.ucAutoUpdateFH = 0;
    }
    else
    {
      if (stDeviceConfiguration.ucStructVersion < 2)// just need to update structure
      {
        stDeviceConfiguration.ucStructVersion = 3;
        stDeviceConfiguration.ucAutoClock = 0;
        stDeviceConfiguration.iGMT = -3;
        stDeviceConfiguration.ucBaudRate = ESP32BAUDRATE;
        stDeviceConfiguration.ucAutoUpdateFH = 0;
      }
      else // just need to update structure
      {
        stDeviceConfiguration.ucStructVersion = 3;
        stDeviceConfiguration.ucBaudRate = ESP32BAUDRATE;
        stDeviceConfiguration.ucAutoUpdateFH = 0;
      }
      saveFileConfig();
    }
  }

  return bReturn;
}

void ScheduleTimeoutCheck() {
    tickerRadioOff.once(stDeviceConfiguration.uiRadioOffTimer, []() { bDisableRadioPending = true; });
}

void  CancelTimeoutCheck() {
  tickerRadioOff.detach();
}

void WaitConnectionIfNeeded(bool bFastReturn = false) {
  if (WiFi.status() != WL_CONNECTED) {
    unsigned long timeout = millis() + (bFastReturn ? 6500 : 10000);
    while (WiFi.status() != WL_CONNECTED && millis() < timeout) {
      yield();
    }
  }
}

byte checkOpenConnections() {
  byte count = 0;
  for (int i = 0; i < 4; i++)
    if (btConnections[i] != CONN_CLOSED) count++;
  // So radio is not disabled during OTA transfer or file hunter http transfer
  if ((count == 0) && ((bHTTPTransfer)||(http_connected)))
    count = 1;
  return count;
}

void setUartSpeed(){
  Serial.flush();
  switch (stDeviceConfiguration.ucBaudRate) {
    case BR9600:
      Serial.begin(9600);
      break;
    case BR19200:
      Serial.begin(19200);
      break;
    case BR57600:
      Serial.begin(57600);
      break;
    case BR115200:
      Serial.begin(115200);
      break;
    case BR230400:
      Serial.begin(230400);
      break;
    case BR460800:
      Serial.begin(460800);
      break;
    case BR921600:
      Serial.begin(921600);
      break;
    case BR859372:
      Serial.begin(859372);
      break;
  }
}

void setup() {
  WiFi.persistent(true);
  EEPROM.begin(32);
  validateConfigFile();
  Serial.setRxBufferSize(2148);
  Serial.setTimeout(1);
  setUartSpeed();
  Serial.print("TCP-IP SSH UNAPI ESP32 v");
  Serial.print(chVer);
  Serial.print(" ");
  Serial.println(FIRMWARETYPE);
  Serial.println("(c) 2019-2026 Oduvaldo Pavan Junior - ducasp@gmail.com");
  displaySetup();               // <-- pantalla de estado WiFi (Display.ino, anadido para MSXnano)
  tapeSetup();                  // <-- cinta virtual por stream (Tape.ino: UART1 GPIO20 + RTR GPIO23)
  longReadyTimeOut = 0;
  btReadyRetries = 3;
  btReceivedCommand = false;
#ifdef USE_WIFI_LED
  // Onboard LED for visible WiFi-up indicator. Always on; independent of debug.
  wifiLedInit();
  // WiFi event handler: drives the LED unconditionally; debug-prints only
  // when DEBUG_WIFI_CONNECT is defined. We register this even in production
  // builds so the LED accurately reflects link state across reconnects.
  WiFi.onEvent([](WiFiEvent_t event, WiFiEventInfo_t info) {
    switch (event) {
      case ARDUINO_EVENT_WIFI_STA_GOT_IP:        wifiLedSet(true);  break;
      case ARDUINO_EVENT_WIFI_STA_DISCONNECTED:  wifiLedSet(false); break;
      default: break;
    }
  });
#endif
  // Initialize file system (FFat). On first boot of a freshly-flashed image
  // the partition has no FAT structure yet — FFat.begin(false) will fail and
  // we format with FFat.begin(true). Subsequent boots mount cleanly.
  // IMPORTANT: do NOT print FFat status to ALL_SERIAL — that's the UART to
  // the FPGA and any stray text corrupts the UNAPI byte stream.
  if (!FFat.begin(false)) {
    FFat.begin(true);
  }

  // Pre-allocate SSH transfer buffers once to avoid heap fragmentation
  g_exportBuf = (uint8_t*)malloc(SSH_KEY_IMPORT_BUF_MAX);
  g_importBuf = (uint8_t*)malloc(SSH_KEY_IMPORT_BUF_MAX);

  sshInitKeyPair();
  initKnownHostsFile();

  WiFi.setSleep(false);
  esp_wifi_set_ps(WIFI_PS_NONE);
  WiFi.persistent(true);
  WiFi.begin();
  if (stDeviceConfiguration.ucAutoClock!=3)
  {
    WiFi.mode(WIFI_STA);
    // Pin minimum auth to WPA2-PSK so the station won't accept OPEN/WEP/WPA-PSK
    // candidates. This also nudges the driver away from preferring WPA3-SAE on
    // WPA2/WPA3 transition-mode APs, which is the most common cause of a
    // ~10-second 4-way handshake timeout when the password is otherwise correct.
    WiFi.setMinSecurity(WIFI_AUTH_WPA2_PSK);
    WiFi.setTxPower(WIFI_POWER_15dBm);
    bWiFiOn = true;
    if (!stDeviceConfiguration.ucAlwaysOn)
      ScheduleTimeoutCheck();
  }
  else
  {
    WiFi.mode(WIFI_OFF);
    bWiFiOn = false;
  }
  configTime(0,0, "pool.ntp.org");
  CacheCertificates();
  libssh_begin();
  Serial.println("Ready");
}

void DisableRadio () {
  if (((!checkOpenConnections())&&(btState == RX_PARSER_IDLE)&&(!bSkipStateCheck)&&(!bHoldConnection))||\
      ((!checkOpenConnections())&&(bSkipStateCheck)&&(!bHoldConnection)))
  {    
    if (bWiFiOn)
    {
      bWiFiOn = false;
      RadioUpdateStatus();
      RadioUpdateStatus();
    }
  }
  else if ((!stDeviceConfiguration.ucAlwaysOn)&&(stDeviceConfiguration.ucAutoClock != 3))
    ScheduleTimeoutCheck();
}

void RadioUpdateStatus () {
  if (bWiFiOn){
    WiFi.mode(WIFI_STA);
    WiFi.begin();
    if (!stDeviceConfiguration.ucAlwaysOn)
      ScheduleTimeoutCheck();
  }
  else
    WiFi.mode(WIFI_OFF);
}

void CertificatesHash(size_t certsSize, unsigned char * certBuff) {
  mbedtls_md_context_t ctx;
  mbedtls_md_type_t md_type = MBEDTLS_MD_SHA256;

  mbedtls_md_init(&ctx);
  mbedtls_md_setup(&ctx, mbedtls_md_info_from_type(md_type), 0);
  mbedtls_md_starts(&ctx);
  mbedtls_md_update(&ctx, (const unsigned char *) certBuff, certsSize);
  mbedtls_md_finish(&ctx, shaResult);
  mbedtls_md_free(&ctx);
  bShaOk = true;
}

bool CacheCertificates() {
  if (g_caPem != NULL)
    free(g_caPem);
  if (g_caBundle != NULL)
    free(g_caBundle);

  g_caPem = NULL;
  g_caBundle = NULL;
  g_caPemLen = 0;
  g_caBundleLen = 0;

  const char *pemPaths[] = {"/ca.pem", "/cacert.pem"};
  for (size_t i = 0; i < (sizeof(pemPaths) / sizeof(pemPaths[0])); i++) {
    File caFile = FFat.open(pemPaths[i], "r");
    if (caFile) {
      size_t size = caFile.size();
      if (size > 0) {
        char *buf = (char*)malloc(size + 1);
        if (buf != NULL) {
          size_t rd = caFile.readBytes(buf, size);
          CertificatesHash(rd, (unsigned char*)buf);
          buf[rd] = 0;
          caFile.close();
          g_caPem = buf;
          g_caPemLen = rd;
          return true;
        }
      }
      caFile.close();
    }
  }

  File bundle = FFat.open("/certs.bin", "r");
  if (bundle) {
    size_t size = bundle.size();
    if (size > 0) {
      uint8_t *buf = (uint8_t*)malloc(size);
      if (buf != NULL) {
        size_t rd = bundle.read(buf, size);
        CertificatesHash(rd, (unsigned char*)buf);
        bundle.close();
        if (rd == size) {
          g_caBundle = buf;
          g_caBundleLen = size;
          return true;
        }
        free(buf);
      } else {
        bundle.close();
      }
    } else {
      bundle.close();
    }
  }
  return false;
}

bool InitCertificates() {
  CacheCertificates();
  setClock(); // Required for X.509 validation

  return true;
}

// Load CA certificates from FFat (FATFS)
// Both cacert.pem and legacy certs.bin will work
bool loadCACertForClient(WiFiClientSecure *client) {
  if (g_caPem != NULL && g_caPemLen > 0) {
    client->setCACert(g_caPem);
    return true;
  }

  if (g_caBundle != NULL && g_caBundleLen > 0) {
    client->setCACertBundle(g_caBundle, g_caBundleLen);
    return true;
  }

  return false;
}

bool IsActivePortInUse (unsigned int uiPort) {
  bool bRet = true;
  byte btLoop;

  for (btLoop = 0; btLoop<4; btLoop++)
    if ( uiLocalPorts[btLoop] == uiPort )
    {
      bRet = false;
      break;
    }

  return bRet;
}

WiFiServer *IsPassivePortInUse (unsigned int uiPort) {
  byte btLoop;
  WiFiServer * newServer;

  for (btLoop = 0; btLoop<4; btLoop++)
  {
    if ( uiListenPorts[btLoop] == uiPort )
      return ServerList[btLoop];
  }

  newServer = new WiFiServer(uiPort);
  newServer->setNoDelay(!stDeviceConfiguration.ucNagle);
  newServer->begin();
  return newServer;  
}

bool CheckActiveLocalPort (unsigned int *lpuiPort) {
  bool bRet = false;
  long lRand;

  if (*lpuiPort == 0xffff) //Random?
  {
    do
    {
      lRand = random (16384,32767);
      *lpuiPort = (unsigned int)lRand;
      bRet = IsActivePortInUse (*lpuiPort);
    }
    while (!bRet);
  }
  else
    bRet = IsActivePortInUse (*lpuiPort);

  return bRet;
}

void CheckPassiveLocalPort (unsigned int *lpuiPort) {
  long lRand;

  if (*lpuiPort == 0xffff) //Random?
  {
    lRand = random (16384,32767);
    *lpuiPort = (unsigned int)lRand;
  }
}

void CloseUdpConnection (byte btConnNumber) {
  switch (btConnNumber)
  {
    case 1:
      Udp1.stop();
    break;
    case 2:
      Udp2.stop();
    break;
    case 3:
      Udp3.stop();
    break;
    case 4:
      Udp4.stop();
    break;
  }
  btConnections[btConnNumber-1] = CONN_CLOSED;
  uiLocalPorts[btConnNumber-1] = 0;
  btIsTransient[btConnNumber-1] = 0;
}

void CloseTcpConnection (byte btConnNumber) {
  if (ClientList[btConnNumber-1]!=NULL)
  {
    ClientList[btConnNumber-1]->stop();
    if (!ServerList[btConnNumber-1])
      delete ClientList[btConnNumber-1];
    ClientList[btConnNumber-1] = NULL;
    switch (btConnNumber)
    {
      case 1:
        memset(btIPConnection1,0,4);
        uiRemotePorts[0]=0;
      break;
      case 2:
        memset(btIPConnection2,0,4);
        uiRemotePorts[1]=0;
      break;
      case 3:
        memset(btIPConnection3,0,4);
        uiRemotePorts[2]=0;
      break;
      case 4:
        memset(btIPConnection4,0,4);
        uiRemotePorts[3]=0;
      break;
    }
    uiRemotePorts[0]=0;

    if (btConnections[btConnNumber-1] == CONN_TCP_TLS_A)
      bTLSInUse = 0;

  }

  if (ServerList[btConnNumber-1])
  {
    switch (btConnNumber)
    {
      case 1:
        if (ServerList[0])
        {
          if ((ServerList[0]!=ServerList[1])&&(ServerList[0]!=ServerList[2])&&(ServerList[0]!=ServerList[3]))
          {
            //This is the last connection linked to this server
            ServerList[0]->stop();
            delete ServerList[0]; //object no longer needed
          }
          ServerList[0] = NULL;
        }
        memset(btIPConnection1,0,4);
        uiRemotePorts[0]=0;
        uiListenPorts[0]=0;
      break;
      case 2:
        if (ServerList[1])
        {
          if ((ServerList[1]!=ServerList[0])&&(ServerList[1]!=ServerList[2])&&(ServerList[1]!=ServerList[3]))
          {
            //This is the last connection linked to this server
            ServerList[1]->stop();
            delete ServerList[1];
          }
          ServerList[1] = NULL;
        }
        memset(btIPConnection2,0,4);
        uiRemotePorts[1]=0;
        uiListenPorts[1]=0;
      break;
      case 3:
        if (ServerList[2])
        {
          if ((ServerList[2]!=ServerList[0])&&(ServerList[2]!=ServerList[1])&&(ServerList[2]!=ServerList[3]))
          {
            //This is the last connection linked to this server
            ServerList[2]->stop();
            delete ServerList[2];
          }
          ServerList[2] = NULL;
        }
        memset(btIPConnection3,0,4);
        uiRemotePorts[2]=0;
        uiListenPorts[2]=0;
      break;
      case 4:
        if (ServerList[3])
        {
          if ((ServerList[3]!=ServerList[0])&&(ServerList[3]!=ServerList[2])&&(ServerList[3]!=ServerList[1]))
          {
            //This is the last connection linked to this server
            ServerList[3]->stop();
            delete ServerList[3];
          }
          ServerList[3] = NULL;
        }
        memset(btIPConnection4,0,4);
        uiRemotePorts[3]=0;
        uiListenPorts[3]=0;
      break;
    }    
  }
  btConnections[btConnNumber-1] = CONN_CLOSED;
  uiLocalPorts[btConnNumber-1] = 0;
  btIsTransient[btConnNumber-1] = 0;
}

void TcpSend(byte btCMDConnNumber,byte *btCommandData,unsigned int uiCmdDataLen) {
  unsigned int uiSent = 0;

  if ((ClientList[btCMDConnNumber-1]!=NULL)&&(ClientList[btCMDConnNumber-1]->connected()))
  {
    uiSent = uiSent + ClientList[btCMDConnNumber-1]->write(&btCommandData[uiSent],uiCmdDataLen-uiSent);
    if (uiSent == uiCmdDataLen)
      SendResponse (TCPIP_TCP_SEND, UNAPI_ERR_OK, 0, 0);
    else
      SendResponse (TCPIP_TCP_SEND, UNAPI_ERR_BUFFER, 0, 0);
  }
  else if (ClientList[btCMDConnNumber-1]!=NULL)
    SendResponse (TCPIP_TCP_SEND, UNAPI_ERR_CONN_STATE, 0, 0);
  else
    SendResponse (TCPIP_TCP_SEND, UNAPI_ERR_NO_CONN, 0, 0);
}

void TcpState(byte btCMDConnNumber)
{
  size_t availableBytes;
  byte btStatus;
  unsigned char ucResponse[16];
  memset (ucResponse,0,sizeof(ucResponse));

  if (btConnections[btCMDConnNumber-1] == CONN_TCP_TLS_A)
  {
    if (ClientList[btCMDConnNumber-1]->connected())
      ucResponse[0] = 1; //It is a flag indicating it is TLS connection
    else
    {
      //TODO: can check real error instead of returning TLS other?
      ucResponse[0] = 19;
    }
  }

  if (ClientList[btCMDConnNumber-1]!=NULL)
  {
    if (ClientList[btCMDConnNumber-1]->available()==0)
    {
      btStatus=ClientList[btCMDConnNumber-1]->connected() ? 4 : 0;
      if (btStatus==0)
        btStatus=7; //ESP8266 Wificlass go to 0 once remote end disconnects, this can lead UNAPI apps go nuts
      ucResponse[1]=btStatus; //Connection State
    }
    else
      ucResponse[1]=4; //Connection State forced to stablished when still there is data
    ucResponse[2]=(unsigned char)(ClientList[btCMDConnNumber-1]->available()&0xff); //Incoming bytes available LSB
    ucResponse[3]=(unsigned char)((ClientList[btCMDConnNumber-1]->available()>>8)&0xff); //Incoming bytes available MSB
    availableBytes = ClientList[btCMDConnNumber-1]->availableForWrite();
    if (availableBytes>2048)
      availableBytes = 2048; //We can receive only up to 2048 in a single command
    ucResponse[6]=(unsigned char)(availableBytes&0xff); //Free space in buffer LSB
    ucResponse[7]=(unsigned char)((availableBytes>>8)&0xff); //Free space in buffer MSB
    if (btCMDConnNumber==1)
      memcpy(&ucResponse[8],btIPConnection1,4);
    else if (btCMDConnNumber==2)
      memcpy(&ucResponse[8],btIPConnection2,4);
    else if (btCMDConnNumber==3)
      memcpy(&ucResponse[8],btIPConnection3,4);
    else
      memcpy(&ucResponse[8],btIPConnection4,4);
    ucResponse[12]=(unsigned char)(uiRemotePorts[btCMDConnNumber-1]&0xff);
    ucResponse[13]=(unsigned char)((uiRemotePorts[btCMDConnNumber-1]>>8)&0xff);
    ucResponse[14]=(unsigned char)(uiLocalPorts[btCMDConnNumber-1]&0xff);
    ucResponse[15]=(unsigned char)((uiLocalPorts[btCMDConnNumber-1]>>8)&0xff);
    SendResponse (TCPIP_TCP_STATE, UNAPI_ERR_OK, 16, ucResponse);
  }
  else if (btConnections[btCMDConnNumber-1] == CONN_TCP_PASSIVE)
  {
    // Here we can either say Listen (1) or Stablished (4)
    // If there is a client, it is stablished, otherwise, listening
    ucResponse[1] = ClientList[btCMDConnNumber-1] != NULL ? 4 : 1; //Connection State
    ucResponse[14]=(unsigned char)(uiLocalPorts[btCMDConnNumber-1]&0xff);
    ucResponse[15]=(unsigned char)((uiLocalPorts[btCMDConnNumber-1]>>8)&0xff);
    SendResponse (TCPIP_TCP_STATE, UNAPI_ERR_OK, 16, ucResponse);
    return;
  }
  else
  {
    SendResponse (TCPIP_TCP_STATE, UNAPI_ERR_NO_CONN, 0, 0);
    return;
  }
}

void TcpReceive (byte btCMDConnNumber, uint16_t ui16RcvSize, byte * btCommandData) {
  int iLenght = 0;
  btCommandData[0]=0;
  btCommandData[1]=0;

  if (ClientList[btCMDConnNumber-1]!=NULL)
  {
    iLenght = ClientList[btCMDConnNumber-1]->available();
    if (iLenght>0)
    {
      if (iLenght>ui16RcvSize)
        iLenght = ui16RcvSize; //get up to ui16RcvSize
      iLenght = ClientList[btCMDConnNumber-1]->read(&btCommandData[2],iLenght);
    }
    else
      iLenght = 0;

    if (iLenght)
      iLenght+=2;
    SendResponse (TCPIP_TCP_RCV, UNAPI_ERR_OK, (unsigned int) iLenght, btCommandData);
  }
  else
  {
    SendResponse (TCPIP_TCP_RCV, UNAPI_ERR_NO_CONN, 0, 0);
  }
}

void WarmBoot() {
  byte bti;
  for (bti=0;bti<4;++bti)
  {
    if (btConnections[bti] == CONN_SSH) {
      if (sshChannels[bti] != NULL) {
        ssh_channel_close(sshChannels[bti]);
        ssh_channel_free(sshChannels[bti]);
        sshChannels[bti] = NULL;
      }
      if (sshSessions[bti] != NULL) {
        ssh_disconnect(sshSessions[bti]);
        ssh_free(sshSessions[bti]);
        sshSessions[bti] = NULL;
      }
    }
    CloseTcpConnection(bti);
    CloseUdpConnection(bti);
  }
  if ((!bWiFiOn)&&(stDeviceConfiguration.ucAutoClock!=3))
  {
    bWiFiOn = true;
    RadioUpdateStatus();
  }
}

/**
 * Filters the SSH buffer in-place using a static carryover state machine.
 * Supports up to 4 concurrent connections (conn_id 1 to 4).
 * Skips invalid ANSI sequences by rewinding the write pointer (O(N) squeeze).
 */
void filter_ssh_buffer_inplace(uint8_t conn_id, uint8_t *buffer, int *length, bool reset = false) {
    // 1. Enforce bounds to prevent memory corruption (must be 1, 2, 3, or 4)
    if (conn_id < 1 || conn_id > 4) {
        return; 
    }

    // 2. Create the persistent array of states for the 4 connections.
    // They are automatically initialized to zero/false/STATE_TEXT on the first boot.
    static SshFilterState connections[4];

    // 3. Grab a reference to the specific connection's state block (offset by -1 for 0-indexing)
    SshFilterState &s = connections[conn_id - 1];

    // --- THE RESET BLOCK ---
    if (reset) {
        s.carry_len = 0;
        s.state = STATE_TEXT;
        s.drop_sequence = false;
        s.is_extended_color = false;
        s.current_param = 0;
        s.prev_param = 0;
        return; // Exit immediately
    }

    // Standard safety checks
    if (buffer == NULL || length == NULL || *length <= 0) {
        return;
    }

    // Inject carryover from the previous split sequence for THIS connection
    if (s.carry_len > 0) {
        memmove(buffer + s.carry_len, buffer, *length);
        memcpy(buffer, s.carryover, s.carry_len);
        *length += s.carry_len;
        s.carry_len = 0;
    }

    int read_idx = 0;
    int write_idx = 0;
    int input_len = *length;
    int seq_start_idx = 0;

    while (read_idx < input_len) {
        uint8_t c = buffer[read_idx++];
        
        // Tentatively write every character.
        buffer[write_idx++] = c;

        switch (s.state) {
            case STATE_TEXT:
                if (c == 0x1B) {
                    s.state = STATE_ESC;
                    seq_start_idx = write_idx - 1;
                    s.drop_sequence = false;
                }
                break;

            case STATE_ESC:
                if (c == '[') {
                    s.state = STATE_CSI;
                    s.is_extended_color = false;
                    s.current_param = 0;
                    s.prev_param = 0;
                } 
                else if (c == ']') {
                    s.state = STATE_SKIP_OSC;
                    s.drop_sequence = true;
                } 
                else {
                    s.state = STATE_TEXT; 
                }
                break;

            case STATE_CSI:
                // Drop sequences starting with '?' (private modes / alt-screen)
                if (write_idx - seq_start_idx == 3 && c == '?') {
                    s.drop_sequence = true;
                }

                // Integer parameter parsing
                if (c >= '0' && c <= '9') {
                    s.current_param = (s.current_param * 10) + (c - '0');
                } 
                else if (c == ';') {
                    // Check for strict truecolor/256-color patterns: 38;5, 48;5, 38;2, etc.
                    if ((s.prev_param == 38 || s.prev_param == 48 || s.prev_param == 58) && 
                        (s.current_param == 5 || s.current_param == 2)) {
                        s.is_extended_color = true;
                    }
                    s.prev_param = s.current_param;
                    s.current_param = 0;
                }

                // Sequence Termination (any letter 0x40 to 0x7E)
                if (c >= 0x40 && c <= 0x7E) {
                    // ONLY drop extended color codes if they terminate as graphic renditions ('m')
                    if (c == 'm' && s.is_extended_color) {
                        s.drop_sequence = true;
                    }

                    if (s.drop_sequence) {
                        write_idx = seq_start_idx; // SQUEEZE
                    }
                    s.state = STATE_TEXT;
                }
                break;

            case STATE_SKIP_OSC:
                if (c == 0x07) { 
                    write_idx = seq_start_idx;
                    s.state = STATE_TEXT;
                } 
                else if (c == 0x1B) { 
                    // Wait for ST (\x1b\) or BEL
                    s.state = STATE_OSC_EXPECT_ST;
                }
                break;

            case STATE_OSC_EXPECT_ST:
                if (c == '\\') {
                    // ST (\x1b\): drop entire OSC
                    write_idx = seq_start_idx;
                    s.state = STATE_TEXT;
                } else if (c == 0x07) {
                    // BEL-terminated OSC also valid here
                    write_idx = seq_start_idx;
                    s.state = STATE_TEXT;
                } else if (c == 0x1B) {
                    // Another ESC — stay in this state waiting for ST
                } else {
                    // Unexpected character — drop it and continue skipping OSC
                    s.state = STATE_SKIP_OSC;
                }
                break;
        }
    }

    // Handle incomplete sequences at the chunk boundary
    if (s.state != STATE_TEXT) {
        s.carry_len = write_idx - seq_start_idx;
        
        if (s.carry_len <= sizeof(s.carryover)) {
            memcpy(s.carryover, buffer + seq_start_idx, s.carry_len);
        } else {
            s.carry_len = 0; 
        }
        
        write_idx = seq_start_idx;
        s.state = STATE_TEXT; 
    }

    *length = write_idx;
}

static void initKnownHostsFile() {
    if (!FFat.exists(SSH_KNOWN_HOSTS_FILE)) {
        File f = FFat.open(SSH_KNOWN_HOSTS_FILE, "w");
        if (f) f.close();
    }
}

static bool isHostKnown(const uint8_t* hash) {
    File f = FFat.open(SSH_KNOWN_HOSTS_FILE, "r");
    if (!f) return false;
    uint8_t stored[SSH_KNOWN_HOST_HASH_SIZE];
    while (f.read(stored, sizeof(stored)) == sizeof(stored)) {
        if (memcmp(stored, hash, sizeof(stored)) == 0) {
            f.close();
            return true;
        }
    }
    f.close();
    return false;
}

static bool addHostToKnown(const uint8_t* hash) {
    File f = FFat.open(SSH_KNOWN_HOSTS_FILE, "a");
    if (!f) return false;
    size_t w = f.write(hash, SSH_KNOWN_HOST_HASH_SIZE);
    f.close();
    return w == SSH_KNOWN_HOST_HASH_SIZE;
}

// ======================== Key Pair Persistence ========================

static bool sshSaveKeyPair(ssh_key key) {
    char *privPem = NULL;
    if (ssh_pki_export_privkey_base64(key, NULL, NULL, NULL, &privPem) != SSH_OK)
        return false;

    File f = FFat.open(SSH_KEY_PRIV_FILE, "w");
    if (!f) { ssh_string_free_char(privPem); return false; }
    f.write((uint8_t*)privPem, strlen(privPem));
    f.close();

    ssh_key pubKey = NULL;
    if (ssh_pki_export_privkey_to_pubkey(key, &pubKey) == SSH_OK) {
        char *pubB64 = NULL;
        if (ssh_pki_export_pubkey_base64(pubKey, &pubB64) == SSH_OK) {
            f = FFat.open(SSH_KEY_PUB_FILE, "w");
            if (f) {
                      const char *keyType = ssh_key_type_to_char(ssh_key_type(pubKey));
                      f.write((uint8_t*)keyType, strlen(keyType));
                      f.write((uint8_t*)" ", 1);
                      f.write((uint8_t*)pubB64, strlen(pubB64));
                      f.close();
                  }
            ssh_string_free_char(pubB64);
        }
        ssh_key_free(pubKey);
    }

    ssh_string_free_char(privPem);
    return true;
}

static bool sshLoadKeyPair() {
    if (g_sshKeyPair) { ssh_key_free(g_sshKeyPair); g_sshKeyPair = NULL; }

    File f = FFat.open(SSH_KEY_PRIV_FILE, "r");
    if (!f) return false;

    size_t len = f.size();
    char *pem = (char*)malloc(len + 1);
    if (!pem) { f.close(); return false; }
    f.read((uint8_t*)pem, len);
    pem[len] = '\0';
    f.close();

    int rc = ssh_pki_import_privkey_base64(pem, NULL, NULL, NULL, &g_sshKeyPair);
    free(pem);
    return (rc == SSH_OK);
}

static void sshInitKeyPair() { g_sshKeyLoaded = sshLoadKeyPair(); }

static void sshFreeKeyPair() {
    if (g_sshKeyPair) { ssh_key_free(g_sshKeyPair); g_sshKeyPair = NULL; }
    FFat.remove(SSH_KEY_PRIV_FILE);
    FFat.remove(SSH_KEY_PUB_FILE);
    g_sshKeyLoaded = false;
}

static void sshExportCleanup() {
    g_exportLen = g_exportOff = 0;
}

static void sshImportCleanup() {
    g_importLen = 0;
}

// ======================== sshFinishSession ========================

static byte sshFinishSession(byte slot, ssh_session session, ssh_channel channel) {
    bool channelWasOpen = (channel != NULL);
    if (!channelWasOpen) {
        channel = ssh_channel_new(session);
        if (!channel) return SSH_ERR_NO_RSS;
        if (ssh_channel_open_session(channel) != SSH_OK) {
            ssh_channel_free(channel);
            return UNAPI_ERR_NO_CONN;
        }
    }

    if (sshSubsystems[slot] == SSH_SUB_PTY) {
        const char *termStr;
        switch (sshTermType) {
            case TERM_VT52: termStr = "vt52"; break;
            case TERM_ANSI: termStr = "ansi"; break;
            default: termStr = "xterm"; break;
        }
        if (ssh_channel_request_pty_size(channel, termStr, sshWinCol, sshWinRow) != SSH_OK) {
            if (!channelWasOpen) { ssh_channel_close(channel); ssh_channel_free(channel); }
            return SSH_ERR_PTY_REQ;
        }
        if (ssh_channel_request_shell(channel) != SSH_OK) {
            if (!channelWasOpen) { ssh_channel_close(channel); ssh_channel_free(channel); }
            return SSH_ERR_PTY_REQ;
        }
    }

    sshSessions[slot] = session;
    sshChannels[slot] = channel;
    btConnections[slot] = CONN_SSH;
    sshKbdIntActive[slot] = false;
    sshPendingValid[slot] = false;
    return UNAPI_ERR_OK;
}

// ======================== Key Management Functions ========================

static byte sshKeyGen() {
    ssh_key newKey = NULL;
    if (ssh_pki_generate(SSH_KEYTYPE_ECDSA, 256, &newKey) != SSH_OK)
        return SSH_ERR_NO_RSS;
    if (!sshSaveKeyPair(newKey)) {
        ssh_key_free(newKey);
        return SSH_ERR_NO_RSS;
    }
    if (g_sshKeyPair) ssh_key_free(g_sshKeyPair);
    g_sshKeyPair = newKey;
    g_sshKeyLoaded = true;
    return UNAPI_ERR_OK;
}

static byte sshKeyExport(byte what, byte *buf, unsigned int maxSize,
                         unsigned int *written, byte *lastBlock) {
    if (!g_sshKeyLoaded) return SSH_ERR_NO_KEY;
    if (what > 2) return UNAPI_ERR_INV_PARAM;

    if (g_exportLen == 0) {
        char *privPem = NULL;
        char *pubB64 = NULL;

        if (ssh_pki_export_privkey_base64(g_sshKeyPair, NULL, NULL, NULL, &privPem) != SSH_OK)
            return SSH_ERR_NO_KEY;

        ssh_key pubKey = NULL;
        if (ssh_pki_export_privkey_to_pubkey(g_sshKeyPair, &pubKey) == SSH_OK) {
            ssh_pki_export_pubkey_base64(pubKey, &pubB64);
            ssh_key_free(pubKey);
        }

        size_t privLen = privPem ? strlen(privPem) : 0;
        size_t pubLen  = pubB64  ? strlen(pubB64)  : 0;

        if (what == 0) {
            g_exportLen = privLen;
        } else if (what == 1) {
            const char *keyType = ssh_key_type_to_char(ssh_key_type(g_sshKeyPair));
            size_t typeLen = strlen(keyType);
            g_exportLen = typeLen + 1 + pubLen;
        } else {
            g_exportLen = privLen + 1 + pubLen;
        }

        g_exportBuf = (uint8_t*)malloc(g_exportLen + 1);
        if (!g_exportBuf) {
            if (privPem) ssh_string_free_char(privPem);
            if (pubB64)  ssh_string_free_char(pubB64);
            return SSH_ERR_NO_RSS;
        }

        if (what == 0) {
            memcpy(g_exportBuf, privPem, privLen);
        } else if (what == 1) {
            const char *keyType = ssh_key_type_to_char(ssh_key_type(g_sshKeyPair));
            size_t typeLen = strlen(keyType);
            memcpy(g_exportBuf, keyType, typeLen);
            g_exportBuf[typeLen] = ' ';
            memcpy(g_exportBuf + typeLen + 1, pubB64, pubLen);
        } else {
            memcpy(g_exportBuf, privPem, privLen);
            g_exportBuf[privLen] = 0;
            if (pubLen) memcpy(g_exportBuf + privLen + 1, pubB64, pubLen);
        }

        if (privPem) ssh_string_free_char(privPem);
        if (pubB64)  ssh_string_free_char(pubB64);

        g_exportOff = 0;
    }

    size_t remaining = g_exportLen - g_exportOff;
    size_t chunk = (remaining < maxSize) ? remaining : maxSize;
    memcpy(buf, g_exportBuf + g_exportOff, chunk);
    g_exportOff += chunk;
    *written = (unsigned int)chunk;
    *lastBlock = (g_exportOff >= g_exportLen) ? 1 : 0;

    if (*lastBlock) sshExportCleanup();
    return UNAPI_ERR_OK;
}

static byte sshKeyImport(byte lastBlock, byte *data, unsigned int dataLen) {
    if (!g_importBuf) {
        return SSH_ERR_NO_RSS;
    }
    if (g_importLen + dataLen > SSH_KEY_IMPORT_BUF_MAX) {
        sshImportCleanup();
        return UNAPI_ERR_BUFFER;
    }
    memcpy(g_importBuf + g_importLen, data, dataLen);
    g_importLen += dataLen;

    if (!lastBlock) return UNAPI_ERR_OK;

    // Final chunk: parse complete private key PEM
    ssh_key newKey = NULL;
    int rc = ssh_pki_import_privkey_base64((const char*)g_importBuf, NULL, NULL, NULL, &newKey);
    if (rc != SSH_OK) {
        sshImportCleanup();
        return SSH_ERR_KEY_INV_DATA;
    }
    if (!sshSaveKeyPair(newKey)) {
        ssh_key_free(newKey);
        sshImportCleanup();
        return SSH_ERR_NO_RSS;
    }
    if (g_sshKeyPair) ssh_key_free(g_sshKeyPair);
    g_sshKeyPair = newKey;
    g_sshKeyLoaded = true;
    sshImportCleanup();
    return UNAPI_ERR_OK;
}

static byte sshKeyInfo(byte *fingerprintBuf, byte *keyStatus) {
    *keyStatus = g_sshKeyLoaded ? 1 : 0;
    if (!fingerprintBuf || !g_sshKeyLoaded) return UNAPI_ERR_OK;

    ssh_key pubKey = NULL;
    if (ssh_pki_export_privkey_to_pubkey(g_sshKeyPair, &pubKey) != SSH_OK)
        return SSH_ERR_NO_KEY;
    unsigned char *hash = NULL; size_t hlen;
    if (ssh_get_publickey_hash(pubKey, SSH_PUBLICKEY_HASH_SHA256, &hash, &hlen) != SSH_OK) {
        ssh_key_free(pubKey);
        return SSH_ERR_NO_KEY;
    }
    String b64 = base64::encode(hash, hlen);
    ssh_clean_pubkey_hash(&hash);
    ssh_key_free(pubKey);
    b64.replace("=", "");
    strcpy((char*)fingerprintBuf, b64.c_str());
    return UNAPI_ERR_OK;
}

static byte sshOpen(byte *params, unsigned int paramLen, byte *outConnNum) {
  if (paramLen < 8) return UNAPI_ERR_INV_PARAM;

  // Parse remote IP
  IPAddress remoteIP(params[0], params[1], params[2], params[3]);
  if (remoteIP == IPAddress(0,0,0,0) || remoteIP == IPAddress(127,0,0,1))
    return UNAPI_ERR_INV_PARAM;
  if (WiFi.status() != WL_CONNECTED) return UNAPI_ERR_NO_NETWORK;

  // Parse port (LSB first)
  int port = params[4] | (params[5] << 8);

  // Subsystem: 
  byte subsystem = params[6];
  if ((subsystem != SSH_SUB_PTY) && (subsystem != SSH_SUB_RAW))
    return UNAPI_ERR_NOT_IMP;
  // Flags:
  // bit 0: auth method (0=password, 1=public key). Ignored when bit 2 is set.
  // bit 1: Anonymous Authentication. Cannot be combined with bit 2.
  // bit 2: Keyboard-Interactive Authentication
  // bit 3: Non ANSI filter
  // bit 4: Host key verification (returns SSH_ERR_UNKNOWN_HOST + hash if unknown)
  // bits 5-7: Unused, must be zero
  byte flags = params[7];
  if (flags > 0x1f)
    return UNAPI_ERR_INV_PARAM;
  if (((flags & 0x06) == 0x06) || ((flags & 0x03) == 0x03))
    return UNAPI_ERR_INV_PARAM; // bit 1 can't be set when bit 0 or bit 2 is set
  bool usePubKey = (flags & 0x01) != 0;
  bool anonymousConnection = (flags & 0x02) != 0;
  bool useKbdInt = (flags & 0x04) != 0;
  bool bFilter = (flags & 0x08) != 0;
  bool verifyHostKey = (flags & 0x10) != 0;

  if (bFilter && subsystem != SSH_SUB_PTY)
    return UNAPI_ERR_INV_PARAM;

  unsigned int userOff = 8;
  unsigned int userLen = 0;
  unsigned int authOff;
  unsigned int authLen = 0;

  if (useKbdInt) {
    // Keyboard-interactive: only username is needed, no auth data
    while (userOff + userLen < paramLen && params[userOff + userLen] != 0) userLen++;
    if (userLen == 0 || userOff + userLen >= paramLen) return UNAPI_ERR_INV_PARAM;
  } else if (usePubKey) {
    // Public key: only username needed, no password field
    while (userOff + userLen < paramLen && params[userOff + userLen] != 0) userLen++;
    if (userLen == 0 || userOff + userLen >= paramLen) return UNAPI_ERR_INV_PARAM;
  } else if (!anonymousConnection) {
    // Password: username + password required
    while (userOff + userLen < paramLen && params[userOff + userLen] != 0) userLen++;
    if (userLen == 0 || userOff + userLen >= paramLen) return UNAPI_ERR_INV_PARAM;
    authOff = userOff + userLen + 1;
    while (authOff + authLen < paramLen && params[authOff + authLen] != 0) authLen++;
    if (authLen == 0) return UNAPI_ERR_INV_PARAM;
  }

  // Find free slot
  byte slot;
  for (slot = 0; slot < 4; slot++)
    if (btConnections[slot] == CONN_CLOSED) break;
  if (slot == 4) return UNAPI_ERR_NO_FREE_CONN;

  btSSHFilter[slot] = bFilter;
  // Create SSH session
  ssh_session session = ssh_new();
  if (session == NULL) return SSH_ERR_NO_RSS;

  // Build host string
  char hostStr[16];
  sprintf(hostStr, "%d.%d.%d.%d", params[0], params[1], params[2], params[3]);
  ssh_options_set(session, SSH_OPTIONS_HOST, hostStr);
  ssh_options_set(session, SSH_OPTIONS_PORT, &port);
  ssh_options_set(session, SSH_OPTIONS_USER, (const char*)&params[userOff]);

  // Connect TCP
  if (ssh_connect(session) != SSH_OK) {
    ssh_free(session);
    return UNAPI_ERR_NO_CONN;
  }
  {
    socket_t sock = ssh_get_fd(session);
    int rcvbuf = 4096;
    setsockopt(sock, SOL_SOCKET, SO_RCVBUF, (const char*)&rcvbuf, sizeof(rcvbuf));
  }

  // Host key verification (bit 4)
  if (verifyHostKey) {
    ssh_key key = NULL;
    unsigned char *hash = NULL;
    size_t hlen;
    if (ssh_get_server_publickey(session, &key) == SSH_OK) {
      if (ssh_get_publickey_hash(key, SSH_PUBLICKEY_HASH_SHA256, &hash, &hlen) == SSH_OK && hlen == SSH_KNOWN_HOST_HASH_SIZE) {
        if (!isHostKnown(hash)) {
          // Save credentials for SSH_ADD_KNOWN_HOST resume
          if (useKbdInt) {
            sshPendingAuthType[slot] = 2;
            strncpy(sshPendingUser[slot], (const char*)&params[userOff], SSH_CRED_USER_MAX - 1);
            sshPendingUser[slot][SSH_CRED_USER_MAX - 1] = '\0';
            sshPendingSecretLen[slot] = 0;
          } else if (usePubKey) {
            sshPendingAuthType[slot] = 1;
            strncpy(sshPendingUser[slot], (const char*)&params[userOff], SSH_CRED_USER_MAX - 1);
            sshPendingUser[slot][SSH_CRED_USER_MAX - 1] = '\0';
            sshPendingSecretLen[slot] = 0;
          } else if (!anonymousConnection) {
            sshPendingAuthType[slot] = 0;
            strncpy(sshPendingUser[slot], (const char*)&params[userOff], SSH_CRED_USER_MAX - 1);
            sshPendingUser[slot][SSH_CRED_USER_MAX - 1] = '\0';
            unsigned int authDataLen = authLen < SSH_CRED_SECRET_MAX ? authLen : SSH_CRED_SECRET_MAX - 1;
            memcpy(sshPendingSecret[slot], &params[authOff], authDataLen);
            sshPendingSecret[slot][authDataLen] = '\0';
            sshPendingSecretLen[slot] = authDataLen;
          } else {
            sshPendingAuthType[slot] = 3;
            sshPendingUser[slot][0] = '\0';
            sshPendingSecretLen[slot] = 0;
          }
          sshPendingValid[slot] = true;
          memcpy(sshPendingHash[slot], hash, SSH_KNOWN_HOST_HASH_SIZE);
          sshPendingHashValid[slot] = true;
          sshSessions[slot] = session;
          sshSubsystems[slot] = subsystem;
          btConnections[slot] = CONN_SSH;
          *outConnNum = slot + 1;
          ssh_clean_pubkey_hash(&hash);
          ssh_key_free(key);
          return SSH_ERR_UNKNOWN_HOST;
        }
        ssh_clean_pubkey_hash(&hash);
      }
      ssh_key_free(key);
    }
  }

  if (useKbdInt) {
    // Keyboard-interactive: defer authentication, store session as-is
    sshSessions[slot] = session;
    sshChannels[slot] = NULL;
    sshSubsystems[slot] = subsystem;
    btConnections[slot] = CONN_SSH;
    sshKbdIntActive[slot] = true;
    sshChallengeDataLen[slot] = 0;
    *outConnNum = slot + 1;
    return UNAPI_ERR_OK;
  }

  // Authenticate
  if (usePubKey) {
    if (!g_sshKeyLoaded) { ssh_disconnect(session); ssh_free(session); return SSH_ERR_NO_KEY; }
    if (ssh_userauth_publickey(session, NULL, g_sshKeyPair) != SSH_AUTH_SUCCESS) {
      ssh_disconnect(session);
      ssh_free(session);
      return SSH_ERR_PWD;
    }
  } else if (!anonymousConnection){
    if (ssh_userauth_password(session, NULL, (const char*)&params[authOff]) != SSH_AUTH_SUCCESS) {
      ssh_disconnect(session);
      ssh_free(session);
      return SSH_ERR_PWD;
    }
  }
  else {
    if (ssh_userauth_none(session, "") != SSH_AUTH_SUCCESS) {
      ssh_disconnect(session);
      ssh_free(session);
      return SSH_ERR_PWD;
    }
  }

  // Open channel and set up subsystem
  sshSubsystems[slot] = subsystem;
  byte result = sshFinishSession(slot, session, NULL);
  if (result == UNAPI_ERR_OK)
    *outConnNum = slot + 1;
  else {
    ssh_disconnect(session);
    ssh_free(session);
  }
  return result;
}

static byte sshAddKnownHost(byte connNum) {
  if (connNum < 1 || connNum > 4) return UNAPI_ERR_NO_CONN;
  byte slot = connNum - 1;
  if (!sshPendingHashValid[slot]) return UNAPI_ERR_NO_CONN;

  if (!addHostToKnown(sshPendingHash[slot])) {
    return SSH_ERR_NO_RSS;
  }
  sshPendingHashValid[slot] = false;

  ssh_session session = sshSessions[slot];
  if (session == NULL) {
    btConnections[slot] = CONN_CLOSED;
    sshPendingValid[slot] = false;
    return UNAPI_ERR_NO_CONN;
  }

  byte subsystem = sshSubsystems[slot];
  byte authType = sshPendingAuthType[slot];
  ssh_channel channel = NULL;
  byte result;

  if (authType == 2) {
    sshKbdIntActive[slot] = true;
    sshChallengeDataLen[slot] = 0;
    sshChannels[slot] = NULL;
    sshPendingValid[slot] = false;
    return UNAPI_ERR_OK;
  }

  if (authType == 1) {
    if (!g_sshKeyLoaded) goto fail_cleanup;
    if (ssh_userauth_publickey(session, NULL, g_sshKeyPair) != SSH_AUTH_SUCCESS)
      goto fail_cleanup;
  } else if (authType == 0) {
    if (ssh_userauth_password(session, NULL, (const char*)sshPendingSecret[slot]) != SSH_AUTH_SUCCESS) {
      goto fail_cleanup;
    }
  } else if (authType == 3) {
    if (ssh_userauth_none(session, "") != SSH_AUTH_SUCCESS) {
      goto fail_cleanup;
    }
  }

  // Open channel and set up subsystem
  channel = ssh_channel_new(session);
  if (channel == NULL) goto fail_cleanup;
  if (ssh_channel_open_session(channel) != SSH_OK) { ssh_channel_free(channel); goto fail_cleanup; }

  result = sshFinishSession(slot, session, channel);
  if (result == UNAPI_ERR_OK) {
    sshPendingValid[slot] = false;
    return UNAPI_ERR_OK;
  }
  goto fail_cleanup;

fail_cleanup:
  ssh_disconnect(session);
  ssh_free(session);
  sshSessions[slot] = NULL;
  sshChannels[slot] = NULL;
  btConnections[slot] = CONN_CLOSED;
  sshPendingValid[slot] = false;
  return UNAPI_ERR_NO_CONN;
}

static byte sshClose(byte connNum) {
  if (connNum < 1 || connNum > 4) return UNAPI_ERR_NO_CONN;
  byte slot = connNum - 1;
  if (btConnections[slot] != CONN_SSH) return UNAPI_ERR_NO_CONN;

  if (sshChannels[slot] != NULL) {
    ssh_channel_close(sshChannels[slot]);
    ssh_channel_free(sshChannels[slot]);
    sshChannels[slot] = NULL;
  }
  if (sshSessions[slot] != NULL) {
    ssh_disconnect(sshSessions[slot]);
    ssh_free(sshSessions[slot]);
    sshSessions[slot] = NULL;
  }
  sshKbdIntActive[slot] = false;
  sshSubsystems[slot] = 0;
  sshChallengeDataLen[slot] = 0;
  sshPendingHashValid[slot] = false;
  sshPendingValid[slot] = false;
  btConnections[slot] = CONN_CLOSED;
  return UNAPI_ERR_OK;
}

static byte sshState(byte connNum, uint8_t *state, uint16_t *avail) {
  if (connNum < 1 || connNum > 4) return UNAPI_ERR_NO_CONN;
  byte slot = connNum - 1;
  if (btConnections[slot] != CONN_SSH || sshSessions[slot] == NULL) {
    *state = SSH_CLOSED;
    return UNAPI_ERR_OK;
  }

  // Check for HostUnknown state (pending host key approval)
  if (sshPendingHashValid[slot]) {
    *state = SSH_HOST_UNKNOWN;
    *avail = 0;
    return UNAPI_ERR_OK;
  }

  // Check for keyboard-interactive auth in progress
  if (sshKbdIntActive[slot]) {
    *state = SSH_AUTH_CHALLENGE;
    *avail = (uint16_t)sshChallengeDataLen[slot];
    return UNAPI_ERR_OK;
  }

  ssh_channel ch = sshChannels[slot];
  if (ch != NULL && ssh_channel_is_open(ch) && !ssh_channel_is_eof(ch)) {
    *state = SSH_CONNECTED;
    *avail = (uint16_t)ssh_channel_poll(ch, 0);
  } else if (ch != NULL && ssh_channel_is_eof(ch)) {
    *state = SSH_ERROR;
    *avail = 0;
  } else {
    *state = SSH_CLOSED;
    *avail = 0;
  }
  return UNAPI_ERR_OK;
}

static byte sshSend(byte connNum, byte *data, unsigned int len) {
  if (connNum < 1 || connNum > 4) return UNAPI_ERR_NO_CONN;
  byte slot = connNum - 1;
  if (btConnections[slot] != CONN_SSH) return UNAPI_ERR_NO_CONN;
  if (sshChannels[slot] == NULL || !ssh_channel_is_open(sshChannels[slot]))
    return UNAPI_ERR_CONN_STATE;

  int n = ssh_channel_write(sshChannels[slot], data, len);
  if (n == SSH_ERROR) return UNAPI_ERR_CONN_STATE;
  if ((unsigned int)n < len) return UNAPI_ERR_BUFFER;
  return UNAPI_ERR_OK;
}

static byte sshReceive(byte connNum, byte *buf, uint16_t maxSize, uint16_t *outLen) {
  if (connNum < 1 || connNum > 4) return UNAPI_ERR_NO_CONN;
  byte slot = connNum - 1;
  if (btConnections[slot] != CONN_SSH) return UNAPI_ERR_NO_CONN;
  if (sshChannels[slot] == NULL || !ssh_channel_is_open(sshChannels[slot]))
    return UNAPI_ERR_CONN_STATE;

  int n = ssh_channel_read_nonblocking(sshChannels[slot], buf, maxSize, 0);
  if (n == SSH_ERROR) return UNAPI_ERR_CONN_STATE;
  if (n == 0) return UNAPI_ERR_NO_DATA;
  if (btSSHFilter[slot])
    filter_ssh_buffer_inplace(connNum, buf, &n);
  *outLen = (uint16_t)n;
  return UNAPI_ERR_OK;
}

static byte sshSetTermType(byte type) {
  if (type > TERM_XTERM) return UNAPI_ERR_INV_PARAM;
  sshTermType = type;
  return UNAPI_ERR_OK;
}

static byte sshSetWinSize(byte rows, byte cols) {
  if (rows == 0 || cols == 0) return UNAPI_ERR_INV_PARAM;
  sshWinRow = rows;
  sshWinCol = cols;
  return UNAPI_ERR_OK;
}

static byte sshAuthGetChallenge(byte connNum, byte *buf, unsigned int bufSize,
                                byte *outPrompts, byte *outEchoFlags, unsigned int *outLen)
{
  if (connNum < 1 || connNum > 4) return UNAPI_ERR_NO_CONN;
  byte slot = connNum - 1;
  if (btConnections[slot] != CONN_SSH || sshSessions[slot] == NULL)
    return UNAPI_ERR_NO_CONN;
  if (!sshKbdIntActive[slot]) return UNAPI_ERR_CONN_STATE;

  // If challenge data is not yet cached, fetch it from libssh
  if (sshChallengeDataLen[slot] == 0) {
    int rc = ssh_userauth_kbdint(sshSessions[slot], NULL, NULL);
    if (rc == SSH_AUTH_SUCCESS) {
        // Auth succeeded: open channel and set up subsystem
        ssh_channel channel = ssh_channel_new(sshSessions[slot]);
        if (channel == NULL) {
          sshKbdIntActive[slot] = false;
          return SSH_ERR_NO_RSS;
        }
        if (ssh_channel_open_session(channel) != SSH_OK) {
          ssh_channel_free(channel);
          sshKbdIntActive[slot] = false;
          return UNAPI_ERR_NO_CONN;
        }

        if (sshSubsystems[slot] == SSH_SUB_PTY) {
          const char *termStr;
          switch (sshTermType) {
            case TERM_VT52: termStr = "vt52"; break;
            case TERM_ANSI: termStr = "ansi"; break;
            default: termStr = "xterm"; break;
          }
          ssh_channel_request_pty_size(channel, termStr, sshWinCol, sshWinRow);
          if (ssh_channel_request_shell(channel) != SSH_OK) {
            ssh_channel_close(channel);
            ssh_channel_free(channel);
            sshKbdIntActive[slot] = false;
            return SSH_ERR_PTY_REQ;
          }
          // Force a window size update to "wake up" the shell
          ssh_channel_change_pty_size(channel, sshWinCol, sshWinRow);
        }

        sshChannels[slot] = channel;
        sshKbdIntActive[slot] = false;
        return UNAPI_ERR_OK;
    }
    else if (rc == SSH_AUTH_DENIED) {
      return SSH_ERR_AUTH_TRY_OTHER;
    }    
    else if (rc != SSH_AUTH_INFO) {
      return UNAPI_ERR_CONN_STATE;
    }

    const char *name = ssh_userauth_kbdint_getname(sshSessions[slot]);
    const char *instruction = ssh_userauth_kbdint_getinstruction(sshSessions[slot]);
    int numPrompts = ssh_userauth_kbdint_getnprompts(sshSessions[slot]);
    if (name == NULL) name = "";
    if (instruction == NULL) instruction = "";

    unsigned int pos = 0;
    byte echoFlags = 0;

    // Write name, instruction, prompts into cache
    auto writeStr = [&](const char *s) {
      unsigned int slen = strlen(s) + 1;
      if (pos + slen <= SSH_CHALLENGE_BUF_SIZE) {
        memcpy(sshChallengeData[slot] + pos, s, slen);
        pos += slen;
      }
    };

    writeStr(name);
    writeStr(instruction);
    for (int i = 0; i < numPrompts; i++) {
      char echo = 0;
      const char *prompt = ssh_userauth_kbdint_getprompt(sshSessions[slot], i, &echo);
      if (prompt == NULL) prompt = "";
      writeStr(prompt);
      if (echo) echoFlags |= (1 << i);
    }
    // Final terminator
    if (pos < SSH_CHALLENGE_BUF_SIZE) sshChallengeData[slot][pos] = 0;
    pos++;

    sshChallengeDataLen[slot] = pos;
    sshChallengePrompts[slot] = (byte)numPrompts;
    sshChallengeEchoFlags[slot] = echoFlags;
  }

  // Serve from cache
  unsigned int needed = sshChallengeDataLen[slot];
  if (needed > bufSize) {
    *outLen = needed;
    return UNAPI_ERR_BUFFER;
  }

  memcpy(buf, sshChallengeData[slot], needed);
  *outPrompts = sshChallengePrompts[slot];
  *outEchoFlags = sshChallengeEchoFlags[slot];
  *outLen = needed;
  return UNAPI_ERR_OK;
}

static byte sshAuthRespond(byte connNum, byte *responseBlock, unsigned int respLen)
{
  if (connNum < 1 || connNum > 4) return UNAPI_ERR_NO_CONN;
  byte slot = connNum - 1;
  if (btConnections[slot] != CONN_SSH || sshSessions[slot] == NULL)
    return UNAPI_ERR_NO_CONN;
  if (!sshKbdIntActive[slot]) return UNAPI_ERR_CONN_STATE;

  // Parse response block: count byte followed by zero-terminated strings
  byte count = responseBlock[0];
  if (count == 0 || count != sshChallengePrompts[slot]) return UNAPI_ERR_INV_PARAM;

  unsigned int off = 1;
  for (byte i = 0; i < count; i++) {
    if (off >= respLen) return UNAPI_ERR_INV_PARAM;
    const char *answer = (const char *)(responseBlock + off);
    if (ssh_userauth_kbdint_setanswer(sshSessions[slot], i, answer))
      return SSH_ERR_PWD;
    off += strlen(answer) + 1;
  }

  // Clear cached challenge data
  sshChallengeDataLen[slot] = 0;

  // Submit answers
  int rc = ssh_userauth_kbdint(sshSessions[slot], NULL, NULL);

  if (rc == SSH_AUTH_SUCCESS) {
    ssh_channel channel = ssh_channel_new(sshSessions[slot]);
    if (channel == NULL) { sshKbdIntActive[slot] = false; return SSH_ERR_NO_RSS; }
    if (ssh_channel_open_session(channel) != SSH_OK) {
      ssh_channel_free(channel); sshKbdIntActive[slot] = false; return UNAPI_ERR_NO_CONN;
    }
    byte result = sshFinishSession(slot, sshSessions[slot], channel);
    if (result != UNAPI_ERR_OK) {
      ssh_channel_close(channel); ssh_channel_free(channel);
      sshKbdIntActive[slot] = false;
    }
    return result;
  }

  if (rc == SSH_AUTH_INFO) {
    // Another challenge available, will be cached on next GET_CHALLENGE
    return UNAPI_ERR_OK;
  }

  // SSH_AUTH_DENIED, SSH_AUTH_ERROR, SSH_AUTH_PARTIAL, etc.
  sshKbdIntActive[slot] = false;
  return SSH_ERR_PWD;
}


void received_data_parser () {
  static bool bInit = false;
  static unsigned long RXTimeOut;
  static byte btCommand;
  static byte btCommandData[MAX_CMD_DATA_LEN];
  static byte btIPRet[4];
  static unsigned int uiCmdDataLen, uiCmdDataRemaining,uiTmp;
  static byte btCmdInternalStep = 0;
  byte btTmp;
  unsigned int uiForHelper;
  unsigned int uiCMDLocalPort,uiCMDRemotePort;
  int iLenght;
  byte btCMDTransient;
  byte btCMDPassive;
  byte btCMDConnNumber;
  byte btCMDBeginRet;
  uint16_t ui16Port,ui16RcvSize;
  static int iAPCount = 0;
  unsigned int iAPItemI,iPWDCount;
  bool bOkParam = false;
  bool bPWD = false;
  static unsigned char ucSSID[33];
  static unsigned char ucPWD[65];
  static unsigned char ucOTAServer[256];
  static unsigned char ucOTAFile[256];
  uint16_t uiOTAPort;
  String stOTAServer,stOTAFile,stVersion;
  WiFiClient OTAclient;
  t_httpUpdate_return OTAret;
  uint32_t ulSerialUpdateSize = 0;
  byte bAutoIPConfig=0;
  uint32_t bin_flash_size;
  bool bScanReconnect = false;
  bool bScanReconnectNeeded = false;

  if (!bInit)
  {
    bInit = true;
    RXTimeOut = millis() + 250;
  }
  else
  {
    if (millis()>RXTimeOut)
    {
      //RX Timeout, reset state machine
      btState = RX_PARSER_IDLE;
    }
    RXTimeOut = millis() + 250;
  }

  switch (btState)
  {
    case RX_PARSER_IDLE:
      //Ok, so first let's check if it is a valid command
      if (Serial.readBytes(&btCommand,1) == 1)
      {
        btReceivedCommand = true;
        if ((btCommand!=CUSTOM_F_RELEASECONNECTION) && (btCommand!=CUSTOM_F_RESET) && (!bWiFiOn) && (btCommand!=CUSTOM_F_QUERY) && (stDeviceConfiguration.ucAutoClock!=3))
        {
          bWiFiOn = true;
          RadioUpdateStatus();
        }
        switch(btCommand)
        {
          case CUSTOM_F_INITCERTS:
            if(!InitCertificates())
            {
              SendQuickResponse(btCommand,UNAPI_ERR_NO_DATA);
            }
            else
            {
              SendQuickResponse(btCommand,UNAPI_ERR_OK);
            }
          break;
          case CUSTOM_F_RETRY_TX:
            if(ucReceivedCommand == QUICK_COMMAND)
            {
              SendQuickResponse (ucLastCmd, ucLastResponse);
            }
            else if(ucReceivedCommand == REGULAR_COMMAND)
            {
              SendResponse (ucLastCmd, ucLastResponse, uiLastDataSize, ucLastData);
            }
          break;
          case  CUSTOM_F_WARMBOOT:
            WarmBoot();
            Serial.println("Ready");
          break;
          case  CUSTOM_F_GETBOARD:
            SendResponse (CUSTOM_F_GETBOARD, UNAPI_ERR_OK, sizeof(FIRMWARETYPE), (unsigned char*)FIRMWARETYPE);
          break;
          case CUSTOM_F_END_RS232_UPDATE:
            if (!bSerialUpdateInProgress)
            {
              SendQuickResponse(btCommand,UNAPI_ERR_INV_PARAM);
            }
            else if (bSerialCertUpdateInProgress) 
            {
              // Finalize the cert upload: close the temp file, sniff the
              // first bytes to decide PEM vs mbedTLS bundle, rename to the
              // appropriate path, invalidate the cached-cert pointers so
              // next HTTPS connect reloads from FFat.
              g_certUploadFile.close();
              bSerialCertUpdateInProgress = false;
              bSerialUpdateInProgress = false;

              char hdr[12] = {0};
              size_t hdrRead = 0;
              File t = FFat.open("/cert_upload.tmp", "r");
              if (t)
              {
                hdrRead = t.readBytes(hdr, 11);
                t.close();
              }

              const char* targetPath = "/certs.bin";  // mbedTLS bundle (default)
              if (hdrRead >= 11 && memcmp(hdr, "-----BEGIN ", 11) == 0)
                targetPath = "/ca.pem";               // PEM text

              if (FFat.exists(targetPath)) FFat.remove(targetPath);
              if (FFat.rename("/cert_upload.tmp", targetPath))
              {
                // Drop in-memory cached certs so loadCACertForClient() reloads
                if (g_caPem)    { free(g_caPem);    g_caPem = NULL;    g_caPemLen = 0; }
                if (g_caBundle) { free(g_caBundle); g_caBundle = NULL; g_caBundleLen = 0; }
                SendQuickResponse(btCommand, UNAPI_ERR_OK);
                // No ESP.restart() — cert update is hot-applied.
              }
              else
                SendQuickResponse(btCommand, UNAPI_ERR_NO_DATA);
            }
            else
            {
              if (!Update.end())
              {
                SendQuickResponse(btCommand,UNAPI_ERR_NO_DATA);
              }
              else
              {
                SendQuickResponse(btCommand,UNAPI_ERR_OK);
                // On ESP32 - C6 if not waiting a little, the response sent is corrupted or not even sent
                Serial.flush();
                delay(1000);
                bSerialUpdateInProgress = false;
                ESP.restart();
              }
            }
          break;
          //Reset?
          case CUSTOM_F_RESET:
            Serial.print("R0");
            if (!bSerialUpdateInProgress)
              ESP.restart();
            break;
          //GET Access Point Status
          case CUSTOM_F_GETAPSTS:
          {
            unsigned char uchConSts[34];
            memset(uchConSts,0,sizeof(uchConSts));
            uchConSts[0]= getConnStatus();
            strcpy((char*)&uchConSts[1],WiFi.SSID().c_str());
            SendResponse (CUSTOM_F_GETAPSTS, UNAPI_ERR_OK, (2+strlen((const char*)&uchConSts[1])), uchConSts);
          }
            break;
          //Query?
          case CUSTOM_F_QUERY:
            Serial.print("OK");
            break;
          case CUSTOM_F_GET_DATETIME:
            {
              unsigned char uchDateTime[7];
              time_t currTime;
              struct tm *currTimeInfo;

              if (!bSNTPOK)
              {
                WaitConnectionIfNeeded(true);
                if (WiFi.status() != WL_CONNECTED)
                  SendQuickResponse (CUSTOM_F_GET_DATETIME, UNAPI_ERR_NO_NETWORK);
              }

              if ((bSNTPOK)||(WiFi.status() == WL_CONNECTED))
              {
                if (!bSNTPOK)
                  setClock(true);
                if (bSNTPOK)
                {
                  time(&currTime);
                  currTime = currTime + (stDeviceConfiguration.iGMT * 3600);
                  currTimeInfo = localtime(&currTime);
                  uchDateTime[0] = currTimeInfo->tm_sec & 0xff;
                  uchDateTime[1] = currTimeInfo->tm_min & 0xff;
                  uchDateTime[2] = currTimeInfo->tm_hour & 0xff;
                  uchDateTime[3] = currTimeInfo->tm_mday & 0xff;
                  uchDateTime[4] = (currTimeInfo->tm_mon+1) & 0xff;
                  uchDateTime[5] = (currTimeInfo->tm_year + 1900) & 0xff;
                  uchDateTime[6] = ((currTimeInfo->tm_year + 1900)>>8) & 0xff;
                  SendResponse (CUSTOM_F_GET_DATETIME, UNAPI_ERR_OK, 7, uchDateTime);
                }
                else
                  SendQuickResponse (CUSTOM_F_GET_DATETIME, UNAPI_ERR_NO_NETWORK);
              }
            }
            break;
          case CUSTOM_F_HOLDCONNECTION:
            {
              bHoldConnection = true;
              if (!bWiFiOn)
              {
                bWiFiOn= true;
                RadioUpdateStatus();
              }
              SendQuickResponse(btCommand,UNAPI_ERR_OK);
            }
            break;
          case CUSTOM_F_RELEASECONNECTION:
            {
              bHoldConnection = false;
              if (stDeviceConfiguration.ucAutoClock==3)
              {
                bWiFiOn = false;
                RadioUpdateStatus();
              }
              SendQuickResponse(btCommand,UNAPI_ERR_OK);
            }
            break;
          case CUSTOM_F_QUERY_AUTOCLOCK:
            {
              unsigned char uchAutoClock[2];
              uchAutoClock[0] = stDeviceConfiguration.ucAutoClock;
              if (stDeviceConfiguration.iGMT>=0)
                uchAutoClock[1] = stDeviceConfiguration.iGMT&0xff;
              else
                uchAutoClock[1] = ((stDeviceConfiguration.iGMT*-1)&0xff)|0x80;
              SendResponse (CUSTOM_F_QUERY_AUTOCLOCK, UNAPI_ERR_OK, 2, uchAutoClock);
            }
            break;
          case CUSTOM_F_QUERY_SETTINGS:
            {
              unsigned char uchSettingsString[30];
              unsigned char uchTmp[10];

              sprintf((char*)uchTmp,"%u",stDeviceConfiguration.uiRadioOffTimer);
              
              if (stDeviceConfiguration.ucNagle)
                sprintf((char*)uchSettingsString,"ON:%s",(char*)uchTmp);
              else
                sprintf((char*)uchSettingsString,"OFF:%s",(char*)uchTmp);

              SendResponse (CUSTOM_F_QUERY_SETTINGS, UNAPI_ERR_OK, strlen((char*)uchSettingsString), uchSettingsString);
            }
            break;
          case CUSTOM_F_GET_VER:
            Serial.write(CUSTOM_F_GET_VER);
            Serial.write(chVer[0]-'0');
            Serial.write(chVer[2]-'0');
            break;
          case CUSTOM_F_SCAN:
            wl_status_t stScan;
            stScan = WiFi.status();
            if ((stScan != WL_CONNECTED) && (stScan != WL_IDLE_STATUS))
            {
              // ESP32 when with bad credentials will not scan unless you call disconnectds
              WiFi.disconnect();
              bScanReconnectNeeded = true;
            }
            WiFi.scanNetworks(true,false);
            SendQuickResponse('S',0);
            break;
          case CUSTOM_F_SCAN_R:
            iAPCount = WiFi.scanComplete();
            Serial.write('s');
            if (iAPCount>=0)
            {
              bScanReconnect = true;
              Serial.write(0);
              Serial.write((unsigned char)iAPCount); //count of APs
              if (iAPCount>0)
              {
                for (int iScanRLoop = 0; iScanRLoop<iAPCount; iScanRLoop++)
                {
                  Serial.printf("%s",WiFi.SSID(iScanRLoop).c_str());
                  Serial.write(0); //Terminate SSID
                  Serial.write(WiFi.encryptionType(iScanRLoop) == WIFI_AUTH_OPEN ? 'O' : 'E');
                }
              }
            }
            else if (iAPCount == WIFI_SCAN_RUNNING)
            {
              Serial.write(UNAPI_ERR_NO_DATA); //no data yet
            }
            else {
              bScanReconnect = true;
              Serial.write(UNAPI_ERR_NO_NETWORK); //no AP found found
            }
            if (bScanReconnect && bScanReconnectNeeded) {
              WiFi.mode(WIFI_STA);
              WiFi.begin();
            }
            break;
          case CUSTOM_F_TURN_WIFI_OFF:
            bSkipStateCheck = true;
            DisableRadio();
            bSkipStateCheck = false;
            SendQuickResponse(btCommand,UNAPI_ERR_OK);
          break;
          case CUSTOM_F_TURN_RS232_OFF:
            // Note: it won't be possible to restore communications, only through power cycle or physical reset
            SendQuickResponse(btCommand,UNAPI_ERR_OK);
            Serial.end();
            break;
          case CUSTOM_F_CLEAR_AP:
            WiFi.disconnect(false, true);
            yield();
            SendQuickResponse(btCommand,UNAPI_ERR_OK);
            break;
          case CUSTOM_F_NO_DELAY:
            stDeviceConfiguration.ucNagle = 0;
            saveFileConfig();
            SendQuickResponse(btCommand,UNAPI_ERR_OK);
          break;
          case CUSTOM_F_DELAY:
            stDeviceConfiguration.ucNagle = 1;
            saveFileConfig();
            SendQuickResponse(btCommand,UNAPI_ERR_OK);
          break;

          case TCPIP_HTTP_OPEN:
          case TCPIP_HTTP_RECEIVE:
          case TCPIP_HTTP_CLOSE:
          case TCPIP_GET_CAPAB:
          case TCPIP_GET_IPINFO:
          case TCPIP_NET_STATE:
          case TCPIP_DNS_Q:
          case TCPIP_DNS_Q_NEW:
          case TCPIP_UDP_OPEN:
          case TCPIP_UDP_CLOSE:
          case TCPIP_UDP_STATE:
          case TCPIP_UDP_SEND:
          case TCPIP_UDP_RCV:
          case TCPIP_TCP_OPEN:
          case TCPIP_TCP_CLOSE:
          case TCPIP_TCP_ABORT:
          case TCPIP_TCP_STATE:
          case TCPIP_TCP_SEND:
          case TCPIP_TCP_RCV:
          case CUSTOM_F_CONNECT_AP:
          case CUSTOM_F_UPDATE_FW:
          case CUSTOM_F_UPDATE_CERTS:
          case TCPIP_CONFIG_AUTOIP:
          case TCPIP_CONFIG_IP:
          case CUSTOM_F_START_RS232_UPDATE:
          case CUSTOM_F_START_RS232_CERT_UPDATE:
          case CUSTOM_F_BLOCK_RS232_UPDATE:
          case CUSTOM_F_WIFI_ON_TIMER_SET:
          case CUSTOM_F_SET_AUTOCLOCK:
          case CUSTOM_F_FILE_BOARD:
          case CUSTOM_F_SETBAUD:
          case CUSTOM_F_TSX_LIST:
          case CUSTOM_F_TSX_PLAY:
          case CUSTOM_F_TSX_STATUS:
          case CUSTOM_F_TSX_UPLOAD:
          case CUSTOM_F_TSX_UPBLOCK:
          case CUSTOM_F_TSX_FIND:
          case SSH_GET_CAPAB:
          case SSH_OPEN:
          case SSH_CLOSE:
          case SSH_STATE:
          case SSH_SEND:
          case SSH_RCV:
          case SSH_TERM_TYPE:
          case SSH_WIN_SIZE:
           case SSH_AUTH_GET_CHALLENGE:
           case SSH_AUTH_RESPOND:
           case SSH_ADD_KNOWN_HOST:
           case SSH_KEY_GEN:
           case SSH_KEY_EXPORT:
           case SSH_KEY_IMPORT:
           case SSH_KEY_INFO:
              btState = RX_PARSER_WAIT_DATA_SIZE;
             btCmdInternalStep = 0;
             break;
          default:
            btState = RX_PARSER_IDLE;
            break;
        }
        
      }
    break;

    case RX_PARSER_WAIT_DATA_SIZE:
      if (Serial.readBytes(&btTmp,1) == 1)
      {
        if (btCmdInternalStep == 0)
        {
          uiCmdDataLen = btTmp*256;
          btCmdInternalStep++;
        }
        else
        {
          uiCmdDataLen += btTmp;
          uiCmdDataRemaining = uiCmdDataLen;
          btCmdInternalStep = 0;
          if (uiCmdDataLen)
            btState = RX_PARSER_GET_DATA;
          else
          {
            btState = RX_PARSER_PROCCESS_CMD;
            goto proccesscmd;
          }
        }
      }
    break;

    case RX_PARSER_GET_DATA:
      uiTmp = Serial.available();
      if (uiTmp > uiCmdDataRemaining)
        uiTmp = uiCmdDataRemaining;
      uiTmp = Serial.readBytes(&btCommandData[uiCmdDataLen - uiCmdDataRemaining],uiTmp);
      uiCmdDataRemaining -= uiTmp;
      if (uiCmdDataRemaining == 0)
        btState = RX_PARSER_PROCCESS_CMD;
      else
        break;
        
    case RX_PARSER_PROCCESS_CMD:
proccesscmd:
      switch(btCommand)
      {
        case CUSTOM_F_SETBAUD:
          if ((uiCmdDataLen !=1)||(btCommandData[0] > BR859372))
            SendQuickResponse(btCommand,UNAPI_ERR_INV_PARAM);
          else {
            stDeviceConfiguration.ucBaudRate = btCommandData[0];
            saveFileConfig();
            SendQuickResponse(btCommand, UNAPI_ERR_OK);
            setUartSpeed();
          }
        break;
        // ---- cinta virtual por stream (TapeWeb.ino, MSXnano/MSXimus) ----
        case CUSTOM_F_TSX_LIST:
          if (uiCmdDataLen != 3) SendQuickResponse(btCommand, UNAPI_ERR_INV_PARAM);
          else tsxCmdList(btCommandData[0], btCommandData[1], btCommandData[2]);
        break;
        case CUSTOM_F_TSX_PLAY:
          if (uiCmdDataLen == 0) tsxCmdStop();          // payload vacio = STOP
          else if (uiCmdDataLen != 3) SendQuickResponse(btCommand, UNAPI_ERR_INV_PARAM);
          else tsxCmdPlay(btCommandData[0], btCommandData[1], btCommandData[2]);
        break;
        case CUSTOM_F_TSX_STATUS:
          tsxCmdStatus();
        break;
        case CUSTOM_F_TSX_UPLOAD:
          tsxCmdUploadStart(btCommandData, uiCmdDataLen);
        break;
        case CUSTOM_F_TSX_UPBLOCK:
          tsxCmdUploadBlock(btCommandData, uiCmdDataLen);
        break;
        case CUSTOM_F_TSX_FIND:
          tsxCmdFind(btCommandData, uiCmdDataLen);
        break;
        case CUSTOM_F_FILE_BOARD:
          if (strcmp(FIRMWARETYPE,(const char*)btCommandData) == 0) {
            bRS232UpdateAllowed = true;
            SendQuickResponse(btCommand, UNAPI_ERR_OK);
          }
          else {
            bRS232UpdateAllowed = false;
            SendQuickResponse(btCommand,UNAPI_ERR_INV_PARAM);
          }
        break;
        case CUSTOM_F_START_RS232_UPDATE:
        case CUSTOM_F_START_RS232_CERT_UPDATE:
          if ((uiCmdDataLen !=12)||(bSerialUpdateInProgress))
            SendQuickResponse(btCommand,UNAPI_ERR_INV_PARAM);
          else
          {
            ulSerialUpdateSize = btCommandData[0] + (btCommandData[1]*0x100) + (btCommandData[2]*0x10000) + (btCommandData[3]*0x1000000) + (btCommandData[4]*0x100000000) + (btCommandData[5]*0x10000000000)+ (btCommandData[6]*0x1000000000000)+ (btCommandData[7]*0x100000000000000);
            if (btCommand == CUSTOM_F_START_RS232_CERT_UPDATE)
            {
              // Stream the cert bundle into a FFat temp file. On END we'll
              // sniff the first bytes to decide whether it's PEM (rename to
              // /ca.pem) or an mbedTLS bundle (rename to /certs.bin).
              if (FFat.exists("/cert_upload.tmp")) FFat.remove("/cert_upload.tmp");
              g_certUploadFile = FFat.open("/cert_upload.tmp", "w");
              if (!g_certUploadFile)
                SendQuickResponse(btCommand, UNAPI_ERR_NO_DATA);
              else {
                bSerialUpdateInProgress = true;
                bSerialCertUpdateInProgress = true;
                SendQuickResponse(btCommand, UNAPI_ERR_OK);
              }
            }
            else
            {
              if (!bRS232UpdateAllowed)
                SendQuickResponse(btCommand,UNAPI_ERR_INV_OPER);
              else if (ulSerialUpdateSize > (ESP.getFreeSketchSpace() - 0x1000))
                SendQuickResponse(btCommand,UNAPI_ERR_INV_PARAM);
              else
              {
                if(!Update.begin(ulSerialUpdateSize, U_FLASH, -1, HIGH))
                  SendQuickResponse(btCommand,UNAPI_ERR_INV_PARAM);
                else
                {
                  SendQuickResponse(btCommand,UNAPI_ERR_OK);
                  bSerialUpdateInProgress = true;
                }
              }
            }
          }
        break;
        case CUSTOM_F_BLOCK_RS232_UPDATE:
          if ((uiCmdDataLen == 0)||(!bSerialUpdateInProgress))
            SendQuickResponse(btCommand,UNAPI_ERR_INV_PARAM);
          else if (bSerialCertUpdateInProgress) 
          {
            // Cert path: append to the FFat temp file
            size_t w = g_certUploadFile.write(btCommandData, uiCmdDataLen);
            if (w != uiCmdDataLen)
              SendQuickResponse(btCommand, UNAPI_ERR_NO_DATA);
            else
              SendQuickResponse(btCommand, UNAPI_ERR_OK);
          }
          else
          {
            if (Update.write(btCommandData,uiCmdDataLen)!=uiCmdDataLen)
              SendQuickResponse(btCommand,UNAPI_ERR_NO_DATA);
            else
              SendQuickResponse(btCommand,UNAPI_ERR_OK);
          }
        break;
        case CUSTOM_F_SET_AUTOCLOCK:
          if ( (uiCmdDataLen != 2) || (btCommandData[0]>3) ||\
               ((btCommandData[1]>12)&&((btCommandData[1]<129)||(btCommandData[1]>140))) )
            SendQuickResponse(btCommand,UNAPI_ERR_INV_PARAM);
          else
          {
            // Enabling a disabled adapter?
            if ((stDeviceConfiguration.ucAutoClock == 3)&&(btCommandData[0]!=3))
            {
              bWiFiOn = true;
              RadioUpdateStatus();
            }
            stDeviceConfiguration.ucAutoClock = btCommandData[0];
            if (btCommandData[1] > 12) //negative?
              stDeviceConfiguration.iGMT = (btCommandData[1]&0x0f)*-1;
            else
              stDeviceConfiguration.iGMT = btCommandData[1];
            saveFileConfig();
            if (stDeviceConfiguration.ucAutoClock == 3)
            {
              bSkipStateCheck = true;
              DisableRadio();
              bSkipStateCheck = false;
            }
            SendQuickResponse(btCommand,UNAPI_ERR_OK);
          }
        break;
        case CUSTOM_F_WIFI_ON_TIMER_SET:
          if (uiCmdDataLen != 2)
            SendQuickResponse(btCommand,UNAPI_ERR_INV_PARAM);
          else
          {
            stDeviceConfiguration.uiRadioOffTimer = (unsigned int)(btCommandData[0]*256) + btCommandData[1];
            if (stDeviceConfiguration.uiRadioOffTimer > 600) //10 minutes top
              stDeviceConfiguration.uiRadioOffTimer = 600;
            if ((stDeviceConfiguration.uiRadioOffTimer>0)&&(stDeviceConfiguration.uiRadioOffTimer<30))
              stDeviceConfiguration.uiRadioOffTimer = 30; //30 seconds at least
            if (stDeviceConfiguration.uiRadioOffTimer)
              stDeviceConfiguration.ucAlwaysOn = 0;
            else
            {
              stDeviceConfiguration.ucAlwaysOn = 1;
              CancelTimeoutCheck();
            }
            saveFileConfig();
            SendQuickResponse(btCommand,UNAPI_ERR_OK);
          }
        break;
        case TCPIP_CONFIG_AUTOIP:
          if ((uiCmdDataLen != 2) || (btCommandData[0]>1) || (btCommandData[1]>3))
            SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          else
          {
            if (btCommandData[0]) //set?
            {
              bIPAutomatic = (btCommandData[1] & 1) != 0;
              bDNSAutomatic = (btCommandData[1] & 2) != 0;
            }
            if (bIPAutomatic)
              bAutoIPConfig|=B00000001;
            else
              bAutoIPConfig&=B11111110;

            if (bDNSAutomatic)
              bAutoIPConfig|=B00000010;
            else
              bAutoIPConfig&=B11111101;
            SendResponse(btCommand,UNAPI_ERR_OK,1,&bAutoIPConfig);
          }
        break;
        case TCPIP_CONFIG_IP:
          externalIP[0] = btCommandData[1];
          externalIP[1] = btCommandData[2];
          externalIP[2] = btCommandData[3];
          externalIP[3] = btCommandData[4];
          if ((uiCmdDataLen != 5) || (btCommandData[0]==0) || (btCommandData[0]==2)|| (btCommandData[0]>6))
            SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          else
          {
            if ((!bIPAutomatic) && ( (btCommandData[0]==1)||(btCommandData[0]==3)||(btCommandData[0]==4) ))
            {
              //Set IP/MASK/GATEWAY
              switch (btCommandData[0])
              {
                case 1:
                  WiFi.config(externalIP,WiFi.gatewayIP(),WiFi.subnetMask(),WiFi.dnsIP(0),WiFi.dnsIP(1));
                break;
                case 3:
                  WiFi.config(WiFi.localIP(),WiFi.gatewayIP(),externalIP,WiFi.dnsIP(0),WiFi.dnsIP(1));
                break;
                case 4:
                  WiFi.config(WiFi.localIP(),externalIP,WiFi.subnetMask(),WiFi.dnsIP(0),WiFi.dnsIP(1));
                break;
              }
              SendResponse(btCommand,UNAPI_ERR_OK,0,0);
            }
            else if ((!bDNSAutomatic) && ( (btCommandData[0]==5)||(btCommandData[0]==6) ))
            {
              //Set Primary DNS or secondary DNS
              switch (btCommandData[0])
              {
                case 5:
                  WiFi.config(WiFi.localIP(),WiFi.gatewayIP(),WiFi.subnetMask(),externalIP,WiFi.dnsIP(1));
                break;
                case 6:
                  WiFi.config(WiFi.localIP(),WiFi.gatewayIP(),WiFi.subnetMask(),WiFi.dnsIP(0),externalIP);
                break;
              }
              SendResponse(btCommand,UNAPI_ERR_OK,0,0);
            }
            else //sorry
              SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          }
        break;
        case CUSTOM_F_UPDATE_FW:
        case CUSTOM_F_UPDATE_CERTS:
          bOkParam = false;
          uiOTAPort = btCommandData[0]+(btCommandData[1]*256);
          if ((uiCmdDataLen <4)||(bSerialUpdateInProgress))
            SendQuickResponse(btCommand,UNAPI_ERR_INV_PARAM);
          else
          {
            for (iAPItemI=2; (iAPItemI<257)&&(iAPItemI<uiCmdDataLen); iAPItemI++)
            {
              ucOTAServer[iAPItemI-2]=btCommandData[iAPItemI];
              if (btCommandData[iAPItemI]==0)
              {
                bOkParam = true;
                iAPItemI++;
                break;
              }
            }
            if (bOkParam)
            {
              if (iAPItemI<uiCmdDataLen) //still more data?
                bOkParam = false;

              if (bOkParam)
              {
                yield();
                stOTAServer = (const char*)ucOTAServer;
                if (btCommand == CUSTOM_F_UPDATE_FW) {
                  char chOTAFWHelper[300];
                  sprintf(chOTAFWHelper, "/index.php?type=%s&version=%s", FIRMWARETYPE, chVer);
                  stOTAFile = chOTAFWHelper;
                  httpUpdate.rebootOnUpdate(false);
                  bHTTPTransfer = true;                
                  OTAret = httpUpdate.update(OTAclient, stOTAServer, uiOTAPort, stOTAFile, chVer);
                  bHTTPTransfer = false;
                  if (OTAret==HTTP_UPDATE_OK)
                    SendQuickResponse(btCommand,0);
                  else if (OTAret==HTTP_UPDATE_NO_UPDATES)
                    SendQuickResponse(btCommand,UNAPI_ERR_INV_OPER);
                  else
                    SendQuickResponse(btCommand,UNAPI_ERR_NO_DATA);
                } else {
                  // lets simply download the cert file
                  stOTAFile="/index.php?type=CERTS&hash=";
                  char shaBuff[3];
                  for (int iHashByte = 0; iHashByte < 32; ++iHashByte) {
                    sprintf(shaBuff,"%02X",shaResult[iHashByte]);
                    stOTAFile += shaBuff;
                  }
                  bHTTPTransfer = true;
                  http.begin(OTAclient, stOTAServer, uiOTAPort, stOTAFile, chVer);
                  int httpCode = http.GET();
                  if (httpCode == HTTP_CODE_OK) {
                    g_certUploadFile = FFat.open("/cert_upload.tmp", FILE_WRITE);
                    if (!g_certUploadFile) {
                        SendQuickResponse(btCommand, UNAPI_ERR_NO_DATA);
                    }
                    else {
                      // Stream data from web to file
                      stream = http.getStreamPtr();
                      while (http.connected() && (http.getSize() > 0 || http.getSize() == -1)) {
                          size_t size = stream->available();
                          if (size) {
                              int c = stream->readBytes(buffer, ((size > sizeof(buffer)) ? sizeof(buffer) : size));
                              g_certUploadFile.write(buffer, c);
                          }
                      }
                      g_certUploadFile.close();
                      // File received, now lets do the magic
                      char header[12] = {0};
                      size_t headerRead = 0;
                      File tt = FFat.open("/cert_upload.tmp", "r");
                      if (tt)
                      {
                        headerRead = tt.readBytes(header, 11);
                        tt.close();
                        const char* ttargetPath = "/certs.bin";  // mbedTLS bundle (default)
                        if (headerRead >= 11 && memcmp(header, "-----BEGIN ", 11) == 0)
                          ttargetPath = "/ca.pem";               // PEM text

                        if (FFat.exists(ttargetPath)) FFat.remove(ttargetPath);
                        if (FFat.rename("/cert_upload.tmp", ttargetPath))
                        {
                          // Drop in-memory cached certs so loadCACertForClient() reloads
                          if (g_caPem)    { free(g_caPem);    g_caPem = NULL;    g_caPemLen = 0; }
                          if (g_caBundle) { free(g_caBundle); g_caBundle = NULL; g_caBundleLen = 0; }
                          SendQuickResponse(btCommand, UNAPI_ERR_OK);
                          // No ESP.restart() — cert update is hot-applied.
                        }
                        else
                          SendQuickResponse(btCommand, UNAPI_ERR_NO_DATA);
                      }
                      else
                        SendQuickResponse(btCommand, UNAPI_ERR_NO_DATA);
                    }
                  }
                  else {
                    // if not available means version is fine
                    if  ((httpCode == HTTP_CODE_NO_CONTENT) || (httpCode == HTTP_CODE_NOT_MODIFIED))
                      SendQuickResponse(btCommand,UNAPI_ERR_INV_OPER);
                    else
                      SendQuickResponse(btCommand, UNAPI_ERR_NO_DATA);
                  }
                  bHTTPTransfer = false;
                }
              }
            }
            if(!bOkParam)
              SendQuickResponse(btCommand,UNAPI_ERR_INV_PARAM);
          }
        break;
        case CUSTOM_F_CONNECT_AP:
        {
          bool bSentRsp = false;
          bOkParam = false;
          bPWD = false;

          if (uiCmdDataLen <3)
            SendQuickResponse(btCommand,UNAPI_ERR_INV_PARAM);
          else
          {
            for (iAPItemI=0; (iAPItemI<33)&&(iAPItemI<uiCmdDataLen); iAPItemI++)
            {
              ucSSID[iAPItemI]=btCommandData[iAPItemI];
              if (btCommandData[iAPItemI]==0)
              {
                bOkParam = true;
                iAPItemI++;
                break;
              }
            }

            if (bOkParam)
            {
              if (iAPItemI<uiCmdDataLen) //still more data?
              {
                //Yes
                bPWD = true;
                iPWDCount=0;
                do
                {
                    ucPWD[iPWDCount]=btCommandData[iAPItemI];
                    iAPItemI++;
                    iPWDCount++;
                }
                while ((iAPItemI<uiCmdDataLen)&&(iPWDCount<64));
                ucPWD[iPWDCount]=0;
              }
              WiFi.disconnect();
              delay(50);
              yield();
              if (bPWD)
                WiFi.begin((const char*)ucSSID,(const char*)ucPWD);
              else
                WiFi.begin((const char*)ucSSID);

              unsigned long ulTimeOut = millis() + 20000;
              do
              {
                wl_status_t APsts;
                APsts = WiFi.status();
                if (APsts == WL_CONNECTED)
                {
                  SendQuickResponse(btCommand,0);
                  bSentRsp = true;
                  break;
                }
                else if (APsts == WL_CONNECT_FAILED)
                {
                  SendQuickResponse(btCommand,UNAPI_ERR_NO_NETWORK);
                  bSentRsp = true;
                  break;
                }
                yield();
                delay(100);  // let the WiFi task run; yield() alone is too tight on ESP32
              }
              while (ulTimeOut>millis());
              if (!bSentRsp)
                SendQuickResponse(btCommand,UNAPI_ERR_NO_NETWORK);
            }
            else
              SendQuickResponse(btCommand,UNAPI_ERR_INV_PARAM);
          }
        }
        break;
        case SSH_GET_CAPAB:
          if ((uiCmdDataLen != 1) || (btCommandData[0]==0) || (btCommandData[0]>1))
            SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          else
          {
            Serial.write(btCommand);
            Serial.write(UNAPI_ERR_OK);
            Serial.write(0);
            Serial.write(6);
            // Capability flags ENABLED:
            // 0 - PTY
            // 3 - RAW
            // 8 - Built-in TCP/IP
            // 9 - Connection pool shared with built-in TCP/IP
            // 10 - Support Public Key Authentication
            // 11 - Support Keyboard-Interactive Authentication (it is here, tested, but seems libssh ESP32 has a bug with it, did not work for me, YMMV)
            // 12 - Support non ANSI code filtering on PTY
            // 13 - Host key verification (SSH_ADD_KNOWN_HOST)
            // 14 - Support Key Import/Export (SSH_KEY_IMPORT, SSH_KEY_EXPORT)
            Serial.write(B00001001); //flags LSB
            Serial.write(B01111111); //flags MSB (bits 10 and 14 now set)
            Serial.write(4); //Max 4 simultaneous SSH conns
            Serial.write(4 - checkOpenConnections()); //Free SSH conns
            Serial.write(0x00); //DE LSB = 2048 max data per call
            Serial.write(0x08); //DE MSB = 2048
          }
        break;
        case TCPIP_GET_CAPAB:
          if ((uiCmdDataLen != 1) || (btCommandData[0]==0) || (btCommandData[0]>4))
            SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          else
          {
            Serial.write(btCommand);
            Serial.write(UNAPI_ERR_OK);
            Serial.write(0);
            switch (btCommandData[0])
            {
              case TCPIP_GET_CAPAB_FLAGS:
                Serial.write(5);
                // Capability flags ENABLED:
                // 2 - Resolve host names by querying a DNS server
                // 3 - Open TCP connections in active mode
                // 5 - Open TCP connections in passive mode w/o specified remote socket
                //10 - Open UDP connections  
                //14 - Automatically obtain the IP addresses, by using DHCP or an equivalent protocol

                // Capability flags DISABLED:
                // 0 - Send ICMP echo messages (PINGs) and retrieve the answers
                // 1 - Resolve host names by querying local host file or database
                // 4 - Open TCP connections in passive mode with specified remote socket 
                // 6 - Send and receive TCP urgent data
                // 7 - Explicitly set the PUSH bit when sending TCP data
                // 8 - Send data to a TCP connection before the ESTABLISHED state is reached
                // 9 - Discard the output buffers of a TCP connection
                //11 - Open RAW IP connections
                //12 - Explicitly set the TTL and TOS for outgoing datagrams
                //13 - Explicitly set the automatic reply to PINGs on or off 
                //15 - Get the TTL and ToS for outgoing datagrams
                Serial.write(B00101100); //flags LSB
                Serial.write(B01000100); //flags MSB
                // Features flags ENABLED:
                // 1 - Physical link is wireless
                // 2 - Connection pool is shared by TCP, UDP and raw IP
                // 4 - The TCP/IP handling code is assisted by external hardware
                // 7 - IP datagram fragmentation is supported
                Serial.write(B10010110); //flags LSB
                // 10 TCPIP_DNS_Q is a blocking operation
                // 11 TCPIP_TCP_OPEN is a blocking operation
                // 12 The server certificate can be verified when opening a TCP connection with TLS in TCPIP_TCP_OPEN
                Serial.write(B00011100); //flags MSB
                // Link level - 4 - WiFi
                Serial.write(4);
              break;
              case TCPIP_GET_CAPAB_CONN:
                Serial.write(6);
                Serial.write(4); //Max 4 simultaneous TCP conns
                Serial.write(4); //Max 4 simultaneous UDP conns
                Serial.write(4 - checkOpenConnections()); //Free TCP conns
                Serial.write(4 - checkOpenConnections()); //Free UDP conns
                Serial.write(0); //Raw TCP not supported
                Serial.write(0); //Raw TCP not supported
              break;
              case TCPIP_GET_CAPAB_DGRAM:
                Serial.write(4);
                btTmp = 1500 & 0xff;
                Serial.write(btTmp); // LSB max incoming dg size
                btTmp = (1500 >> 8) & 0xff;
                Serial.write(btTmp); // MSB max incoming dg size
                btTmp = 2048 & 0xff;
                Serial.write(btTmp); // LSB max outgoing dg size
                btTmp = (2048 >> 8) & 0xff;
                Serial.write(btTmp); // MSB max outgoing dg size
              break;
              case TCPIP_GET_SECONDARY_CAPAB_FLAGS:
              Serial.write(5);
              //Secondary Capabilities enabled:
              //Bit 0: Automatically obtain the local IP address, subnet mask and default gateway, by using DHCP or an equivalent protocol                           
              //Bit 1: Automatically obtain the IP addresses of the DNS servers, by using DHCP or an equivalent protocol
              //Bit 2: Manually set the local IP address
              //Bit 4: Manually set the subnet mask IP address
              //Bit 5: Manually set the default gateway IP address
              //Bit 6: Manually set the primary DNS server IP address
              //Bit 7: Manually set the secondary DNS server IP address
              //Bit 8: Use TLS in TCP active connections
              //Secondary Capabilities disabled:
              //Bit 3: Manually set the peer IP address
              //Bit 9: Use TLS in TCP passive connections
              //Bits 11-15: Unused
              Serial.write(B11110111); //flags LSB
              Serial.write(B00000001); //flags MSB (bit 8 + bit 10)
              // Secondary features flags currently not defined, all 0
              Serial.write(0);
              Serial.write(0);
              // Unused, left to make driver easier / simpler
              Serial.write(0);
              break;
            }
          }
        break;
        case TCPIP_GET_IPINFO:
          if ((uiCmdDataLen != 1) || (btCommandData[0]==0) || (btCommandData[0]>6))
            SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          else
          {
            WaitConnectionIfNeeded(false);
            switch (btCommandData[0])
            {
              case TCPIP_GET_IPINFO_LOCALIP:
                externalIP = WiFi.localIP();
              break;
              case TCPIP_GET_IPINFO_PEERIP:
                externalIP = IPAddress(0,0,0,0);
              break;
              case TCPIP_GET_IPINFO_SUBNETMASK:
                externalIP = WiFi.subnetMask();
              break;
              case TCPIP_GET_IPINFO_GATEWAY:
                btIPRet[0] = externalIP = WiFi.gatewayIP();
              break;
              case TCPIP_GET_IPINFO_PRIMDNS:
                externalIP = WiFi.dnsIP(0);
              break;
              case TCPIP_GET_IPINFO_SECDNS:
                externalIP = WiFi.dnsIP(1);
              break;
            }
            uint8_t ipBytes[4]; ipToBytes(externalIP, ipBytes);
            SendResponse(btCommand, UNAPI_ERR_OK, 4, ipBytes);
          }
          break;

        case TCPIP_NET_STATE:
          if (uiCmdDataLen != 0)
            SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          else
          {
            unsigned char ucNetState;
            switch (WiFi.status())
            {
              case WL_CONNECTED:
                ucNetState=2; //Connection Open
              break;
              case WL_IDLE_STATUS:
                ucNetState=1; //possibly opening
              break;
              case WL_DISCONNECTED:
              case WL_NO_SSID_AVAIL:
              case WL_CONNECT_FAILED:
                ucNetState=0; //closed
              break;
              default:
                ucNetState=0; //Unknown as we can't translate, so just say closed
              break;
            }
            SendResponse(btCommand,UNAPI_ERR_OK,1,&ucNetState);
          }
          break;

        case TCPIP_DNS_Q_NEW:
          {
            unsigned char ucIsIp = true;
            unsigned char ucDirectIp[4];
            unsigned char *ucDQNstrstr;
            unsigned int uiDQNi;
            unsigned char ucDQNflags = btCommandData[0];
            unsigned char ucPoints = 0;
            if ((uiCmdDataLen < 2)|| (ucDQNflags&0xf8))
              SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
            else
            {
              btCommandData[uiCmdDataLen]=0; //zero terminate the DNS strings           
              // Check if it is an IP or something to resolve
              if (uiCmdDataLen<17) // 123.567.901.345 -> if it is more than 15 bytes long, remember CmdDataLen includes the first byte that is the flag
              {
                for (uiDQNi = 1; uiDQNi < uiCmdDataLen; ++uiDQNi)
                {
                  if ((btCommandData[uiDQNi]<'0')||(btCommandData[uiDQNi]>'9')) // not a digit
                  {
                    if (btCommandData[uiDQNi]=='.')
                      ++ucPoints;
                    else
                    {
                      ucIsIp = false;
                      break;
                    }
                    if (ucPoints>3)
                    {
                      ucIsIp = false;
                      break;
                    }
                  }
                }
                if (ucPoints == 3) //ok, if it is a valid IP address, it must have three points, otherwise it is not an IP address
                {
                  ucDQNstrstr = &btCommandData[1];
                  if (atoi((const char*)ucDQNstrstr)<0x100)
                  {
                    ucDirectIp[0] = (unsigned char)atoi((const char*)ucDQNstrstr);
                    ucDQNstrstr = (unsigned char*) strstr ((const char*)ucDQNstrstr,".");
                    if ((ucDQNstrstr) && (atoi((const char*)&ucDQNstrstr[1])<0x100))
                    {
                      ucDirectIp[1] = (unsigned char)atoi((const char*)&ucDQNstrstr[1]);
                      ++ucDQNstrstr;
                      ucDQNstrstr = (unsigned char*) strstr ((const char*)ucDQNstrstr,".");
                      if ((ucDQNstrstr) && (atoi((const char*)&ucDQNstrstr[1])<0x100))
                      {
                        ucDirectIp[2] = atoi((const char*)&ucDQNstrstr[1]);
                        ++ucDQNstrstr;
                        ucDQNstrstr = (unsigned char*) strstr ((const char*)ucDQNstrstr,".");
                        if ((ucDQNstrstr) && (atoi((const char*)&ucDQNstrstr[1])<0x100))
                        {
                          ucDirectIp[3] = atoi((const char*)&ucDQNstrstr[1]);
                          ucIsIp = true;
                        }
                        else
                          ucIsIp = false;
                      }
                      else
                        ucIsIp = false;
                    }
                    else
                      ucIsIp = false;
                  }
                  else
                    ucIsIp = false;
                }
                else
                  ucIsIp = false;
              }
              else
                ucIsIp = false;
  
              if ((ucDQNflags&2)&&(!ucIsIp))
                SendResponse(btCommand,UNAPI_ERR_INV_IP,0,0);
              else
              {
                WaitConnectionIfNeeded();
                if (ucIsIp)
                  SendResponse(btCommand,UNAPI_ERR_OK,4,&ucDirectIp[0]);
                else
                {
                  if(WiFi.hostByName((const char*)&btCommandData[1],DNSQueryIP))
                  {
                    if (DNSQueryIP == IPAddress(0,0,0,0) || DNSQueryIP == IPAddress(255,255,255,255))
                      SendResponse(btCommand,UNAPI_ERR_DNS,0,0);
                    else
                    {
                        uint8_t ipBytes[4]; ipToBytes(DNSQueryIP, ipBytes);
                        SendResponse(btCommand, UNAPI_ERR_OK, 4, ipBytes);
                    }
                  }
                  else
                    SendResponse(btCommand,UNAPI_ERR_DNS,0,0);
                }
              }
            }
          }
          break;

        case TCPIP_DNS_Q:
          if (uiCmdDataLen < 1)
            SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          else
          {
            btCommandData[uiCmdDataLen]=0; //zero terminate the DNS strings
            WaitConnectionIfNeeded();
            if(WiFi.hostByName((const char*)btCommandData,DNSQueryIP))
            {
              if (DNSQueryIP == IPAddress(0,0,0,0) || DNSQueryIP == IPAddress(255,255,255,255))
                SendResponse(btCommand,UNAPI_ERR_DNS,0,0);
              else
              {
                uint8_t ipBytes[4]; ipToBytes(DNSQueryIP, ipBytes);
                SendResponse(btCommand, UNAPI_ERR_OK, 4, ipBytes);
              }
            }
            else
              SendResponse(btCommand,UNAPI_ERR_DNS,0,0);
          }
        break;

        case TCPIP_TCP_OPEN:
          externalIP[0] = btCommandData[0];
          externalIP[1] = btCommandData[1];
          externalIP[2] = btCommandData[2];
          externalIP[3] = btCommandData[3];
          uiCMDRemotePort = btCommandData[4] + btCommandData[5]*256;
          uiCMDLocalPort = btCommandData[6] + btCommandData[7]*256;
          btCMDPassive = btCommandData[10];
          btCMDBeginRet=0;

          if (btCMDPassive & 2)
            btCMDTransient = 0; //set, so resident
          else
            btCMDTransient = 1; //clear, so transient

          WaitConnectionIfNeeded(false);

          if ((uiCmdDataLen < 11) || (uiCMDLocalPort==0) || \
              (btCMDPassive & 0xf0) || ( (btCMDPassive & 4) && (uiCmdDataLen <12) ) || ( (btCMDPassive & 1) && (btCMDPassive & 4) ) || ( ((btCMDPassive & 1) == 0) && ((btCMDPassive & 4) ==0) && (btCMDPassive&8) ) || 
              ( ((btCMDPassive & 1) == 0) && ( (externalIP[0] | externalIP[1] | externalIP[2] | externalIP[3]) == 0) ) || //Active connection remote IP MUST be other than 0.0.0.0
              ( ((btCMDPassive & 1) == 1) && ( (externalIP[0] | externalIP[1] | externalIP[2] | externalIP[3]) != 0) ) )//Passive connection remote IP MUST be 0.0.0.0
            SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          else if (WiFi.status() != WL_CONNECTED) {
            SendResponse(btCommand,UNAPI_ERR_NO_NETWORK,0,0);
          }
          else
          {
            if (btCMDPassive & 1) 
            {
              //set, so passive connection
              if (checkOpenConnections()<4) 
              {
                for (uiForHelper=0;uiForHelper<4;uiForHelper++)
                  if (btConnections[uiForHelper] == CONN_CLOSED)
                    break;
                btCMDConnNumber = uiForHelper+1;
                CheckPassiveLocalPort(&uiCMDLocalPort);
                ServerList[uiForHelper] = IsPassivePortInUse(uiCMDLocalPort);
                uiLocalPorts[uiForHelper] = uiCMDLocalPort;
                uiListenPorts[uiForHelper] = uiCMDLocalPort;
                btConnections[uiForHelper] = CONN_TCP_PASSIVE;
                btIsTransient[uiForHelper] = btCMDTransient;
                SendResponse(btCommand,UNAPI_ERR_OK,1,&btCMDConnNumber);
              }
              else
                SendResponse(btCommand,UNAPI_ERR_NO_FREE_CONN,0,0);
            }
            else
            {
              if (CheckActiveLocalPort(&uiCMDLocalPort))
              {
                if (btCMDPassive&4) //TLS?
                {
                  if ((bTLSInUse)||(checkOpenConnections()>=4))
                    //TODO: can we have more than 1 TLS connection on ESP32?
                    SendResponse(btCommand,UNAPI_ERR_NO_FREE_CONN,0,0);
                  else
                  {
                    if (uiCmdDataLen > 12)
                    {
                      bHasHostName = true;
                      memset (uchTLSHost, 0, sizeof(uchTLSHost));
                      if ((uiCmdDataLen-11)>256)
                        memcpy (uchTLSHost,&btCommandData[11],(uiCmdDataLen-11));
                      else
                        memcpy (uchTLSHost,&btCommandData[11],255);
                    }
                    else
                      bHasHostName = false;

                    for (uiForHelper=0;uiForHelper<4;uiForHelper++)
                      if (btConnections[uiForHelper] == CONN_CLOSED)
                        break;
                    btCMDConnNumber = uiForHelper+1;
                    bTLSInUse = btCMDConnNumber;
                    ClientList[uiForHelper] = new WiFiClientSecure();
                    TClient1 = (WiFiClientSecure*)ClientList[uiForHelper];
                    ClientList[uiForHelper]->setNoDelay(!stDeviceConfiguration.ucNagle);

                    if (btCMDPassive&8) //validate certificates?
                       loadCACertForClient(TClient1);
                    else
                      TClient1->setInsecure();

                    if (bHasHostName)
                      btCMDBeginRet = TClient1->connect((const char*)uchTLSHost, uiCMDRemotePort);
                    else
                      btCMDBeginRet = TClient1->connect(externalIP,uiCMDRemotePort);
  
                    if (btCMDBeginRet)
                    {
                      uiLocalPorts[uiForHelper] = TClient1->localPort();
                      uiRemotePorts[uiForHelper] = TClient1->remotePort();
                      switch (btCMDConnNumber) 
                      {
                        case 1: ipToBytes(externalIP, btIPConnection1); break;
                        case 2: ipToBytes(externalIP, btIPConnection2); break;
                        case 3: ipToBytes(externalIP, btIPConnection3); break;
                        case 4: ipToBytes(externalIP, btIPConnection4); break;
                      }
                      {
                        int rcvbuf = 4096;
                        TClient1->setSocketOption(SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf));
                      }
                      btConnections[uiForHelper] = CONN_TCP_TLS_A;
                      btIsTransient[uiForHelper] = btCMDTransient;
                      SendResponse(btCommand,UNAPI_ERR_OK,1,&btCMDConnNumber);
                    }
                    else
                    {
                      // TODO: instead of always returning ERR_TLS_OTHER, can we figure out error reason?
                      btCommandData[0] = 19;
                      delete ClientList[uiForHelper];
                      ClientList[uiForHelper] = NULL;
                      bTLSInUse = 0;
                      SendResponse(btCommand, UNAPI_ERR_NO_CONN, 1, btCommandData);
                    }
                  }
                }
                else //regular TCP
                {
                  //clear, so active connection
                  if (checkOpenConnections()<4) 
                  {
                    for (uiForHelper=0;uiForHelper<4;uiForHelper++)
                      if (btConnections[uiForHelper] == CONN_CLOSED)
                        break;
                    btCMDConnNumber = uiForHelper+1;
                    ClientList[uiForHelper] = new WiFiClient();
                    ClientList[uiForHelper]->setNoDelay(!stDeviceConfiguration.ucNagle);

                    btCMDBeginRet = ClientList[uiForHelper]->connect(externalIP,uiCMDRemotePort,uiCMDLocalPort);
                    if (btCMDBeginRet)
                    {
                      uiLocalPorts[uiForHelper] = ClientList[uiForHelper]->localPort();
                      uiRemotePorts[uiForHelper] = ClientList[uiForHelper]->remotePort();
                      switch (btCMDConnNumber) 
                      {
                        case 1: ipToBytes(externalIP, btIPConnection1); break;
                        case 2: ipToBytes(externalIP, btIPConnection2); break;
                        case 3: ipToBytes(externalIP, btIPConnection3); break;
                        case 4: ipToBytes(externalIP, btIPConnection4); break;
                      }
                      {
                        int rcvbuf = 4096;
                        ClientList[uiForHelper]->setSocketOption(SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf));
                      }
                      btConnections[uiForHelper] = CONN_TCP_ACTIVE;
                      btIsTransient[uiForHelper] = btCMDTransient;
                      SendResponse(btCommand,UNAPI_ERR_OK,1,&btCMDConnNumber);
                    }
                    else // (!btCMDBeginRet)
                    {
                      btCommandData[0]=0; //unknown reason
                      SendResponse(btCommand,UNAPI_ERR_NO_CONN,1,btCommandData);
                    }
                  }
                  else
                    SendResponse(btCommand,UNAPI_ERR_NO_FREE_CONN,0,0);
                }
              }
              else
                SendResponse(btCommand,UNAPI_ERR_CONN_EXISTS,0,0);
            }
          }
        break;

        case TCPIP_UDP_OPEN:
          uiCMDLocalPort = btCommandData[0] + btCommandData[1]*256;
          btCMDTransient = btCommandData[2];
          btCMDBeginRet=0;
          if ((uiCmdDataLen != 3) || (uiCMDLocalPort==0) || ((uiCMDLocalPort>=0xfff0)&&(uiCMDLocalPort!=0xffff)) || (btCMDTransient>1) )
            SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          else if (WiFi.status() != WL_CONNECTED)
            SendResponse(btCommand,UNAPI_ERR_NO_NETWORK,0,0);
          else
          {
            if (CheckActiveLocalPort(&uiCMDLocalPort))
            {
              if (checkOpenConnections()<4)
              {
                for (uiForHelper=0;uiForHelper<4;uiForHelper++)
                  if (btConnections[uiForHelper] == CONN_CLOSED)
                    break;
                btCMDConnNumber = uiForHelper+1;
                switch (btCMDConnNumber)
                {
                  case 1:
                    btCMDBeginRet = Udp1.begin(uiCMDLocalPort);
                  break;
                  case 2:
                    btCMDBeginRet = Udp2.begin(uiCMDLocalPort);
                  break;
                  case 3:
                    btCMDBeginRet = Udp3.begin(uiCMDLocalPort);
                  break;
                  case 4:
                    btCMDBeginRet = Udp4.begin(uiCMDLocalPort);
                  break;
                }
                if (!btCMDBeginRet)
                  SendResponse(btCommand,UNAPI_ERR_CONN_EXISTS,0,0);
                else
                {
                  btConnections[uiForHelper] = CONN_UDP;
                  uiLocalPorts[uiForHelper] = uiCMDLocalPort;
                  btIsTransient[uiForHelper] = btCMDTransient;
                  SendResponse(btCommand,UNAPI_ERR_OK,1,&btCMDConnNumber);
                }
              }
              else
                SendResponse(btCommand,UNAPI_ERR_NO_FREE_CONN,0,0);
            }
            else
              SendResponse(btCommand,UNAPI_ERR_CONN_EXISTS,0,0);
          }
        break;

        case TCPIP_TCP_CLOSE:
        case TCPIP_TCP_ABORT:
          btCMDConnNumber = btCommandData[0];
          if (uiCmdDataLen != 1)
            SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          else
          {
            if (btCMDConnNumber>4)
              SendResponse(btCommand,UNAPI_ERR_NO_CONN,0,0);
            else
            {
              if (btCMDConnNumber) //Not close all
              {
                if ( (btConnections[btCMDConnNumber-1] == CONN_TCP_ACTIVE) || (btConnections[btCMDConnNumber-1] == CONN_TCP_PASSIVE) || (btConnections[btCMDConnNumber-1] == CONN_TCP_TLS_A))
                {
                  CloseTcpConnection (btCMDConnNumber);
                  SendResponse(btCommand,UNAPI_ERR_OK,0,0);
                }
                else
                  SendResponse(btCommand,UNAPI_ERR_NO_CONN,0,0);
              }
              else //Close all open transient
              {
                for (uiForHelper=0;uiForHelper<4;uiForHelper++)
                {
                  if ( ((btConnections[uiForHelper] == CONN_TCP_ACTIVE) || (btConnections[uiForHelper] == CONN_TCP_PASSIVE) || (btConnections[uiForHelper] == CONN_TCP_TLS_A)) && (btIsTransient[uiForHelper]) )
                    CloseTcpConnection ((byte)(uiForHelper+1));
                }
                SendResponse(btCommand,UNAPI_ERR_OK,0,0);
              }
            }
          }
        break;

        case TCPIP_UDP_CLOSE:
          btCMDConnNumber = btCommandData[0];
          if (uiCmdDataLen != 1)
            SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          else
          {
            if (btCMDConnNumber>4)
              SendResponse(btCommand,UNAPI_ERR_NO_CONN,0,0);
            else
            {
              if (btCMDConnNumber) //Not close all
              {
                if (btConnections[btCMDConnNumber-1] == CONN_UDP)
                {
                  CloseUdpConnection (btCMDConnNumber);
                  SendResponse(btCommand,UNAPI_ERR_OK,0,0);
                }
                else
                  SendResponse(btCommand,UNAPI_ERR_NO_CONN,0,0);
              }
              else //Close all open transient
              {
                for (uiForHelper=0;uiForHelper<4;uiForHelper++)
                {
                  if ( (btConnections[uiForHelper] == CONN_UDP) && (btIsTransient[uiForHelper]) )
                    CloseUdpConnection ((byte)(uiForHelper+1));
                }
                SendResponse(btCommand,UNAPI_ERR_OK,0,0);
              }
            }
          }
        break;

        case TCPIP_TCP_STATE:
          btCMDConnNumber = btCommandData[0];
          if (uiCmdDataLen != 1)
            SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          else
          {
            if ((btCMDConnNumber>4)||(btCMDConnNumber==0))
              SendResponse(btCommand,UNAPI_ERR_NO_CONN,0,0);
            else
            {
              TcpState(btCMDConnNumber);
            }
          }
        break;

        case TCPIP_UDP_STATE:
          btCMDConnNumber = btCommandData[0];
          if (uiCmdDataLen != 1)
            SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          else
          {
            if ((btCMDConnNumber>4)||(btCMDConnNumber==0))
              SendResponse(btCommand,UNAPI_ERR_NO_CONN,0,0);
            else
            {
              if (btConnections[btCMDConnNumber-1] == CONN_UDP)
              {
                switch (btCMDConnNumber)
                {
                  case 1:
                    iLenght = Udp1.parsePacket();
                  break;
                  case 2:
                    iLenght = Udp2.parsePacket();
                  break;
                  case 3:
                    iLenght = Udp3.parsePacket();
                  break;
                  case 4:
                    iLenght = Udp4.parsePacket();
                  break;
                }

                btCommandData[0] = (byte)(uiLocalPorts[btCMDConnNumber-1]&0xff);
                btCommandData[1] = (byte)((uiLocalPorts[btCMDConnNumber-1]>>8)&0xff);
                if (iLenght)
                  btCommandData[2]=1; //at least one packet
                else
                  btCommandData[2]=0; //no packet
                btCommandData[3] = (byte)(iLenght&0xff);
                btCommandData[4] = (byte)((iLenght>>8)&0xff);
                SendResponse(btCommand,UNAPI_ERR_OK,5,btCommandData);
              }
              else
                SendResponse(btCommand,UNAPI_ERR_NO_CONN,0,0);
            }
          }
        break;

        case TCPIP_TCP_SEND:
          if ((uiCmdDataLen < 3)||(btCommandData[1]&0xfe)) //only bit 1 is accepted
            SendResponse(btCommand,UNAPI_ERR_NO_CONN,0,0);
          else if (WiFi.status() != WL_CONNECTED)
            SendResponse(btCommand,UNAPI_ERR_NO_NETWORK,0,0);
          else
          {
            if ((btCommandData[0]>4)||(btCommandData[0]==0))
              SendResponse(btCommand,UNAPI_ERR_NO_CONN,0,0);
            else
            {
              TcpSend(btCommandData[0],&btCommandData[2],uiCmdDataLen-2);
            }
          }
        break;

        case TCPIP_UDP_SEND:
          btCMDConnNumber = btCommandData[0];
          externalIP[0] = btCommandData[1];
          externalIP[1] = btCommandData[2];
          externalIP[2] = btCommandData[3];
          externalIP[3] = btCommandData[4];
          ui16Port = btCommandData[5] + (btCommandData[6]*256);
          if (uiCmdDataLen < 8)
            SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          else
          {
            if ((btCMDConnNumber>4)||(btCMDConnNumber==0))
              SendResponse(btCommand,UNAPI_ERR_NO_CONN,0,0);
            else
            {
              if (btConnections[btCMDConnNumber-1] == CONN_UDP)
              {
                if (WiFi.status() == WL_CONNECTED)
                {
                  switch (btCMDConnNumber)
                  {
                    case 1:
                      Udp1.beginPacket(externalIP,ui16Port);
                      Udp1.write(&btCommandData[7],uiCmdDataLen-7);
                      Udp1.endPacket();
                    break;
                    case 2:
                      Udp2.beginPacket(externalIP,ui16Port);
                      Udp2.write(&btCommandData[7],uiCmdDataLen-7);
                      Udp2.endPacket();
                    break;
                    case 3:
                      Udp3.beginPacket(externalIP,ui16Port);
                      Udp3.write(&btCommandData[7],uiCmdDataLen-7);
                      Udp3.endPacket();
                    break;
                    case 4:
                      Udp4.beginPacket(externalIP,ui16Port);
                      Udp4.write(&btCommandData[7],uiCmdDataLen-7);
                      Udp4.endPacket();
                    break;
                  }
                  yield();
                  SendResponse(btCommand,UNAPI_ERR_OK,0,0);
                }
                else
                  SendResponse(btCommand,UNAPI_ERR_NO_CONN,0,0);
              }
              else
                  SendResponse(btCommand,UNAPI_ERR_NO_NETWORK,0,0);
            }
          }
        break;

        case TCPIP_TCP_RCV:
          btCMDConnNumber = btCommandData[0];
          ui16RcvSize = btCommandData[1] + (btCommandData[2]*256);
          if (ui16RcvSize>2048)
            ui16RcvSize = 2048;
          if (uiCmdDataLen != 3)
            SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          else
          {
            if ((btCMDConnNumber>4)||(btCMDConnNumber==0))
              SendResponse(btCommand,UNAPI_ERR_NO_CONN,0,0);
            else
            {
              TcpReceive(btCMDConnNumber,ui16RcvSize,btCommandData);
            }
          }
        break;

        case TCPIP_UDP_RCV:
          btCMDConnNumber = btCommandData[0];
          ui16RcvSize = btCommandData[1] + (btCommandData[2]*256);
          if (uiCmdDataLen != 3)
            SendResponse(btCommand,UNAPI_ERR_INV_PARAM,0,0);
          else
          {
            if ((btCMDConnNumber>4)||(btCMDConnNumber==0))
              SendResponse(btCommand,UNAPI_ERR_NO_CONN,0,0);
            else
            {
              if (btConnections[btCMDConnNumber-1] == CONN_UDP)
              {
                switch (btCMDConnNumber)
                {
                  case 1:
                    iLenght = Udp1.parsePacket();
                    if (iLenght)
                    {
                      externalIP = Udp1.remoteIP();
                      btCommandData[1] = externalIP[0];
                      btCommandData[2] = externalIP[1];
                      btCommandData[3] = externalIP[2];
                      btCommandData[4] = externalIP[3];
                      btCommandData[5] = (byte)(Udp1.remotePort()&0xff);
                      btCommandData[6] = (byte)((Udp1.remotePort()>>8)&0xff);
                      iLenght = Udp1.read(&btCommandData[7],iLenght);
                      if (iLenght>ui16RcvSize)
                        iLenght = ui16RcvSize;
                    }
                  break;
                  case 2:
                    iLenght = Udp2.parsePacket();
                    if (iLenght)
                    {
                      externalIP = Udp2.remoteIP();
                      btCommandData[1] = externalIP[0];
                      btCommandData[2] = externalIP[1];
                      btCommandData[3] = externalIP[2];
                      btCommandData[4] = externalIP[3];
                      btCommandData[5] = (byte)(Udp2.remotePort()&0xff);
                      btCommandData[6] = (byte)((Udp2.remotePort()>>8)&0xff);
                      iLenght = Udp2.read(&btCommandData[7],MAX_CMD_DATA_LEN);
                      if (iLenght>ui16RcvSize)
                        iLenght = ui16RcvSize;
                    }
                  break;
                  case 3:
                    iLenght = Udp3.parsePacket();
                    if (iLenght)
                    {
                      externalIP = Udp3.remoteIP();
                      btCommandData[1] = externalIP[0];
                      btCommandData[2] = externalIP[1];
                      btCommandData[3] = externalIP[2];
                      btCommandData[4] = externalIP[3];
                      btCommandData[5] = (byte)(Udp3.remotePort()&0xff);
                      btCommandData[6] = (byte)((Udp3.remotePort()>>8)&0xff);
                      iLenght = Udp3.read(&btCommandData[7],MAX_CMD_DATA_LEN);
                      if (iLenght>ui16RcvSize)
                        iLenght = ui16RcvSize;
                    }
                  break;
                  case 4:
                    iLenght = Udp4.parsePacket();
                    if (iLenght)
                    {
                      externalIP = Udp4.remoteIP();
                      btCommandData[1] = externalIP[0];
                      btCommandData[2] = externalIP[1];
                      btCommandData[3] = externalIP[2];
                      btCommandData[4] = externalIP[3];
                      btCommandData[5] = (byte)(Udp4.remotePort()&0xff);
                      btCommandData[6] = (byte)((Udp4.remotePort()>>8)&0xff);
                      iLenght = Udp4.read(&btCommandData[7],MAX_CMD_DATA_LEN);
                      if (iLenght>ui16RcvSize)
                        iLenght = ui16RcvSize;
                    }
                  break;
                }
                if (iLenght)
                  iLenght = iLenght + 6;
                if (iLenght)
                  SendResponse(btCommand,UNAPI_ERR_OK,iLenght,&btCommandData[1]);
                else
                  SendResponse(btCommand,UNAPI_ERR_NO_DATA,0,0);                
              }
              else
                SendResponse(btCommand,UNAPI_ERR_NO_CONN,0,0);
            }
          }
        break;

        case TCPIP_HTTP_OPEN:
          if (uiCmdDataLen > 0) {
            btCommandData[uiCmdDataLen] = 0;
            SendResponse(btCommand, http_open((const char *)btCommandData), 0, 0);
          } else {
            SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
          }
          break;

        case TCPIP_HTTP_RECEIVE:
        {
          if (uiCmdDataLen == 1) {
            byte result = http_receive(btCommandData, &uiCmdDataLen, (btCommandData[0] > 0));
            SendResponse(btCommand, result, uiCmdDataLen, btCommandData);
          } else {
            SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
          }
        }
          break;

        case TCPIP_HTTP_CLOSE:
          if (uiCmdDataLen == 0) {
            SendResponse(btCommand, http_close(UNAPI_ERR_OK), 0, 0);
          } else {
            SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
          }
          break;

        case SSH_OPEN:
        {
          byte connNum;
          byte result = sshOpen(btCommandData, uiCmdDataLen, &connNum);
          if (result == UNAPI_ERR_OK) {
            filter_ssh_buffer_inplace(connNum, NULL, NULL, true);
            btCommandData[0] = connNum;
            SendResponse(btCommand, result, 1, btCommandData);
          } else if (result == SSH_ERR_UNKNOWN_HOST) {
            btCommandData[0] = connNum;
            byte slot = connNum - 1;
            String encodedHash = base64::encode(sshPendingHash[slot], SSH_KNOWN_HOST_HASH_SIZE);
            memcpy(btCommandData + 1, encodedHash.c_str(), encodedHash.length());
            // don't want to send the padding
            btCommandData[encodedHash.length()] = 0x00;
            SendResponse(btCommand, result, encodedHash.length() + 1, btCommandData);
          } else {
            SendResponse(btCommand, result, 0, 0);
          }
        }
        break;

        case SSH_CLOSE:
        {
          if (uiCmdDataLen < 1) {
            SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
          } else if (btCommandData[0] == 0) {
            // SSH connections are not transient, must be closed individually
            SendResponse(btCommand, UNAPI_ERR_NO_CONN, 0, 0);
          } else {
            byte result = sshClose(btCommandData[0]);
            SendResponse(btCommand, result, 0, 0);
          }
        }
        break;

        case SSH_STATE:
        {
          if (uiCmdDataLen < 1) {
            SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
          } else {
            uint8_t state;
            uint16_t avail;
            byte result = sshState(btCommandData[0], &state, &avail);
            if (result == UNAPI_ERR_OK) {
              btCommandData[0] = state;
              btCommandData[1] = (uint8_t)(avail & 0xff);
              btCommandData[2] = (uint8_t)((avail >> 8) & 0xff);
              SendResponse(btCommand, result, 3, btCommandData);
            } else {
              SendResponse(btCommand, result, 0, 0);
            }
          }
        }
        break;

        case SSH_SEND:
        {
          if (uiCmdDataLen < 1) {
            SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
          } else {
            byte result = sshSend(btCommandData[0], btCommandData + 1, uiCmdDataLen - 1);
            SendResponse(btCommand, result, 0, 0);
          }
        }
        break;

        case SSH_RCV:
        {
          if (uiCmdDataLen < 3) {
            SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
          } else {
            uint16_t maxSize = btCommandData[1] + (btCommandData[2] * 256);
            if (maxSize > 2048) maxSize = 2048;
            uint16_t rcvLen;
            byte result = sshReceive(btCommandData[0], btCommandData, maxSize, &rcvLen);
            if (result == UNAPI_ERR_OK) {
              SendResponse(btCommand, result, rcvLen, btCommandData);
            } else {
              SendResponse(btCommand, result, 0, 0);
            }
          }
        }
        break;

        case SSH_TERM_TYPE:
        {
          if (uiCmdDataLen < 1) {
            SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
          } else {
            byte getSet = btCommandData[0];
            if (getSet == 0) {
              // GET
              btCommandData[0] = sshTermType;
              SendResponse(btCommand, UNAPI_ERR_OK, 1, btCommandData);
            } else if (getSet == 1) {
              // SET
              if (uiCmdDataLen < 2) {
                SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
              } else {
                byte result = sshSetTermType(btCommandData[1]);
                SendResponse(btCommand, result, 0, 0);
              }
            } else {
              SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
            }
          }
        }
        break;

        case SSH_WIN_SIZE:
        {
          if (uiCmdDataLen < 1) {
            SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
          } else {
            byte getSet = btCommandData[0];
            if (getSet == 0) {
              // GET
              btCommandData[0] = sshWinRow;
              btCommandData[1] = sshWinCol;
              SendResponse(btCommand, UNAPI_ERR_OK, 2, btCommandData);
            } else if (getSet == 1) {
              // SET
              if (uiCmdDataLen < 3) {
                SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
              } else {
                byte result = sshSetWinSize(btCommandData[1], btCommandData[2]);
                SendResponse(btCommand, result, 0, 0);
              }
            } else {
              SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
            }
          }
        }
        break;

        case SSH_AUTH_GET_CHALLENGE:
        {
          if (uiCmdDataLen < 1) {
            SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
          } else {
            byte prompts, echoFlags;
            unsigned int chalLen;
            // btCommandData[0] = conn number
            // Reserve 2 bytes for response header (prompts, echoFlags)
            byte result = sshAuthGetChallenge(
                btCommandData[0], btCommandData + 2, MAX_CMD_DATA_LEN - 2,
                &prompts, &echoFlags, &chalLen);
            if (result == UNAPI_ERR_OK) {
              btCommandData[0] = prompts;
              btCommandData[1] = echoFlags;
              SendResponse(btCommand, result, chalLen + 2, btCommandData);
            } else if (result == UNAPI_ERR_BUFFER) {
              btCommandData[0] = 0; // reserved
              btCommandData[1] = 0; // reserved
              btCommandData[2] = (byte)(chalLen & 0xFF);       // required size LSB
              btCommandData[3] = (byte)((chalLen >> 8) & 0xFF); // required size MSB
              SendResponse(btCommand, result, 4, btCommandData);
            } else if (result == SSH_ERR_AUTH_TRY_OTHER) {
              sshClose(btCommandData[0]);
              SendResponse(btCommand, result, 0, 0);
            } 
            else {
              SendResponse(btCommand, result, 0, 0);
            }
          }
        }
        break;

        case SSH_AUTH_RESPOND:
        {
          if (uiCmdDataLen < 2) {
            SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
          } else {
            // btCommandData[0] = conn number
            // btCommandData[1..] = response block
            byte result = sshAuthRespond(
                btCommandData[0], btCommandData + 1, uiCmdDataLen - 1);
            SendResponse(btCommand, result, 0, 0);
          }
        }
        break;

        case SSH_ADD_KNOWN_HOST:
        {
          if (uiCmdDataLen < 1) {
            SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
          } else {
            byte result = sshAddKnownHost(btCommandData[0]);
            SendResponse(btCommand, result, 0, 0);
          }
        }
        break;

        case SSH_KEY_GEN:
        {
          byte result = sshKeyGen();
          SendResponse(btCommand, result, 0, 0);
        }
        break;

        case SSH_KEY_EXPORT:
        {
          if (uiCmdDataLen < 3) {
            SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
            break;
          }
          byte what = btCommandData[0];                              // B
          unsigned int maxSize = btCommandData[1] | (btCommandData[2] << 8);  // HL
          if (maxSize > 2045) maxSize = 2045;
          unsigned int written;
          byte lastBlock;
          byte result = sshKeyExport(what, &btCommandData[3], maxSize, &written, &lastBlock);
          if (result == UNAPI_ERR_OK) {
            btCommandData[0] = (byte)(written & 0xFF);
            btCommandData[1] = (byte)((written >> 8) & 0xFF);
            btCommandData[2] = lastBlock;
            SendResponse(btCommand, result, written + 3, btCommandData);
          } else {
            SendResponse(btCommand, result, 0, 0);
          }
        }
        break;

        case SSH_KEY_IMPORT:
        {
          if (uiCmdDataLen < 4) {
            SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
            break;
          }
          byte flags = btCommandData[0];                              // C
          unsigned int dataLen = btCommandData[1] | (btCommandData[2] << 8);  // HL
          if (dataLen > 2048) dataLen = 2048;
          if (uiCmdDataLen < 3 + dataLen) {
            SendResponse(btCommand, UNAPI_ERR_INV_PARAM, 0, 0);
            break;
          }
          byte lastBlock = (flags & 0x01);
          byte result = sshKeyImport(lastBlock, btCommandData + 3, dataLen);
          SendResponse(btCommand, result, 0, 0);
        }
        break;

        case SSH_KEY_INFO:
        {
          bool wantFingerprint = (uiCmdDataLen >= 1) && (btCommandData[0] & 0x01);
          byte keyStatus;
          byte result = sshKeyInfo(wantFingerprint ? btCommandData + 1 : NULL, &keyStatus);
          if (result == UNAPI_ERR_OK) {
            btCommandData[0] = keyStatus;
            unsigned int respLen = 1;
            if (wantFingerprint && (keyStatus & 0x01)) {
              respLen += strlen((char*)(btCommandData + 1)) + 1;
            }
            SendResponse(btCommand, result, respLen, btCommandData);
          } else {
            SendResponse(btCommand, result, 0, 0);
          }
        }
        break;

        default:
          SendResponse(btCommand,UNAPI_ERR_NOT_IMP,0,0);
        break;
      }
      btCmdInternalStep = 0;
      btState = RX_PARSER_IDLE;
      break;
  }
  if (!stDeviceConfiguration.ucAlwaysOn)
    ScheduleTimeoutCheck();
}
void loop() {
  unsigned int uiI;

  displayTask();                // <-- refresca la pantalla (self-throttled 1/s, Display.ino)

  if (bDisableRadioPending) {
    bDisableRadioPending = false;
    DisableRadio();
  }

  if (Serial.available()) {
    g_lastUartMs = millis();          // actividad del enlace MSX (indicador de la pantalla)
    received_data_parser();
  }

  if ((!btReceivedCommand)&&(btReadyRetries))
  {
    if(longReadyTimeOut)
    {
      if (longReadyTimeOut<millis())
      {
        Serial.println("Ready");
        longReadyTimeOut = 0;
        --btReadyRetries;
      }
    }
    else
    {
      longReadyTimeOut = millis() + 5000;
    }
  }

  for (uiI=1;uiI<5;uiI++)
  {
    yield();
    if (btConnections[uiI-1] == CONN_TCP_PASSIVE && ServerList[uiI-1] != NULL)
    {
       WiFiClient newClient = ServerList[uiI-1]->available();
        if (newClient)
        {
            if (ClientList[uiI-1] == NULL) 
            {
                ClientList[uiI-1] = new WiFiClient(newClient);
                externalIP = newClient.remoteIP();
                uiRemotePorts[uiI-1] = newClient.remotePort();
                switch (uiI) 
                {
                    case 1: ipToBytes(externalIP, btIPConnection1); break;
                    case 2: ipToBytes(externalIP, btIPConnection2); break;
                    case 3: ipToBytes(externalIP, btIPConnection3); break;
                    case 4: ipToBytes(externalIP, btIPConnection4); break;
                }
            }
        }
    }
  }
}
