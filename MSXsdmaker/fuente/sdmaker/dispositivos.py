"""dispositivos.py — donde se escribe: una imagen (pruebas, o para grabarla despues con Rufus/dd) o una tarjeta
en Windows por acceso directo al disco (\\\\.\\PhysicalDriveN).

Seguridad (Windows): solo se listan discos de lectores SD/MMC y USB de medio extraible, NUNCA el disco donde esta
Windows. Antes de escribir se bloquean y desmontan todos los volumenes de esa tarjeta; al acabar se pide a Windows que
relea la tabla de particiones (IOCTL_DISK_UPDATE_PROPERTIES) y monta las unidades nuevas solo."""
import os
import struct
import sys
import time

SECTOR = 512


class Imagen:
    """Fichero de imagen. Si no existe se crea del tamano pedido (disperso en ext4/NTFS: no ocupa lo no escrito)."""

    def __init__(self, ruta, sectores=None):
        self.ruta = ruta
        if sectores is not None:
            with open(ruta, "wb") as f:
                if sys.platform == "win32":
                    _dispersa(f)
                f.truncate(sectores * SECTOR)
        self.f = open(ruta, "r+b")
        self.f.seek(0, 2)
        self.sectores = self.f.tell() // SECTOR
        self.nombre = os.path.basename(ruta)

    def escribir(self, lba, datos):
        assert len(datos) % SECTOR == 0, "escritura no alineada"
        self.f.seek(lba * SECTOR)
        self.f.write(datos)

    def leer(self, lba, n=1):
        self.f.seek(lba * SECTOR)
        return self.f.read(n * SECTOR)

    def cerrar(self):
        self.f.close()


