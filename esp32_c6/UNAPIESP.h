/*
UNAPIESP.h
    ESP32 UNAPI Implementation.
    Revision 1.00

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

This file, that is part of ESP8266 UNAPI Firmware program, is free
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
*/

#ifndef _UNAPIESP_H
#define _UNAPIESP_H

#define MAX_CMD_DATA_LEN 2148
#include "ESP32BOARDS.h"

struct ESPConfig {
  unsigned char ucConfigFileName[8];
  unsigned char ucStructVersion;
  unsigned char ucNagle;
  unsigned char ucAlwaysOn;
  unsigned int uiRadioOffTimer;
  unsigned char ucAutoClock;
  int iGMT;
  unsigned char ucBaudRate;
  unsigned char ucAutoUpdateFH;
};

enum CommandTypes {
  NO_COMMAND = 0,
  QUICK_COMMAND = 1,
  REGULAR_COMMAND = 2
};

enum RxDataParserStates {
  RX_PARSER_IDLE = 0,
  RX_PARSER_WAIT_DATA_SIZE,
  RX_PARSER_GET_DATA,
  RX_PARSER_PROCCESS_CMD
};

enum ConnectionStates {
  CONN_CLOSED = 0,
  CONN_UDP = 1,
  CONN_TCP_ACTIVE = 2,
  CONN_TCP_PASSIVE = 3,
  CONN_TCP_TLS_A = 4,
  CONN_SSH = 5
};

// IMPORTANT!!!!
// Never add any custom function lower than ' ' (0x20) or higher than DEL (0x7F)
// Command ranges 0x00 to 0x19 are reserved for TCP-IP UNAPI commands
// Command ranges 0x7F to 0xFF are reserved for SSH UNAPI commands and additional TCP-IP UNAPI commands not in spec (i.e.: http client)
enum CustomFunctions {
  CUSTOM_F_RESET = 'R',
  CUSTOM_F_RETRY_TX = 'r',
  CUSTOM_F_SCAN = 'S',
  CUSTOM_F_SCAN_R = 's',
  CUSTOM_F_CONNECT_AP = 'A',
  CUSTOM_F_CLEAR_AP = 'a',
  CUSTOM_F_GETBOARD = 'b',
  CUSTOM_F_FILE_BOARD = 'B',
  CUSTOM_F_SETBAUD = 'd',
  CUSTOM_F_UPDATE_FW = 'U',
  CUSTOM_F_UPDATE_CERTS = 'u',
  CUSTOM_F_GET_VER = 'V',
  CUSTOM_F_START_RS232_UPDATE = 'Z',
  CUSTOM_F_START_RS232_CERT_UPDATE = 'Y',
  CUSTOM_F_BLOCK_RS232_UPDATE = 'z',
  CUSTOM_F_END_RS232_UPDATE = 'E',
  CUSTOM_F_NO_DELAY = 'N',
  CUSTOM_F_DELAY = 'D',
  CUSTOM_F_INITCERTS = 'I',
  CUSTOM_F_WIFI_ON_TIMER_SET = 'T',
  CUSTOM_F_TURN_WIFI_OFF = 'O',
  CUSTOM_F_TURN_RS232_OFF = 'o',
  CUSTOM_F_QUERY_SETTINGS = 'Q',
  CUSTOM_F_QUERY_AUTOCLOCK = 'c',
  CUSTOM_F_SET_AUTOCLOCK = 'C',
  CUSTOM_F_GET_DATETIME = 'G',
  CUSTOM_F_WARMBOOT = 'W',
  CUSTOM_F_HOLDCONNECTION = 'H',
  CUSTOM_F_RELEASECONNECTION = 'h',
  CUSTOM_F_GETAPSTS = 'g',
  CUSTOM_F_QUERY = '?',
  // cinta virtual por stream (MSXnano/MSXimus, TapeWeb.ino)
  CUSTOM_F_TSX_LIST = 'L',      // {letra,pag,offset} -> listado del catalogo
  CUSTOM_F_TSX_PLAY = 'K',      // {letra,pag,idx} descarga+reproduce; vacio=STOP
  CUSTOM_F_TSX_STATUS = 'k',    // {} -> {busy,err,sentPag16,totalPag16}
  CUSTOM_F_TSX_UPLOAD = 'X',    // {size u32 LE} subida desde el MSX (SD offline)
  CUSTOM_F_TSX_UPBLOCK = 'x',   // {chunk} anexa; al completar convierte+reproduce
  CUSTOM_F_TSX_FIND = 'J'       // {texto} busca en el catalogo y reproduce el
  // --- Cache de descargas en la FFat del C6 (MSXimus, 31/08/2026) ---
  // LETRAS, como el resto de ordenes propias: el MSX habla con el ESP por los
  // puertos 6/7 de la FPGA (igual que la cinta web), SIN pasar por el driver
  // UNAPI de ducasp, que es una ROM de terceros dentro del pack.
  // Verificadas libres: F, f, P, p no las usa nadie.
  ,CUSTOM_F_CACHE_GET  = 'F'    // {url ASCIIZ} arranca la descarga a fichero
  ,CUSTOM_F_CACHE_STAT = 'f'    // {} -> {estado,err,bajados u32,total u32}
  ,CUSTOM_F_CACHE_PART = 'P'    // {off u32, len u16} -> len bytes del fichero
  ,CUSTOM_F_CACHE_PURGE= 'p'    // {} borra la cache
                                // 1er match; resp: [loadcmd u8][nombreZ ASCII]
};

