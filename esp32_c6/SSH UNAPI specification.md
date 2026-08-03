# SSH UNAPI specification

## Index

[1. Introduction](#1-introduction)

[1.1. Design goals](#11-design-goals)

[1.2. Specification scope](#12-specification-scope)

[1.3. Modularity](#13-modularity)

[2. API identifier and version](#2-api-identifier-and-version)

[3. Error codes](#3-error-codes)

[4. API routines](#4-api-routines)

[4.1. Information gathering routines](#41-information-gathering-routines)

[4.1.1. UNAPI_GET_INFO: Obtain the implementation name and version](#411-unapi_get_info-obtain-the-implementation-name-and-version)

[4.1.2. SSH_GET_CAPAB: Get information about the SSH capabilities and features](#412-ssh_get_capab-get-information-about-the-ssh-capabilities-and-features)

[4.2. SSH common routines](#42-ssh-common-routines)

[4.2.1. SSH_OPEN: Open an SSH client connection](#421-ssh_open-open-an-ssh-client-connection)

[4.2.2. SSH_CLOSE: Close an SSH connection](#422-ssh_close-close-an-ssh-connection)

[4.2.3. SSH_STATE: Get the state of an SSH connection](#423-ssh_state-get-the-state-of-an-ssh-connection)

[4.2.4. SSH_SEND: Send data to an SSH connection](#424-ssh_send-send-data-to-an-ssh-connection)

[4.2.5. SSH_RCV: Receive data from an SSH connection](#425-ssh_rcv-receive-data-from-an-ssh-connection)

[4.2.6. SSH_AUTH_GET_CHALLENGE: Get the current keyboard-interactive authentication challenge](#426-ssh_auth_get_challenge-get-the-current-keyboard-interactive-authentication-challenge)

[4.2.7. SSH_AUTH_RESPOND: Respond to a keyboard-interactive authentication challenge](#427-ssh_auth_respond-respond-to-a-keyboard-interactive-authentication-challenge)

[4.2.8. SSH_ADD_KNOWN_HOST: Accept an unknown host key and resume connection](#428-ssh_add_known_host-accept-an-unknown-host-key-and-resume-connection)

[4.3. SSH Key Management routines](#43-ssh-key-management-routines)

[4.3.1. SSH_KEY_GEN: Generate a key pair](#431-ssh_key_gen-generate-a-key-pair)

[4.3.2. SSH_KEY_EXPORT: Export a key pair](#432-ssh_key_export-export-a-key-pair)

[4.3.3. SSH_KEY_IMPORT: Import a key pair](#433-ssh_key_import-import-a-key-pair)

[4.3.4. SSH_KEY_INFO: Get key pair information](#434-ssh_key_info-get-key-pair-information)

[4.4. SSH PTY specific routines](#44-ssh-pty-specific-routines)

[4.4.1. SSH_TERM_TYPE: Get/set the SSH terminal type](#441-ssh_term_type-getset-the-ssh-terminal-type)

[4.4.2. SSH_WIN_SIZE: Get/set the SSH window size](#442-ssh_win_size-getset-the-ssh-window-size)

[4.5. SSH SFTP specific routines](#45-ssh-sftp-specific-routines)

[4.6. SSH SCP specific routines](#46-ssh-scp-specific-routines)

[4.7. Usage examples](#47-usage-examples)

[4.7.1. Keyboard-interactive authentication example](#471-keyboard-interactive-authentication-example)

## 1. Introduction

MSX-UNAPI is a standard procedure for defining, discovering and using new APIs
(Application Program Interfaces) for MSX computers. The MSX-UNAPI specification is
described [MSX%20UNAPI%20specification%201.1.md](./MSX%20UNAPI%20specification%201.1.md).

This document describes an UNAPI compliant API intended for software that implements
SSH protocol and subsystems, that is, software that provides a secure network protocol.
The functionality provided by this API is focused mainly on communicating with other
computers by using PTY subsystem. This specification might be expanded later to allow
other subsystems like SCP and SFTP.

The intended client software applications for this API are networking related applications
such as SSH PTY terminal. This document is targeted at both developers of SSH UNAPI
implementations, and developers of client applications for these implementations.

### 1.1. Design goals

There were two main goals when designing this specification:

- *Simplicity*. This specification's intent is to provide the simplest API that will allow
to develop useful SSH related applications for MSX computers.

- *Modularity*. Most of the capabilities provided by this API are optional, and there
are means to get information about which capabilities are supported by a given
implementation. This allows to create from minimal to complete
implementations, as well as providing a clean way to develop an implementation
in an incremental way.

### 1.2. Specification scope

In order to achieve the simplicity goal, this specification deals with the most basic
capabilities required in order to develop SSH networking applications. These capabilities
are:

- Openning a SSH connections.
- Communicating via subsystems implemented.
- RAW Communication without any subsystem.

### 1.3. Modularity

In order to achieve the modularity goal, most of the capabilities defined in this
specification are optional; implementations may choose to implement the full
specification, or only a subset of it. Of course, the less capabilities are implemented by a
given implementation, the greater are the chances that a particular client application will
not work with it, especially the most basic capabilities. For example, an implementation
not providing any support for PTY subsystem will not be very useful; on the other hand,
an implementation that supports PTY but does not support keyboard-interactive
authentication will probably still work fine with most client applications.

The modularity feature is implemented in two ways:

1. There is a routine, [SSH_GET_CAPAB](#412-ssh_get_capab-get-information-about-the-ssh-capabilities-and-features), that returns a
"capabilities vector". This vector holds one bit for each capability that is defined
in this specification; when the bit is set it means that the capability is
implemented.
2. All routines defined in this specification return an error code in register A. One of
these codes is "Not implemented", and is returned whenever a routine related to
an unimplemented capability is invoked (certain routines return this error or not
depending on the input parameters).

For more details on which routines can be invoked (and how) depending on the
supported capabilities, see the routines descriptions themselves.

## 2. API identifier and version

The API identifier for the specification described in this document is: "SSH" (without
the quotes). Remember that per the UNAPI specification, API identifiers are caseinsensitive.
The SSH API version described in this document is 1.0. This is the API specification
version that the mandatory implementation information routine must return in DE (see
[UNAPI_GET_INFO](#411-unapi_get_info-obtain-the-implementation-name-and-version)).

## 3. Error codes

All routines defined in this specification return an error code in register A. This section
lists all the possible error codes; the numeric value, a mnemonic and a short description
is provided for each one. Each routine description has an errors section which explains
with detail which error codes can be returned for that routine, and for which reasons is
each one returned. Return codes are shared with TCP/IP UNAPI specification since SSH is a
network protocol on top of TCP/IP. Any future SSH specific error codes will use the range
of 127 to 255.

| Code | Mnemonic               | Description                                                                     |
| ---- | ---------------------- | ------------------------------------------------------------------------------- |
| 0    | ERR_OK                 | Operation completed successfully                                                |
| 1    | ERR_NOT_IMP            | Capability not implemented                                                      |
| 2    | ERR_NO_NETWORK         | No network connection available                                                 |
| 3    | ERR_NO_DATA            | No incoming data available                                                      |
| 4    | ERR_INV_PARAM          | Invalid input parameter                                                         |
| 6    | ERR_INV_IP             | Invalid IP address                                                              |
| 9    | ERR_NO_FREE_CONN       | No free connections available                                                   |
| 10   | ERR_CONN_EXISTS        | Connection already exists                                                       |
| 11   | ERR_NO_CONN            | Connection does not exists                                                      |
| 12   | ERR_CONN_STATE         | Invalid connection state                                                        |
| 13   | ERR_BUFFER             | Insufficient output buffer space                                                |
| 15   | ERR_INV_OPER           | Invalid operation                                                               |
| 127  | SSH_ERR_NO_RSS         | Not enough memory to create a new session                                       |
| 128  | SSH_ERR_INV_KEY        | The key used as password is invalid format                                      |
| 129  | SSH_ERR_PWD            | The key or password used to authenticate session was not accepted.              |
| 130  | SSH_ERR_PTY_REQ        | An error occurred while requesting a shell for PTY                              |
| 131  | SSH_ERR_AUTH_TRY_OTHER | The remote server denied the requested authentication mode                      |
| 132  | SSH_ERR_UNKNOWN_HOST   | The remote server's host key could not be verified against the known hosts list |
| 133  | SSH_ERR_NO_KEY         | No key pair has been loaded or generated                                     |
| 134  | SSH_ERR_KEY_INV_DATA   | The imported key data is invalid or in an unsupported format                 |

## 4. API routines

This version of the SSH API consists of routines that enables usage of PTY, RAW, and
in futre also other subsystems, which are described below. API implementations may define
their own additional implementation-specific routines, as described in the MSX-UNAPI
specification.

Routines are grouped in subsections by related behavior. Useful information concerning
all the routines on a given subsection is provided at the beginning of each subsection.
Some routines exchange data with the client application by using a memory buffer. Per
the UNAPI specification, implementations may not allow the destination address to be a
page 1 address (in the range 4000h-7FFFh). Client software should not use this range as
destination address when invoking these routines, in order to correctly interoperate with
such implementations.

### 4.1. Information gathering routines

These routines allow to obtain various information about the implementation capabilities,
working parameters, and current state.

### 4.1.1. UNAPI_GET_INFO: Obtain the implementation name and version

- Input:
  - A = 0

- Output:
  - A = Error code
  - HL = Address of the implementation name string
  - DE = API specification version supported. D=primary, E=secondary.
  - BC = API implementation version. B=primary, C=secondary.

This routine is mandatory for all implementations of all UNAPI compliant APIs. It returns
basic information about the implementation itself: the implementation version, the
supported API version, and a pointer to the implementation description string.

The implementation name string must be placed in the same slot or segment of the
implementation code (or in page 3), must be zero terminated, must consist of printable
characters, and must be at most 63 characters long (not including the terminating zero).
Refer to the MSX-UNAPI specification for more details.

**ERROR CODES**

This routine never fails. ERR_OK is always returned.

### 4.1.2. SSH_GET_CAPAB: Get information about the SSH capabilities and features

- Input:
  - A = 1
  - B = Index of information block to retrieve:
    - 1: Capabilities information block 1

- Output:
    -  A = Error code

    When information block 1 requested:

    - HL = Capabilities flags
    - B = Maximum simultaneous SSH connections supported
    - C = Free SSH connections currently available
    - DE = Maximum data size for command data in SSH functions (SSH_SEND, SSH_RCV, SSH_KEY_EXPORT, SSH_KEY_IMPORT, and any future data-transfer function). When a caller specifies a larger size in HL, the implementation uses the lower of the two values. (0 = no documented limit)

    Other information blocks are not currently supported in this specification. There is
    a provision for multiple blocks just in case those are needed in future.

As explained in ["Modularity"](#13-modularity), the SSH UNAPI specification is modular, meaning that
implementators may choose to include only a certain funcionality subset in the
developed implementations. This is the routine that gives information about the
capabilities actually available in the implementation in which it is invoked. It also
provides information about other implementation working parameters that may be useful
for client applications.

The **capabilities flags** is the most important piece of information, and should be
retrieved by all client applications at startup time, before trying to actually perform any
SSH related operation. It consists of a bitfield in which each bit is associated to one of
the capabilities provided by the routines described in this specification. When the bit is
one, the capability is available, and client applications can safely invoke the routines that
provide the capability. When the bit is zero, the capability is not implemented, and trying
to invoke any of the associated routines will result in the routine returning a
ERR_NOT_IMP error code. (Some routines depend on a given capability or not depending
on the input parameters; more details are given on each routine description).

The set of capabilities flags returned when information block 1 is requested is as follows.
Bit 0 is LSB of register L, bit 8 is LSB of register H.

- Bit 0: Supports PTY subsystem
- Bit 1: Supports SFTP subsystem
- Bit 2: Supports SCP subsystem
- Bit 3: Supports RAW connection
- Bit 4: Always set to 0
- Bit 5: Always set to 0
- Bit 6: Always set to 0
- Bit 7: Always set to 0
- Bit 8: Built-in TCP/IP
- Bit 9: Connection pool shared with built-in TCP/IP
- Bit 10: Supports Public Key Authentication (when set, SSH_KEY_GEN and SSH_KEY_INFO are mandatory)
- Bit 11: Supports Keyboard-Interactive Authentication
- Bit 12: Supports non ANSI Escape Code filtering on PTY
- Bit 13: Supports host key verification
- Bit 14: Supports Key Import/Export (SSH_KEY_IMPORT and SSH_KEY_EXPORT)
- Bit 15: Always set to 0

Note that SSH might be implemented on the same device that already supports TCP/IP UNAPI. In such
case capabilities bit 8 will be set. If not set, you need a TCP/IP UNAPI device so the SSH solution
can connect and communicate over network. If built-in, and bit 9 is set, this means that when opening
a SSH connection the count of TCP/IP connections available in the UNAPI TCP/IP adapter will decrease
and that the number of available SSH connections will decrease when opening a TCP/IP connection. On
other hand, by using the TCP/IP functionality internally performance will be improved.

The writer of this specification understand that for most people using PTY is the
main reason to want SSH on a MSX. As such, I would recommend any developers of Implementations
to support PTY and support non ANS Escape Code filtering. (SSH PTY Sessions to Linux and Windows terminals
have several specific codes called OSC that are sent EVEN if we request an ANSI session, filtering
those on MSX is a little bit CPU intensive, so offering to do this on the implementation helps
for a better experience, this does not affect SSH BBS's)

Also, it is *strongly advised* to implement host key verification, after all SSH is all about
security and for maximum security you *should* be looking at the other end public key finger print
and validating it, to avoid Man In The Middle attacks.

Notice that SSH is unfeasible only using MSX host capabilities (i.e.: z80 or R800 processor), so
it is expected that ALL SSH implementations will have some sort of hardware acceleration. Ideally
all should be offloaded to the hardware.

**ERROR CODES**

- ERR_OK

The requested information block has been returned.

- ERR_INV_PAR

Invalid information block index specified.

### 4.2. SSH common routines

Those are routines that are either used for all subsystems (OPEN, CLOSE, ADD_KNOWN_HOST,
AUTH_GET_CHALLENGE, AUTH_RESPOND) or relevant for more than one subsystem (STATE, SEND, RCV).

#### 4.2.1. SSH_OPEN: Open an SSH client connection

- Input:
  - A = 2
  - HL = Address of the parameters block *(at least 44 bytes long block is recommended)*

- Output:
  - A = Error code
  - B = Connection number

This routine opens a new SSH client connection to a remote server using the information
specified in the parameters block. The format of this block is:

- +0 (4): Remote IP address
- +4 (2): Remote port
- +6 (1): Subsystem:
  - 0: PTY
  - 1: SFTP
  - 2: SCP
  - 3: RAW
- +7 (1): Flags:
  - bit 0: Authentication method (0 = password, 1 = public key). Ignored when bit 2 is set.
  - bit 1: Anonymous Authentication. Cannot be combined with bit 2.
  - bit 2: Keyboard-Interactive Authentication. When set, the connection enters the
    AuthChallenge state after the SSH handshake, and the application must complete
    authentication using SSH_AUTH_GET_CHALLENGE and SSH_AUTH_RESPOND.
  - bit 3: Non ANSI Escape Code filtering on PTY (only for PTY subsystem)
  - bit 4: Host key verification. When set, the implementation checks the remote
    server's host key against the known hosts list after the SSH handshake. If the
    host key is unknown, SSH_ERR_UNKNOWN_HOST is returned along with a valid
    connection number, and the connection enters state 6 (HostUnknown). See the
    SSH_ERR_UNKNOWN_HOST error description below for more details.
  - bits 5-7: Unused, must be zero

  The parameters block layout after the flags byte depends on the authentication method:

  For password (bits 0-2 = 000) method:
    +8 (variable):
      - 0 to X: username, zero terminated
      - X to end: password, zero terminated

  For public key (bits 0-2 = 001):
    +8 (variable):
      - 0 to X: username, zero terminated
      - X to end: no credentials follow (the implementation uses the stored key pair)

  For anonymous authentication (bit 1 = 1) and public key (bits 0-2 = 001):
    +8 (variable):
      - Two consecutive zero bytes (no username, no credentials)

  For keyboard-interactive (bit 2 = 1):
    +8 (variable):
      - 0 to X: username, zero terminated
      - X to end: no password or key follows (only the username is provided)

  When flag bit 4 (host key verification) is set, make sure the parameters block has
  *AT LEAST* 44 bytes available as implementation may write host key fingerprint on it.

This routine initiates the SSH connection process. The implementation must establish a
TCP connection to the specified remote IP address and port, perform the SSH handshake,
and authenticate using the provided credentials.
Once the SSH session is established and a channel is open, all operations needed for the
requested subsystem are performed, i.e.: for PTY, a pseudo-terminal (PTY) is requested
with the terminal type and window size previously set via SSH_TERM_TYPE and SSH_WIN_SIZE
(or the defaults), and then a remote shell is started.
Data can then be exchanged using SSH_SEND and SSH_RCV for PTY and RAW connections.
For SFTP and SCP subsystems, use the dedicated functions described in their respective sections.

When keyboard-interactive authentication is selected (flag bit 2 set), the authentication
process does not complete within SSH_OPEN. Instead, after the SSH handshake the connection
enters the AuthChallenge (state 5) state. The implementation does not open the SSH channel
or perform any subsystem-specific operations until authentication is completed via the
SSH_AUTH_GET_CHALLENGE and SSH_AUTH_RESPOND routines. The application must poll SSH_STATE
to detect when authentication succeeds (state transitions to Connected) or fails (state
transitions to Error).

When Non ANSI Escape Code filtering on PTY is selected (flag bit 3 set), implementation
will filter any received OSC escape codes on data received from PTY subsystems.

When host key verification is selected (flag bit 4 set) the caller *MUST* ensure the
parameters block has at least 44 bytes to be used. If SSH_ERR_UNKNOWN_HOST is returned,
the implementation writes the 44 bytes Base64 Encode of the SHA-256 hash of the remote
server's public key into the parameter block (from it's start, overwriting any parameters),
implementations are responsible for calculating the hash, Base64 Encode it and make the
result a NULL terminated string that has the padding removed.

When public key authentication is requested (flag bit 0 = 1), the implementation
authenticates using the key pair previously generated with SSH_KEY_GEN or imported
with SSH_KEY_IMPORT. If no key pair is available, SSH_ERR_NO_KEY is returned.

Only one SSH connection can exist per connection number. If the connection is opened
successfully, the returned connection number must be used in all subsequent SSH-related
routine calls.

**ERROR CODES**

- ERR_OK

The SSH connection has been initiated. The returned connection number is valid.

- ERR_NOT_IMP

The implementation does not support the requested subsystem, or, public key or
keyboard-interactive authentication was requested but the implementation does not
support it (as indicated by the appropriate capability flag).

- ERR_INV_PARAM

  - An invalid parameter was specified.
  - An unused flag was set.
  - Zero was specified as the remote IP address.

- ERR_NO_NETWORK

No network connectivity is currently available.

- ERR_NO_FREE_CONN

There are no free connections available.

- ERR_NO_CONN

The TCP connection to the remote server could not be established, or the SSH handshake
or authentication failed.

- SSH_ERR_NO_RSS

There is not enough memory on the device handling SSH connections to create a new session.

- SSH_ERR_NO_KEY

No key pair has been loaded or generated (public key authentication requested but
no key pair available).

- SSH_ERR_INV_KEY

The key to be used as password is not in a valid format.

- SSH_ERR_PWD

The key or password used to authenticate session was not accepted.

- SSH_ERR_PTY_REQ

An error occurred while requesting a shell for PTY.

- SSH_ERR_AUTH_TRY_OTHER

The remote server requires keyboard-interactive authentication but a different
authentication method was requested via the flags field.

- SSH_ERR_UNKNOWN_HOST

Host key verification was requested (flag bit 4 set) and the remote server's host
key could not be verified against the known hosts list. The connection enters the
HostUnknown (state 6) state.

A valid connection number is returned in B. The SSH handshake is kept alive and
the implementation caches the server's public key hash and the authentication
credentials provided in the SSH_OPEN call.

The application must retrieve the SHA-256 hash fingerprint null terminated string
of the host public key from the parameters block (see above), and then choose one
of the following actions:

- **Accept the host**: Call SSH_ADD_KNOWN_HOST with the connection number.
  The implementation persists the cached hash to the known hosts list, then resumes
  the connection — authentication, channel opening and subsystem setup are carried
  out using the credentials from the original SSH_OPEN call. The connection
  transitions to Connected (state 3) on success, or to Error (state 4) on failure.

- **Reject the host**: Call SSH_CLOSE with the connection number. The connection
  is terminated normally.

---

#### 4.2.2. SSH_CLOSE: Close an SSH connection

- Input:
  - A = 3
  - B = Connection number

- Output:
  - A = Error code

This routine closes the specified SSH connection. The SSH session is terminated, and
the connection number is freed. This routine is valid in any connection state,
including AuthChallenge (state 5) and HostUnknown (state 6).

**ERROR CODES**

- ERR_OK

The SSH connection has been closed.

- ERR_NO_CONN

There is no SSH connection open with the specified number.

---

#### 4.2.3. SSH_STATE: Get the state of an SSH connection

- Input:
  - A = 4
  - B = Connection number

- Output:
  - A = Error code
  - B = Connection state
  - HL = State-dependent value (see description below)

This routine returns information about the current state of an open SSH connection.

The **connection state** value encodes the current state of the SSH session. It will be
one of the following values:

- 0: Closed — No SSH session exists for this connection number
- 1: Connecting — The underlying TCP connection is being established
- 2: Authenticating — TCP connected, SSH handshake and authentication in progress
- 3: Connected — SSH session established, channel open, data can be exchanged
- 4: Error — An error occurred during connection, authentication, or data exchange
- 5: AuthChallenge — SSH session handshake completed. The remote server has sent a
  keyboard-interactive authentication challenge. The application must retrieve it via
  SSH_AUTH_GET_CHALLENGE and respond via SSH_AUTH_RESPOND.
- 6: HostUnknown — SSH handshake completed but the remote server's host key was not
  found in the known hosts list. The application must either accept the host key via
  SSH_ADD_KNOWN_HOST (which resumes the connection) or close the connection via
  SSH_CLOSE.

The meaning of the **HL** register depends on the connection state:

- States 0-2, 4 (Closed, Connecting, Authenticating, Error): Ignore
- State 3 (Connected): HL = Number of total available incoming bytes that can be
  retrieved by using the SSH_RCV routine.
- State 5 (AuthChallenge): HL = Buffer size required to call SSH_AUTH_GET_CHALLENGE.
  The application should allocate a buffer of at least this size before calling
  SSH_AUTH_GET_CHALLENGE.
- State 6 (HostUnknown): Ignore

**ERROR CODES**

- ERR_OK

The requested information has been retrieved.

- ERR_NO_CONN

There is no SSH connection open with the specified number.

---

#### 4.2.4. SSH_SEND: Send data to an SSH connection

- Input:
  - A = 5
  - B = Connection number
  - DE = Address of the data to send
  - HL = Data length

- Output:
  - A = Error code

This routine sends data to the SSH channel associated with the specified connection.
This works for PTY and RAW subsystems. For other subsystems use only the functions
designated for it.

The implementation will use the lowest value between the maximum data size (returned
by SSH_GET_CAPAB in DE) and the data length provided by the caller in HL.

**ERROR CODES**

- ERR_OK

The data has been sent to the SSH channel.

- ERR_NO_CONN

There is no SSH connection open with the specified number.

- ERR_CONN_STATE

The SSH connection is not in the "Connected" state (e.g., it is in AuthChallenge state)
or a failure occurred while sending.

- ERR_BUFFER

Insufficient buffer space to queue the data for sending.

---

#### 4.2.5. SSH_RCV: Receive data from an SSH connection

- Input:
  - A = 6
  - B = Connection number
  - DE = Address for the received data
  - HL = Maximum data size to retrieve

- Output:
  - A = Error code
  - BC = Number of bytes actually retrieved

This routine retrieves incoming data from the SSH channel associated with the specified
connection. This works for PTY and RAW subsystems. For other subsystems use only the
functions designated for it.

The maximum number of bytes that can be retrieved is specified in HL. The actual number
of bytes retrieved is returned in BC. The implementation will use the lowest value between
the maximum data size (returned by SSH_GET_CAPAB in DE) and the buffer length provided
by the caller in HL. If no data is available, ERR_NO_DATA is returned.

**ERROR CODES**

- ERR_OK

Data has been retrieved and copied to the specified address.

- ERR_NO_CONN

There is no SSH connection open with the specified number.

- ERR_CONN_STATE

The SSH connection is not in the "Connected" state (e.g., it is in AuthChallenge state)
or a failure occurred while reading.

- ERR_NO_DATA

No incoming data is available.

---

#### 4.2.6. SSH_AUTH_GET_CHALLENGE: Get the current keyboard-interactive authentication challenge

- Input:
  - A = 9
  - B = Connection number
  - DE = Address of the caller-provided buffer
  - HL = Maximum buffer size

- Output:
  - A = Error code
  - H = Number of prompts
  - L = Echo flags (bit N set = echo the response for prompt N)
  - BC = Number of bytes written to the buffer (or required size if ERR_BUFFER)

This routine retrieves the current keyboard-interactive authentication challenge from
the remote server for the specified connection. The connection must be in the
AuthChallenge (state 5) state; otherwise, ERR_CONN_STATE is returned.

The challenge data is written to the caller-provided buffer as a sequence of
zero-terminated strings in the following order:

  Name\0Instruction\0Prompt1\0Prompt2\0\0

- **Name**: A short name identifying the challenge (may be empty, i.e., starts with 00h).
- **Instruction**: A longer instruction or banner text (may be empty).
- **Prompt1, Prompt2, ...**: One zero-terminated string for each prompt, in order.
  The number of prompts is returned in register B.
- **Final terminator**: An additional zero byte after the last prompt string.

The **echo flags** in register C indicate, for each prompt, whether the user's response
should be displayed (echoed) as it is typed. If bit N is set, the response to prompt N
should be echoed; if cleared, the response should not be echoed (e.g., for passwords).

If the supplied buffer is too small to hold the complete challenge data, ERR_BUFFER is
returned, no data is consumed from the implementation's internal state, and HL returns
the required buffer size. The caller may retry with a larger buffer. The application can
determine the required size in advance by calling SSH_STATE while the connection is in
AuthChallenge state, which returns the required buffer size in HL.

**ERROR CODES**

- ERR_OK

The challenge data has been written to the buffer.

- ERR_NOT_IMP

Keyboard-interactive authentication is not supported.

- ERR_NO_CONN

There is no SSH connection open with the specified number.

- ERR_CONN_STATE

The connection is not in the AuthChallenge state.

- ERR_BUFFER

The supplied buffer is too small. HL returns the required size. No data is consumed;
the caller may retry with a larger buffer.

---

#### 4.2.7. SSH_AUTH_RESPOND: Respond to a keyboard-interactive authentication challenge

- Input:
  - A = 10
  - B = Connection number
  - DE = Address of the response block
  - HL = Length of the response block

- Output:
  - A = Error code

This routine sends responses to the current keyboard-interactive authentication
challenge for the specified connection. The connection must be in the AuthChallenge
(state 5) state; otherwise, ERR_CONN_STATE is returned.

The response block format is:

  +0 (1): Number of responses (must match the number of prompts from the challenge)
  +1 (variable): Response string for prompt 1, zero terminated
  ... (variable): Response string for prompt 2, zero terminated
  ... ...
  ... (1): Additional zero terminator (final 00h)

The number of responses must match the number of prompts returned by the last
SSH_AUTH_GET_CHALLENGE call. Each response is provided as a zero-terminated string in
the same order as the prompts.

After sending the responses, the connection state transitions as follows:

- **Connected** (state 3): Authentication succeeded. The implementation completes the
  SSH channel opening and performs the subsystem operations appropriate for the
  subsystem requested in SSH_OPEN (e.g., for PTY, request a pseudo-terminal and start
  the remote shell).
- **AuthChallenge** (state 5): The server has sent another challenge. The application
  should call SSH_AUTH_GET_CHALLENGE again and repeat the process (multi-round
  authentication).
- **Error** (state 4): Authentication failed.

**ERROR CODES**

- ERR_OK

The response has been sent to the server.

- ERR_NOT_IMP

Keyboard-interactive authentication is not supported.

- ERR_NO_CONN

There is no SSH connection open with the specified number.

- ERR_CONN_STATE

The connection is not in the AuthChallenge state.

- SSH_ERR_PWD

The remote server did not accept the provided responses.

---

#### 4.2.8. SSH_ADD_KNOWN_HOST: Accept an unknown host key and resume connection

- Input:
  - A = 11
  - B = Connection number (returned by SSH_OPEN when SSH_ERR_UNKNOWN_HOST was produced)

- Output:
  - A = Error code

This routine accepts the remote server's host key that was found unknown during
a prior SSH_OPEN call with flag bit 4 set. The implementation persists the
cached host key hash to its known hosts list, then **resumes** the connection
from where it was suspended:

1. The host key hash is added to the persistent known hosts list.
2. Authentication proceeds using the credentials originally provided in SSH_OPEN.
3. If authentication succeeds, the SSH channel is opened.
4. If a subsystem was requested (PTY, RAW, etc.), the subsystem setup is performed.

After a successful call, the connection transitions to **Connected** (state 3)
and is ready for data exchange using SSH_SEND and SSH_RCV, exactly as if
SSH_OPEN had returned ERR_OK directly.

If any step fails, an appropriate error code is returned and the connection
transitions to **Error** (state 4).

**ERROR CODES**

- ERR_OK

The host key has been accepted, stored in the known hosts list, and the
connection has been fully established. The connection is in Connected state.

- ERR_NOT_IMP

Host key verification is not supported (capability bit 13 not set).

- ERR_NO_CONN

There is no SSH connection open with the specified number, or the connection
is not in the HostUnknown (state 6) state.

- ERR_BUFFER

The known hosts list is full and no more entries can be added.

- ERR_NO_DATA

The host key hash could not be persisted to storage (e.g., filesystem error).

- SSH_ERR_PWD

The key or password used to authenticate the session was not accepted.

- SSH_ERR_PTY_REQ

An error occurred while requesting a shell for PTY.

- ERR_NO_CONN

The connection could not be resumed (e.g., the remote server disconnected).

---

### 4.3. SSH Key Management routines

These routines manage the key pair used for public key authentication. The key pair is
generated, imported, or queried independently of any SSH connection, and is stored
persistently by the implementation. When public key authentication is requested via
SSH_OPEN, the implementation uses the key pair managed by these routines.

If bit 10 (Public Key Authentication) is set in the SSH_GET_CAPAB capabilities flags,
SSH_KEY_GEN and SSH_KEY_INFO are mandatory. SSH_KEY_IMPORT and SSH_KEY_EXPORT are
optional, indicated by bit 14 (Key Import/Export).

#### 4.3.1. SSH_KEY_GEN: Generate a key pair

- Input:
  - A = 12

- Output:
  - A = Error code

This routine generates a new key pair and stores it persistently by the implementation.

It is up to each implementation to determine the key type (e.g., RSA, Ed25519) and
key size that best fits its capabilities. The newly generated key pair replaces any
previously stored key pair.

**ERROR CODES**

- ERR_OK

The key pair has been generated and stored.

- ERR_NOT_IMP

Key generation is not implemented (capability bit 10 not set).

- SSH_ERR_NO_RSS

There is not enough memory on the device to generate a key pair.

---

#### 4.3.2. SSH_KEY_EXPORT: Export a key pair

- Input:
  - A = 13
  - B = What to export:
    - 0: Private key only
    - 1: Public key only
    - 2: Both (private + public, separated by a zero byte)
  - DE = Address of the output buffer
  - HL = Maximum data size for this chunk

- Output:
  - A = Error code
  - BC = Number of bytes written to the buffer
  - H = Status flags:
    - bit 0: 1 = last block (export complete, no more data available)

This routine exports the currently stored key pair (or a selected portion) to a
caller-provided buffer. Because keys can be larger than the maximum data per call
(returned by SSH_GET_CAPAB in DE), the export uses an internal cursor and supports
chunked transfer.

The private key is exported exactly as stored internally by the implementation (PEM
format). The public key is exported in OpenSSH Base64 format, extracted from the
stored private key.

On the first call, the implementation initializes the internal export cursor for the
requested B value. Subsequent calls continue from where the previous call left off.
To export a different portion (e.g., switch from private to public), the caller must
complete the current export first.

The implementation will use the lowest value between the maximum data size (returned
by SSH_GET_CAPAB in DE) and the buffer length provided by the caller in HL.

**ERROR CODES**

- ERR_OK

The data has been written to the buffer.

- ERR_NOT_IMP

Key export is not implemented (capability bit 14 not set).

- SSH_ERR_NO_KEY

No key pair has been loaded or generated.

- ERR_BUFFER

Insufficient output buffer space.

- ERR_INV_PARAM

An invalid value was specified for B.

---

#### 4.3.3. SSH_KEY_IMPORT: Import a key pair

- Input:
  - A = 14
  - C = Control flags:
    - bit 0: 1 = this is the last block (final chunk)
    - bits 1-7: Reserved, must be zero
  - DE = Address of the input buffer with key data
  - HL = Data length of this chunk

- Output:
  - A = Error code

This routine imports a private key file into the implementation in one or more chunks.
The implementation validates the private key, extracts the public key from it, and
stores both persistently, replacing any previously stored key pair.

When C bit 0 is 0, the implementation accumulates the data and waits for the next chunk.
When C bit 0 is 1, the implementation finalizes the import, validates the complete
private key, and stores the key pair.

The input data is the raw content of a private key file in a format supported by the
implementation (for example, PEM format with "BEGIN EC PRIVATE KEY",
"BEGIN RSA PRIVATE KEY", or "BEGIN OPENSSH PRIVATE KEY" headers). It is up to each
implementation to document what key types, formats, and sizes it accepts.

The implementation will use the lowest value between the maximum data size (returned
by SSH_GET_CAPAB in DE) and the data length provided by the caller in HL.

**ERROR CODES**

- ERR_OK

The key pair has been imported and stored.

- ERR_NOT_IMP

Key import is not implemented (capability bit 14 not set).

- SSH_ERR_KEY_INV_DATA

The provided private key data is invalid, corrupt, or in an unsupported format.

- ERR_INV_PARAM

An invalid parameter was specified.

- ERR_BUFFER

Insufficient buffer space to accumulate the key data.

---

#### 4.3.4. SSH_KEY_INFO: Get key pair information

- Input:
  - A = 15
  - DE = Address of the fingerprint buffer (must have at least 44 bytes).
    Set to 0 if only checking key presence.

- Output:
  - A = Error code
  - B = Key status flags:
    - bit 0: 1 = a key pair is currently stored

This routine returns information about the currently stored key pair.

If DE = 0, the routine purely queries key presence: ERR_OK is returned and bit 0 of
B indicates whether a key pair is stored.

If DE is not zero and a key pair is stored, the routine writes the unpadded Base64
SHA-256 public key fingerprint as a null-terminated string to the buffer. The buffer
must have at least 44 bytes.

If DE is not zero and no key pair is stored, SSH_ERR_NO_KEY is returned.

**ERROR CODES**

- ERR_OK

The requested information has been returned.

- ERR_NOT_IMP

Key information is not implemented (capability bit 10 not set).

- SSH_ERR_NO_KEY

No key pair has been loaded or generated.

---

### 4.4. SSH PTY specific routines

#### 4.4.1. SSH_TERM_TYPE: Get/set the SSH terminal type

- Input:
  - A = 7
  - C = Operation:
    - 0: Get the current terminal type
    - 1: Set the terminal type
  - D = Terminal type (only when C=1)

- Output (when C=0):
  - A = Error code
  - D = Terminal type

- Output (when C=1):
  - A = Error code

This routine gets or sets the terminal type string that is sent to the remote SSH server
when requesting a pseudo-terminal (PTY). The terminal type tells the remote server how
to format the output and which control sequences the client terminal understands. The
application calling this function is responsible for actually emulating this terminal type;
the implementation only stores the value and sends it to the remote server.

The following terminal types are defined:

| Value | Description                        |
| ----- | ---------------------------------- |
| 0     | VT-52                              |
| 1     | ANSI (16 colors)                   |
| 2     | xterm                              |
| 3–255 | Reserved for future terminal types |

When a new SSH connection is opened, the terminal type is set to VT-52 (0) by default,
unless it has been explicitly changed before opening the connection. This setting DOES NOT
apply to currently open PTY sessions, only for connections created after setting it. Get
DOES NOT read the currently open PTY session value, but the value set to be used for the
next connection created.

**ERROR CODES**

- ERR_OK

The operation completed successfully.

- ERR_NOT_IMP

There is no PTY subsystem capability.

- ERR_INV_PARAM

  - An invalid value was specified for the operation (C).
  - An invalid terminal type was specified.

---

#### 4.4.2. SSH_WIN_SIZE: Get/set the SSH window size

- Input:
  - A = 8
  - C = Operation:
    - 0: Get the current window size
    - 1: Set the window size
  - H = Number of rows (only when C=1)
  - L = Number of columns (only when C=1)

- Output (when C=0):
  - A = Error code
  - H = Number of rows
  - L = Number of columns

- Output (when C=1):
  - A = Error code

This routine gets or sets the terminal window size (number of rows and columns) that is
sent to the remote SSH server. The server may use this information to format its output
(for example, pagination or line wrapping).

When a new SSH connection is opened, the window size is set to 24 rows and 40 columns
by default, unless it has been explicitly changed before opening the connection. This
setting DOES NOT apply to currently open PTY sessions, only for connections created
after setting it. Get DOES NOT read the currently open PTY session value, but the value
set to be used for the next connection created.

**ERROR CODES**

- ERR_OK

The operation completed successfully.

- ERR_NOT_IMP

There is no PTY subsystem capability.

- ERR_INV_PARAM

  - An invalid value was specified for the operation (C).
  - Zero was specified for rows or columns.

### 4.5. SSH SFTP specific routines

To be defined in a future revision

### 4.6. SSH SCP specific routines

To be defined in a future revision

### 4.7. Usage examples

#### 4.7.1. Keyboard-interactive authentication example

The following diagram illustrates the flow of a keyboard-interactive authentication
session:

```
  Application                    SSH Implementation              Remote Server
      |                                 |                             |
      |-- SSH_OPEN(bit2=1,user) ------->|                             |
      |<-- ERR_OK, conn=B --------------|                             |
      |                                 |--- TCP connect ------------>|
      |                                 |<-- TCP established ---------|
      |                                 |--- SSH handshake ---------->|
      |                                 |<-- handshake done ----------|
      |                                 |--- "none" auth probe ------>|
      |                                 |<-- keyboard-interactive ----|
      |                                 |      challenge              |
      |                                 |                             |
      |-- SSH_STATE(conn) ------------->|                             |
      |<-- B=5 (AuthChallenge), HL=n ---|                             |
      |                                 |                             |
      |-- SSH_AUTH_GET_CHALLENGE(conn)->|                             |
      |<-- prompts, echo_flags, data ---|                             |
      |                                 |                             |
      |   [Display: Name,               |                             |
      |    Instruction,                 |                             |
      |    For each prompt:             |                             |
      |      print prompt string        |                             |
      |      read user input            |                             |
      |    Build response block]        |                             |
      |                                 |                             |
      |-- SSH_AUTH_RESPOND(conn,resp)-->|                             |
      |                                 |---- responses ------------->|
      |                                 |<--- auth result ------------|
      |                                 |                             |
      |-- SSH_STATE(conn) ------------->|                             |
      |<--- state                       |                             |
      |                                 |                             |
      |   [if state == AuthChallenge:   |                             |
      |      goto GET_CHALLENGE         |                             |
      |    if state == Connected:       |                             |
      |      use SSH_SEND/SSH_RCV       |                             |
      |    if state == Error:           |                             |
      |      abort]                     |                             |
```

Below is a C code example illustrating the same flow. The routines are presented as
function calls for clarity; actual UNAPI implementations use register-based calls.

```c
/*
 * Example: keyboard-interactive SSH login.
 * Assumes SSH_OPEN was called with bit 2 set and returned conn.
 * Assumes terminal type and window size were configured beforehand.
 */

struct ssh_open_params {
    uint32_t ip;          // +0: remote IP address
    uint16_t port;        // +4: remote port
    uint8_t  subsystem;   // +6: subsystem (0 = PTY)
    uint8_t  flags;       // +7: flags (bit 2 = keyboard-interactive)
    char     username[];  // +8: zero-terminated username
};

uint8_t ssh_login_keyboard_interactive(uint8_t conn)
{
    uint8_t  challenge_buf[512];
    uint8_t  response_buf[256];
    uint8_t  state, num_prompts, echo_flags;
    uint16_t size;

    while (1) {
        // Check connection state
        state = ssh_state(conn);  // A = 4

        if (state == STATE_CONNECTED) {
            // PTY + shell ready, proceed with data exchange
            return ERR_OK;
        }

        if (state == STATE_ERROR) {
            return SSH_ERR_PWD;
        }

        if (state != STATE_AUTH_CHALLENGE) {
            // Still connecting or authenticating, wait
            continue;
        }

        // Retrieve the challenge
        num_prompts = ssh_auth_get_challenge(
            conn,
            challenge_buf,
            sizeof(challenge_buf),
            &echo_flags,
            &size
        );

        if (num_prompts == 0) {
            return ERR_CONN_STATE;
        }

        // Parse: Name\0 Instruction\0 Prompt1\0 Prompt2\0 \0
        char *name        = (char *)challenge_buf;
        char *instruction = name + strlen(name) + 1;
        char *prompt_ptr  = instruction + strlen(instruction) + 1;

        // Display challenge info
        if (name[0] != '\0')
            printf("%s\n", name);
        if (instruction[0] != '\0')
            printf("%s\n", instruction);

        // Build response block
        response_buf[0] = num_prompts;   // count byte
        uint8_t *resp_ptr = response_buf + 1;

        for (uint8_t i = 0; i < num_prompts; i++) {
            uint8_t echo = (echo_flags >> i) & 1;

            printf("%s: ", prompt_ptr);

            if (echo) {
                // Echo input (e.g., username)
                gets((char *)resp_ptr);
            } else {
                // No echo (e.g., password)
                get_password_no_echo((char *)resp_ptr);
                printf("\n");
            }

            resp_ptr += strlen((char *)resp_ptr) + 1;
            prompt_ptr += strlen(prompt_ptr) + 1; // next prompt string
        }

        *resp_ptr++ = '\0';  // final terminator

        // Send responses
        uint8_t err = ssh_auth_respond(conn, response_buf);
        if (err != ERR_OK)
            return err;

        // Loop: check state again (Connected, AuthChallenge, or Error)
    }
}
```

---

## 5. Change log

This section lists the changes introduced in all the existing versions of the specification.

### Version 1.0

- First version