if sys.platform == "win32":
    import ctypes
    from ctypes import wintypes as wt

    k32 = ctypes.WinDLL("kernel32", use_last_error=True)
    k32.CreateFileW.argtypes = [wt.LPCWSTR, wt.DWORD, wt.DWORD, wt.LPVOID, wt.DWORD, wt.DWORD, wt.HANDLE]
    k32.CreateFileW.restype = wt.HANDLE
    k32.DeviceIoControl.argtypes = [wt.HANDLE, wt.DWORD, wt.LPVOID, wt.DWORD, wt.LPVOID, wt.DWORD,
                                    ctypes.POINTER(wt.DWORD), wt.LPVOID]
    k32.DeviceIoControl.restype = wt.BOOL
    k32.SetFilePointerEx.argtypes = [wt.HANDLE, ctypes.c_longlong, ctypes.POINTER(ctypes.c_longlong), wt.DWORD]
    k32.SetFilePointerEx.restype = wt.BOOL
    k32.WriteFile.argtypes = [wt.HANDLE, wt.LPVOID, wt.DWORD, ctypes.POINTER(wt.DWORD), wt.LPVOID]
    k32.WriteFile.restype = wt.BOOL
    k32.ReadFile.argtypes = [wt.HANDLE, wt.LPVOID, wt.DWORD, ctypes.POINTER(wt.DWORD), wt.LPVOID]
    k32.ReadFile.restype = wt.BOOL
    k32.CloseHandle.argtypes = [wt.HANDLE]
    k32.FlushFileBuffers.argtypes = [wt.HANDLE]
    k32.FindFirstVolumeW.argtypes = [wt.LPWSTR, wt.DWORD]
    k32.FindFirstVolumeW.restype = wt.HANDLE
    k32.FindNextVolumeW.argtypes = [wt.HANDLE, wt.LPWSTR, wt.DWORD]
    k32.FindVolumeClose.argtypes = [wt.HANDLE]
    k32.GetVolumePathNamesForVolumeNameW.argtypes = [wt.LPCWSTR, wt.LPWSTR, wt.DWORD, ctypes.POINTER(wt.DWORD)]

    INVALIDO = wt.HANDLE(-1).value
    GENERIC_READ, GENERIC_WRITE = 0x80000000, 0x40000000
    SHARE_RW, OPEN_EXISTING = 3, 3
    IOCTL_DISK_GET_LENGTH_INFO = 0x0007405C       # necesita acceso de lectura (administrador)
    IOCTL_DISK_GET_DRIVE_GEOMETRY_EX = 0x000700A0  # sin acceso: sirve para listar sin ser administrador
    IOCTL_STORAGE_QUERY_PROPERTY = 0x002D1400
    IOCTL_STORAGE_GET_DEVICE_NUMBER = 0x002D1080
    IOCTL_DISK_UPDATE_PROPERTIES = 0x00070140
    FSCTL_LOCK_VOLUME, FSCTL_DISMOUNT_VOLUME = 0x00090018, 0x00090020
    BUS = {7: "USB", 12: "SD", 13: "MMC", 11: "SATA", 17: "NVMe", 3: "ATA", 1: "SCSI", 14: "Virtual"}

    def _abrir(ruta, acceso):
        h = k32.CreateFileW(ruta, acceso, SHARE_RW, None, OPEN_EXISTING, 0, None)
        if h == INVALIDO or h is None:
            raise OSError(ctypes.get_last_error(), "no se puede abrir " + ruta)
        return h

    def _ioctl(h, codigo, entrada=None, tam_salida=0):
        salida = ctypes.create_string_buffer(tam_salida) if tam_salida else None
        n = wt.DWORD(0)
        ent = ctypes.create_string_buffer(entrada) if entrada else None
        ok = k32.DeviceIoControl(h, codigo, ent, len(entrada) if entrada else 0, salida, tam_salida, ctypes.byref(n), None)
        if not ok:
            raise OSError(ctypes.get_last_error(), "DeviceIoControl %08X" % codigo)
        return salida.raw[:n.value] if salida else b""

    def _numero_disco(ruta_volumen):
        """Numero de disco fisico de un volumen (\\\\.\\E: o \\\\?\\Volume{...}) o None."""
        try:
            h = _abrir(ruta_volumen, 0)
        except OSError:
            return None
        try:
            _, numero, _ = struct.unpack("<III", _ioctl(h, IOCTL_STORAGE_GET_DEVICE_NUMBER, None, 12))
            return numero
        except OSError:
            return None
        finally:
            k32.CloseHandle(h)

    def _volumenes():
        """[(ruta \\\\?\\Volume{...} sin barra final, [letras], numero de disco)]"""
        out = []
        buf = ctypes.create_unicode_buffer(1024)
        h = k32.FindFirstVolumeW(buf, 1024)
        if h == INVALIDO:
            return out
        try:
            while True:
                vol = buf.value
                letras = []
                nombres = ctypes.create_unicode_buffer(1024)
                n = wt.DWORD(0)
                if k32.GetVolumePathNamesForVolumeNameW(vol, nombres, 1024, ctypes.byref(n)):
                    letras = [p for p in nombres[:n.value].split("\x00") if len(p) == 3 and p[1] == ":"]
                out.append((vol.rstrip("\\"), letras, _numero_disco(vol.rstrip("\\"))))
                if not k32.FindNextVolumeW(h, buf, 1024):
                    break
        finally:
            k32.FindVolumeClose(h)
        return out

    def disco_del_sistema():
        return _numero_disco("\\\\.\\" + os.environ.get("SystemDrive", "C:"))

    def listar_tarjetas(incluir_usb_fijos=False):
        """[{numero, sectores, bytes, modelo, bus, extraible, letras}] de las tarjetas a las que se puede escribir."""
        sistema = disco_del_sistema()
        vols = _volumenes()
        out = []
        for i in range(32):
            try:
                h = _abrir("\\\\.\\PhysicalDrive%d" % i, 0)
            except OSError:
                continue
            try:
                geo = _ioctl(h, IOCTL_DISK_GET_DRIVE_GEOMETRY_EX, None, 256)
                bps = struct.unpack_from("<I", geo, 20)[0]
                longitud = struct.unpack_from("<q", geo, 24)[0]
                d = _ioctl(h, IOCTL_STORAGE_QUERY_PROPERTY, struct.pack("<II4x", 0, 0), 1024)
            except OSError:
                continue
            finally:
                k32.CloseHandle(h)
            extraible = d[10] != 0
            vend_o, prod_o = struct.unpack_from("<II", d, 12)
            bus = struct.unpack_from("<I", d, 28)[0]

            def cad(o):
                return d[o:d.index(b"\x00", o)].decode("ascii", "replace").strip() if o and o < len(d) else ""
            modelo = (cad(vend_o) + " " + cad(prod_o)).strip() or "sin nombre"
            valido = bus in (12, 13) or (bus == 7 and (extraible or incluir_usb_fijos))
            if i == sistema or not valido or longitud <= 0 or bps != SECTOR:
                continue
            letras = sorted(l for v, ls, n in vols if n == i for l in ls)
            out.append({"numero": i, "sectores": longitud // SECTOR, "bytes": longitud, "modelo": modelo,
                        "bus": BUS.get(bus, str(bus)), "extraible": extraible, "letras": letras})
        return out

    def es_admin():
        try:
            return bool(ctypes.windll.shell32.IsUserAnAdmin())
        except Exception:
            return False

    def _dispersa(f):
        """Fichero disperso en NTFS: una imagen de 32 GB solo ocupa lo escrito."""
        import msvcrt
        try:
            _ioctl(wt.HANDLE(msvcrt.get_osfhandle(f.fileno())), 0x000900C4)   # FSCTL_SET_SPARSE
        except OSError:
            pass

    class DiscoLectura:
        """Solo lectura (para ver la tabla de particiones actual), sin bloquear nada."""

        def __init__(self, numero):
            self.h = _abrir("\\\\.\\PhysicalDrive%d" % numero, GENERIC_READ)

        def leer(self, lba, n=1):
            if not k32.SetFilePointerEx(self.h, lba * SECTOR, None, 0):
                raise OSError(ctypes.get_last_error(), "no se puede ir al sector %d" % lba)
            buf = ctypes.create_string_buffer(n * SECTOR)
            m = wt.DWORD(0)
            if not k32.ReadFile(self.h, buf, n * SECTOR, ctypes.byref(m), None):
                raise OSError(ctypes.get_last_error(), "error de lectura en el sector %d" % lba)
            return buf.raw[:m.value]

        def cerrar(self):
            k32.CloseHandle(self.h)

    class DiscoWindows:
        """La tarjeta entera. abrir() bloquea y desmonta sus volumenes; cerrar() hace que Windows relea la tabla."""

        def __init__(self, numero):
            if numero == disco_del_sistema():
                raise PermissionError("ese es el disco de Windows")
            self.numero = numero
            self.nombre = "Disco %d" % numero
            self.bloqueos = []
            for vol, letras, n in _volumenes():
                if n != numero:
                    continue
                hv = _abrir(vol, GENERIC_READ | GENERIC_WRITE)
                for intento in range(10):      # el Explorador suele soltarla en un momento
                    try:
                        _ioctl(hv, FSCTL_LOCK_VOLUME)
                        break
                    except OSError as e:
                        if intento == 9:
                            k32.CloseHandle(hv)
                            self._soltar()
                            raise OSError(e.errno, "la unidad %s esta en uso: cierra lo que la tenga abierta"
                                          % (letras[0] if letras else vol))
                        time.sleep(0.5)
                _ioctl(hv, FSCTL_DISMOUNT_VOLUME)
                self.bloqueos.append(hv)
            self.h = _abrir("\\\\.\\PhysicalDrive%d" % numero, GENERIC_READ | GENERIC_WRITE)
            self.sectores = struct.unpack("<q", _ioctl(self.h, IOCTL_DISK_GET_LENGTH_INFO, None, 8))[0] // SECTOR

        def _mover(self, lba):
            if not k32.SetFilePointerEx(self.h, lba * SECTOR, None, 0):
                raise OSError(ctypes.get_last_error(), "no se puede ir al sector %d" % lba)

        def escribir(self, lba, datos):
            assert len(datos) % SECTOR == 0
            self._mover(lba)
            buf = ctypes.create_string_buffer(bytes(datos), len(datos))
            n = wt.DWORD(0)
            if not k32.WriteFile(self.h, buf, len(datos), ctypes.byref(n), None) or n.value != len(datos):
                raise OSError(ctypes.get_last_error(), "error de escritura en el sector %d" % lba)

        def leer(self, lba, n=1):
            self._mover(lba)
            buf = ctypes.create_string_buffer(n * SECTOR)
            m = wt.DWORD(0)
            if not k32.ReadFile(self.h, buf, n * SECTOR, ctypes.byref(m), None):
                raise OSError(ctypes.get_last_error(), "error de lectura en el sector %d" % lba)
            return buf.raw[:m.value]

        def _soltar(self):
            for hv in self.bloqueos:
                k32.CloseHandle(hv)
            self.bloqueos = []

        def cerrar(self):
            k32.FlushFileBuffers(self.h)
            try:
                _ioctl(self.h, IOCTL_DISK_UPDATE_PROPERTIES)
            except OSError:
                pass
            k32.CloseHandle(self.h)
            self._soltar()
else:
    def listar_tarjetas(incluir_usb_fijos=False):
        return []

    def es_admin():
        return os.geteuid() == 0 if hasattr(os, "geteuid") else False

    def disco_del_sistema():
        return None


def formato_tamano(nbytes):
    for unidad, div in (("TB", 1 << 40), ("GB", 1 << 30), ("MB", 1 << 20), ("KB", 1 << 10)):
        if nbytes >= div:
            return ("%.2f %s" % (nbytes / div, unidad)).replace(".", ",")
    return "%d B" % nbytes