// MUST NEVER GO BEYOND 33 for standard TCP-IP UNAPI functions
// MUST NEVER BE BELOW 129 for standard SSH UNAPI functions OR extended TCP-IP UNAPI functions
enum TcpipUnapiFunctions {
  TCPIP_GET_CAPAB = 1,
  TCPIP_GET_IPINFO = 2,
  TCPIP_NET_STATE = 3,
  TCPIP_SEND_ECHO = 4,
  TCPIP_RCV_ECHO = 5,
  TCPIP_DNS_Q = 6,
  TCPIP_DNS_Q_NEW = 206,
  TCPIP_DNS_S = 7,
  TCPIP_UDP_OPEN = 8,
  TCPIP_UDP_CLOSE = 9,
  TCPIP_UDP_STATE = 10,
  TCPIP_UDP_SEND = 11,
  TCPIP_UDP_RCV = 12,
  TCPIP_TCP_OPEN = 13,
  TCPIP_TCP_CLOSE = 14,
  TCPIP_TCP_ABORT = 15,
  TCPIP_TCP_STATE = 16,
  TCPIP_TCP_SEND = 17,
  TCPIP_TCP_RCV = 18,
  TCPIP_TCP_FLUSH = 19,
  TCPIP_RAW_OPEN = 20,
  TCPIP_RAW_CLOSE = 21,
  TCPIP_RAW_STATE = 22,
  TCPIP_RAW_SEND = 23,
  TCPIP_RAW_RCV = 24,
  TCPIP_CONFIG_AUTOIP = 25,
  TCPIP_CONFIG_IP = 26,
  TCPIP_CONFIG_TTL = 27,
  TCPIP_CONFIG_PING = 28,
  TCPIP_WAIT = 29,
  TCPIP_HTTP_OPEN = 200,
  TCPIP_HTTP_RECEIVE = 201,
  TCPIP_HTTP_CLOSE = 202
};

// MUST NEVER GO BEYOND 33 for standard TCP-IP UNAPI functions
// MUST NEVER BE BELOW 129 for standard SSH UNAPI functions OR extended TCP-IP UNAPI functions
enum SshUnapiFunctions {
  SSH_GET_CAPAB = 129,
  SSH_OPEN = 130,
  SSH_CLOSE = 131,
  SSH_STATE = 132,
  SSH_SEND = 133,
  SSH_RCV = 134,
  SSH_TERM_TYPE = 135,
  SSH_WIN_SIZE = 136,
  SSH_AUTH_GET_CHALLENGE = 137,
  SSH_AUTH_RESPOND = 138,
  SSH_ADD_KNOWN_HOST = 139,
  SSH_KEY_GEN = 140,
  SSH_KEY_EXPORT = 141,
  SSH_KEY_IMPORT = 142,
  SSH_KEY_INFO = 143
};

