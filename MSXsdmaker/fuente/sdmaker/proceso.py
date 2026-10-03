"""proceso.py — crear una tarjeta de principio a fin sobre un dispositivo (imagen o disco de Windows).

Orden: (1) a cero el primer y el ultimo MB (tablas viejas, GPT de respaldo); (2) cada particion: sector de arranque,
las dos FAT enteras, la raiz y, en la de arranque, el sistema y los programas; (3) la tabla de particiones AL FINAL,
para que Windows no vea particiones a medio hacer; (4) verificacion: se relee la tabla y todos los ficheros (CRC)."""
import random
import time

from . import contenido, fatfs, particiones, verificar

SECTOR = 512


def etiqueta_particion(etiqueta, numero):
    if numero == 1:
        return etiqueta
    return (etiqueta[:8].rstrip() + " %d" % numero)[:11]


def crear(dev, plan, sistema, grupos, etiqueta="MSX", aviso=None, raiz_sd=None, opciones=None):
    """plan = lista de particiones.Particion. aviso(texto, fraccion) informa del avance. opciones = las de Nextor 3
    (contenido.OPCIONES_N3). Devuelve un informe."""
    aviso = aviso or (lambda texto, fraccion=None: None)
    t0 = time.time()
    rnd = random.Random()
    informe = {"particiones": [], "ficheros": 0, "bytes": 0}

    aviso("Borrando las tablas viejas...", 0.02)
    uno = min(2048, dev.sectores)
    dev.escribir(0, bytes(uno * SECTOR))
    if dev.sectores > 4096:
        dev.escribir(dev.sectores - 2048, bytes(2048 * SECTOR))

    arbol = None
    if sistema != "ninguno" or grupos:
        arbol = contenido.arbol(sistema, grupos, len(plan), raiz_sd, opciones)
        informe["ficheros"], informe["bytes"] = contenido.resumen(arbol)
    total_ficheros = max(1, informe["ficheros"])
    hechos = [0]

    volumenes = []
    for p in plan:
        if p.tipo == particiones.TIPO_FAT32:
            g = fatfs.geometria_fat32(p.sectores, p.lba)
        else:
            g = fatfs.geometria_fat16_nextor(p.sectores)
        et = etiqueta_particion(etiqueta, p.numero)
        base = 0.05 + 0.85 * (p.numero - 1) / len(plan)

        def progreso(ruta, base=base):
            hechos[0] += 1
            aviso("Copiando %s" % ruta, base + 0.8 * hechos[0] / total_ficheros / len(plan))

        aviso("Particion %d: formateando %s..." % (p.numero, g), base)
        v = fatfs.Volumen(dev, p.lba, g, et, rnd.getrandbits(32), ocultos=p.lba, progreso=progreso)
        usados = v.formatear(arbol if p.numero == 1 else None)
        volumenes.append(v)
        informe["particiones"].append({"numero": p.numero, "geometria": g, "etiqueta": et,
                                       "clusters_usados": usados})

    aviso("Escribiendo la tabla de particiones...", 0.92)
    for lba, s in particiones.sectores_tabla(dev.sectores, plan, rnd.getrandbits(32) | 1):
        dev.escribir(lba, s)

    aviso("Verificando lo escrito...", 0.95)
    errores = verificar.comprobar(dev, plan, volumenes)
    informe["errores"] = errores
    informe["segundos"] = time.time() - t0
    aviso("Hecho" if not errores else "Hecho, CON ERRORES", 1.0)
    return informe