enum TcpipUnapiGetCapabParam1
{
  TCPIP_GET_CAPAB_FLAGS = 1,
  TCPIP_GET_CAPAB_CONN = 2,
  TCPIP_GET_CAPAB_DGRAM = 3,
  TCPIP_GET_SECONDARY_CAPAB_FLAGS = 4
};

enum TcpipUnapiGetIpInfoParam1
{
  TCPIP_GET_IPINFO_LOCALIP = 1,
  TCPIP_GET_IPINFO_PEERIP = 2,
  TCPIP_GET_IPINFO_SUBNETMASK = 3,
  TCPIP_GET_IPINFO_GATEWAY = 4,
  TCPIP_GET_IPINFO_PRIMDNS = 5,
  TCPIP_GET_IPINFO_SECDNS = 6
};

enum TcpipErrorCodes {
  UNAPI_ERR_OK = 0,
  UNAPI_ERR_NOT_IMP,
  UNAPI_ERR_NO_NETWORK,
  UNAPI_ERR_NO_DATA,
  UNAPI_ERR_INV_PARAM,
  UNAPI_ERR_QUERY_EXISTS,
  UNAPI_ERR_INV_IP,
  UNAPI_ERR_NO_DNS,
  UNAPI_ERR_DNS,
  UNAPI_ERR_NO_FREE_CONN,
  UNAPI_ERR_CONN_EXISTS,
  UNAPI_ERR_NO_CONN,
  UNAPI_ERR_CONN_STATE,
  UNAPI_ERR_BUFFER,
  UNAPI_ERR_LARGE_DGRAM,
  UNAPI_ERR_INV_OPER
};

enum SSHErrorCodes {
  SSH_ERR_NO_RSS = 127,
  SSH_ERR_INV_KEY,
  SSH_ERR_PWD,
  SSH_ERR_PTY_REQ,
  SSH_ERR_AUTH_TRY_OTHER,
  SSH_ERR_UNKNOWN_HOST,
  SSH_ERR_NO_KEY,       // = 133
  SSH_ERR_KEY_INV_DATA  // = 134
};

enum SshConnectionStates {
  SSH_CLOSED = 0,
  SSH_CONNECTING = 1,
  SSH_AUTHENTICATING = 2,
  SSH_CONNECTED = 3,
  SSH_ERROR = 4,
  SSH_AUTH_CHALLENGE = 5,
  SSH_HOST_UNKNOWN = 6
};

enum SshTerminalTypes {
  TERM_VT52 = 0,
  TERM_ANSI = 1,
  TERM_XTERM = 2
};

enum SshSubsystems {
  SSH_SUB_PTY = 0,
  SSH_SUB_SFTP = 1,
  SSH_SUB_SCP = 2,
  SSH_SUB_RAW = 4
};

#define SSH_AUTH_PASSWORD  0
#define SSH_AUTH_PUBKEY    1

#define SSH_KNOWN_HOST_HASH_SIZE 32
#define SSH_KNOWN_HOSTS_FILE "/ssh_known_hosts"
#define SSH_KEY_PRIV_FILE "/ssh_key_priv.pem"
#define SSH_KEY_PUB_FILE "/ssh_key_pub.pem"
#define SSH_KEY_FINGERPRINT_BUF 44
#define SSH_KEY_IMPORT_BUF_MAX 8192
#define SSH_CRED_USER_MAX 128
#define SSH_CRED_SECRET_MAX 2048

// State Machine States
typedef enum {
    STATE_TEXT,             // Plain text or standard control characters (\r, \n, \b)
    STATE_ESC,              // Found ESC (\x1b)
    STATE_CSI,              // Found CSI (ESC [)
    STATE_SKIP_CSI,         // Discard state for unsupported CSI sequences (Xterm/Mouse)
    STATE_SKIP_OSC,         // Discard state for OSC commands (Windows window titles)
    STATE_OSC_EXPECT_ST     // In OSC, saw 0x1B, expect ST terminator (\)
} parse_state_t;

// Bundle all state variables into a single struct
struct SshFilterState {
    uint8_t carryover[128];
    int carry_len;
    parse_state_t state;
    bool drop_sequence;
    bool is_extended_color;
    int current_param;
    int prev_param;
};

#endif
