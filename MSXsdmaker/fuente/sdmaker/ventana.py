"""ventana.py — la ventana de MSXsdmaker (tkinter). El trabajo pesado va en un hilo; los avisos llegan por una cola."""
import os
import queue
import sys
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog, ttk

from . import VERSION, contenido, dispositivos, particiones, proceso
from .dispositivos import formato_tamano

ESQUEMAS = [("fat16-2g", "FAT16 de 2 GB"), ("fat16-4g", "FAT16 de 4 GB"), ("fat32", "Una FAT32 (toda la tarjeta)")]
AVISO_FAT32 = ("Nextor 2.1.4 y 3.0 no leen FAT32: el MSX no arrancará MSX-DOS desde esta tarjeta.\n"
               "Sirve para el menú del MSXimus (ROM y DSK) y para la MSX Pico.")


class Ventana:
    def __init__(self, raiz):
        self.raiz = raiz
        raiz.title("MSX SD Maker %s: tarjetas para MSXimus, MSXnano y MSX Pico" % VERSION)
        raiz.minsize(760, 640)
        self.cola = queue.Queue()
        self.tarjetas = []
        self.trabajando = False
        self.esquema = tk.StringVar(value="fat16-2g")
        self.cantidad = tk.IntVar(value=1)
        self.resto = tk.BooleanVar(value=False)
        self.sistema = tk.StringVar(value="nextor214")
        self.etiqueta = tk.StringVar(value="MSX")
        self.grupos = {g[0]: tk.BooleanVar(value=True) for g in contenido.GRUPOS}
        d = contenido.OPCIONES_N3
        self.n3 = {k: tk.BooleanVar(value=d[k]) for k in ("yenslash", "bufinsert", "btm")}
        self.dirk = tk.StringVar(value=d["dirk"])
        self._construir()
        self.actualizar_tarjetas()
        self.raiz.after(100, self._leer_cola)

    # ------------------------------------------------------------------ interfaz
    def _construir(self):
        p = {"padx": 8, "pady": 4}
        f1 = ttk.LabelFrame(self.raiz, text="1. Tarjeta SD")
        f1.pack(fill="x", **p)
        fila = ttk.Frame(f1)
        fila.pack(fill="x", padx=6, pady=4)
        self.combo = ttk.Combobox(fila, state="readonly", width=78)
        self.combo.pack(side="left", fill="x", expand=True)
        self.combo.bind("<<ComboboxSelected>>", lambda e: self._tarjeta_elegida())
        ttk.Button(fila, text="Actualizar", command=self.actualizar_tarjetas).pack(side="left", padx=6)
        self.info = ttk.Label(f1, text="", justify="left")
        self.info.pack(fill="x", padx=6, pady=(0, 6))

        f2 = ttk.LabelFrame(self.raiz, text="2. Particiones")
        f2.pack(fill="x", **p)
        fila = ttk.Frame(f2)
        fila.pack(fill="x", padx=6, pady=4)
        for clave, texto in ESQUEMAS:
            ttk.Radiobutton(fila, text=texto, value=clave, variable=self.esquema,
                            command=self._recalcular).pack(side="left", padx=(0, 16))
        fila = ttk.Frame(f2)
        fila.pack(fill="x", padx=6)
        ttk.Label(fila, text="Cantidad:").pack(side="left")
        self.spin = ttk.Spinbox(fila, from_=1, to=8, width=4, textvariable=self.cantidad, command=self._recalcular)
        self.spin.pack(side="left", padx=6)
        self.spin.bind("<KeyRelease>", lambda e: self._recalcular())
        self.max_txt = ttk.Label(fila, text="")
        self.max_txt.pack(side="left", padx=6)
        self.chk_resto = ttk.Checkbutton(f2, text="Usar lo que sobre en una última partición FAT16 (de hasta 4 GB)",
                                         variable=self.resto, command=self._recalcular)
        self.chk_resto.pack(anchor="w", padx=6, pady=2)
        self.plan_txt = ttk.Label(f2, text="", justify="left", font=("Consolas", 9))
        self.plan_txt.pack(fill="x", padx=6, pady=(2, 2))
        self.aviso = ttk.Label(f2, text="", foreground="#b00000", justify="left")
        self.aviso.pack(fill="x", padx=6, pady=(0, 6))

        f3 = ttk.LabelFrame(self.raiz, text="3. Sistema en la partición de arranque")
        f3.pack(fill="x", **p)
        for clave, (texto, _, _) in contenido.SISTEMAS.items():
            ttk.Radiobutton(f3, text=texto, value=clave, variable=self.sistema,
                            command=self._recalcular).pack(anchor="w", padx=6)
        fo = ttk.LabelFrame(f3, text="Opciones de Nextor 3")
        fo.pack(fill="x", padx=6, pady=(2, 6))
        self.controles_n3 = [
            ttk.Checkbutton(fo, text="Barra invertida en vez de ¥ en las rutas (YENSLASH ON)", variable=self.n3["yenslash"]),
            ttk.Checkbutton(fo, text="Modo inserción al escribir órdenes (BUFINSERT)", variable=self.n3["bufinsert"]),
            ttk.Checkbutton(fo, text="AUTOEXEC.BTM en vez de AUTOEXEC.BAT (admite GOTO, GOSUB y END)",
                            variable=self.n3["btm"]),
        ]
        for c in self.controles_n3:
            c.pack(anchor="w", padx=6)
        fila = ttk.Frame(fo)
        fila.pack(anchor="w", padx=6, pady=(0, 4))
        self.controles_n3.append(ttk.Label(fila, text="Tamaños en DIR:"))
        self.controles_n3.append(ttk.Radiobutton(fila, text="en K desde 10K (Nextor 3)", value="", variable=self.dirk))
        self.controles_n3.append(ttk.Radiobutton(fila, text="en bytes, como MSX-DOS 2", value="0", variable=self.dirk))
        for c in self.controles_n3[-3:]:
            c.pack(side="left", padx=(0, 10))

        f4 = ttk.LabelFrame(self.raiz, text="4. Programas (en la partición de arranque)")
        f4.pack(fill="x", **p)
        rej = ttk.Frame(f4)
        rej.pack(fill="x", padx=6, pady=4)
        for i, (clave, texto, _, _, _) in enumerate(contenido.GRUPOS):
            ttk.Checkbutton(rej, text=texto, variable=self.grupos[clave]).grid(row=i // 2, column=i % 2, sticky="w",
                                                                              padx=(0, 20))
        fila = ttk.Frame(f4)
        fila.pack(fill="x", padx=6, pady=(0, 6))
        ttk.Button(fila, text="Todos", command=lambda: self._todos(True)).pack(side="left")
        ttk.Button(fila, text="Ninguno", command=lambda: self._todos(False)).pack(side="left", padx=6)
        ttk.Label(fila, text="Nombre de la tarjeta:").pack(side="left", padx=(24, 4))
        ttk.Entry(fila, textvariable=self.etiqueta, width=14).pack(side="left")

        fila = ttk.Frame(self.raiz)
        fila.pack(fill="x", **p)
        self.b_crear = ttk.Button(fila, text="Preparar la tarjeta", command=self.preparar)
        self.b_crear.pack(side="left")
        self.b_imagen = ttk.Button(fila, text="Guardar como imagen...", command=self.guardar_imagen)
        self.b_imagen.pack(side="left", padx=6)
        ttk.Button(fila, text="Salir", command=self.raiz.destroy).pack(side="right")
        self.barra = ttk.Progressbar(self.raiz, maximum=1000)
        self.barra.pack(fill="x", **p)
        self.estado = ttk.Label(self.raiz, text="")
        self.estado.pack(fill="x", padx=8)
        self.log = tk.Text(self.raiz, height=8, font=("Consolas", 9))
        self.log.pack(fill="both", expand=True, **p)

    def _todos(self, valor):
        for v in self.grupos.values():
            v.set(valor)

    def escribir_log(self, texto):
        self.log.insert("end", texto + "\n")
        self.log.see("end")

    # ------------------------------------------------------------------ tarjetas
    def actualizar_tarjetas(self):
        try:
            self.tarjetas = dispositivos.listar_tarjetas()
        except Exception as e:
            self.tarjetas = []
            self.escribir_log("No se pueden listar las tarjetas: %s" % e)
        textos = []
        for t in self.tarjetas:
            unidades = " ".join(t["letras"]) or "sin unidad"
            textos.append("%s   %s   %s   (%s, disco %d)" % (unidades, t["modelo"], formato_tamano(t["bytes"]),
                                                             t["bus"], t["numero"]))
        self.combo["values"] = textos
        if textos:
            self.combo.current(0)
        else:
            self.combo.set("No hay ninguna tarjeta SD ni memoria USB extraíble conectada")
        self._tarjeta_elegida()

    def tarjeta(self):
        i = self.combo.current()
        return self.tarjetas[i] if 0 <= i < len(self.tarjetas) else None

    def _tarjeta_elegida(self):
        t = self.tarjeta()
        if t is None:
            self.info["text"] = ""
        else:
            self.info["text"] = "Tamaño: %s (%s sectores de 512 bytes).  Ahora: %s" % (
                formato_tamano(t["bytes"]), format(t["sectores"], ",").replace(",", "."), self._actual(t))
        self._recalcular()

    def _actual(self, t):
        if sys.platform != "win32" or not dispositivos.es_admin():
            return "(para ver sus particiones hace falta abrir el programa como administrador)"
        try:
            d = dispositivos.DiscoLectura(t["numero"])
            try:
                tabla = particiones.leer_tabla(lambda lba: d.leer(lba))
            finally:
                d.cerrar()
        except Exception as e:
            return "no se puede leer (%s)" % e
        if not tabla:
            return "sin tabla de particiones"
        return ", ".join("%s de %s" % (particiones.NOMBRES_TIPO.get(tipo, "tipo %02Xh" % tipo),
                                       formato_tamano(n * 512)) for _, tipo, _, n in tabla)

    # ------------------------------------------------------------------ plan
    def _sectores(self):
        t = self.tarjeta()
        return t["sectores"] if t else None

    def plan(self, sectores=None):
        sectores = sectores or self._sectores()
        if not sectores:
            return None
        esquema = self.esquema.get()
        try:
            n = int(self.cantidad.get())
        except (tk.TclError, ValueError):
            n = 1
        return particiones.planificar(sectores, esquema, n, self.resto.get())

    def _recalcular(self):
        for c in getattr(self, "controles_n3", []):
            c.state(["!disabled"] if self.sistema.get() == "nextor3" else ["disabled"])
        sectores = self._sectores()
        esquema = self.esquema.get()
        fat16 = esquema != "fat32"
        self.spin.state(["!disabled"] if fat16 else ["disabled"])
        self.chk_resto.state(["!disabled"] if fat16 else ["disabled"])
        self.aviso["text"] = AVISO_FAT32 if not fat16 else ""
        if not sectores:
            self.plan_txt["text"] = ""
            self.max_txt["text"] = ""
            return
        self.max_txt["text"] = ""
        if fat16:
            tam = particiones.GB2 if esquema == "fat16-2g" else particiones.GB4
            maximo = particiones.maximo_fat16(sectores, tam)
            self.spin.configure(to=max(1, maximo))
            self.max_txt["text"] = ("caben %d en esta tarjeta (máximo 8: el menú del MSXimus ve 8)" % maximo
                                    if maximo else "la tarjeta es más pequeña: una sola partición con toda ella")
            if maximo and int(self.cantidad.get() or 1) > maximo:
                self.cantidad.set(maximo)
        try:
            plan = self.plan()
        except ValueError as e:
            self.plan_txt["text"] = str(e)
            return
        lineas = []
        for p in plan:
            if p.numero == 1:
                uso = "arranque (A:)" if self.sistema.get() != "ninguno" else ""
            else:
                uso = "%s: (MAPDRV en el AUTOEXEC)" % "CDEFGHI"[p.numero - 2]
            lineas.append("  %d: %s de %-10s %s" % (p.numero, "FAT32" if p.tipo == particiones.TIPO_FAT32 else "FAT16",
                                                   formato_tamano(p.bytes), uso))
        sobra = particiones.sin_usar(sectores, plan)
        if sobra > 2048:
            lineas.append("  sin usar: %s" % formato_tamano(sobra * 512))
        self.plan_txt["text"] = "\n".join(lineas)

    # ------------------------------------------------------------------ acciones
    def _elegidos(self):
        return {k for k, v in self.grupos.items() if v.get()}

    def _opciones(self):
        o = {k: v.get() for k, v in self.n3.items()}
        o["dirk"] = self.dirk.get()
        return o

    def _texto_opciones(self):
        if self.sistema.get() != "nextor3":
            return ""
        o = self._opciones()
        partes = [contenido.nombre_autoexec("nextor3", o)]
        partes += [t for k, t in (("yenslash", "YENSLASH ON"), ("bufinsert", "BUFINSERT"), ) if o[k]]
        partes.append("DIR en bytes" if o["dirk"] == "0" else "DIR en K")
        return "\nOpciones: " + ", ".join(partes)

    def _bloquear(self, si):
        self.trabajando = si
        for b in (self.b_crear, self.b_imagen):
            b.state(["disabled"] if si else ["!disabled"])

    def preparar(self):
        if self.trabajando:
            return
        t = self.tarjeta()
        if t is None:
            messagebox.showwarning("MSX SD Maker", "Conecta una tarjeta SD y pulsa Actualizar.")
            return
        if sys.platform == "win32" and not dispositivos.es_admin():
            if messagebox.askyesno("MSX SD Maker", "Para escribir en la tarjeta hace falta abrir el programa como "
                                   "administrador.\n\n¿Lo vuelvo a abrir así?"):
                relanzar_como_admin()
            return
        try:
            plan = self.plan()
        except ValueError as e:
            messagebox.showerror("MSX SD Maker", str(e))
            return
        unidades = " ".join(t["letras"]) or "sin unidad"
        texto = ("Se va a BORRAR TODO lo que hay en:\n\n    %s, %s  (%s, disco %d)\n\ny se crearán:\n%s\n\n"
                 "Sistema: %s%s\n\n¿Seguro?" % (t["modelo"], formato_tamano(t["bytes"]), unidades, t["numero"],
                                                self.plan_txt["text"], contenido.SISTEMAS[self.sistema.get()][0],
                                                self._texto_opciones()))
        if not messagebox.askyesno("MSX SD Maker: borrar la tarjeta", texto, icon="warning", default="no"):
            return

        def abrir():
            return dispositivos.DiscoWindows(t["numero"])
        self._lanzar(abrir, plan, "la tarjeta")

    def guardar_imagen(self):
        if self.trabajando:
            return
        # 1.1: el tamano se pregunta siempre (antes, con una tarjeta conectada, la imagen salia del tamano de la tarjeta).
        # 1800M cabe en cualquier tarjeta de 2 GB (las de "2 GB" tienen menos de 2 GiB); en una mayor sobra el resto.
        tam = simpledialog.askstring("MSX SD Maker", "Tamaño de la imagen (por ejemplo 1800M, 3500M o 7G).\n"
                                     "Se puede grabar en una tarjeta de ese tamaño o mayor:\n"
                                     "1800M cabe en cualquiera de 2 GB, 3500M en cualquiera de 4 GB.",
                                     initialvalue="1800M")
        if not tam:
            return
        try:
            t = tam.strip().upper().rstrip("B")
            sectores = int(float(t[:-1]) * {"M": 1 << 20, "G": 1 << 30}[t[-1]]) // 512
        except (ValueError, KeyError, IndexError):
            messagebox.showerror("MSX SD Maker", "Tamaño no válido: %s" % tam)
            return
        ruta = filedialog.asksaveasfilename(title="Guardar la imagen", defaultextension=".img",
                                            filetypes=[("Imagen de disco", "*.img"), ("Todos", "*.*")])
        if not ruta:
            return
        try:
            plan = self.plan(sectores)
        except ValueError as e:
            messagebox.showerror("MSX SD Maker", str(e))
            return

        def abrir():
            return dispositivos.Imagen(ruta, sectores)
        self._lanzar(abrir, plan, os.path.basename(ruta))

    def _lanzar(self, abrir, plan, destino):
        self._bloquear(True)
        self.log.delete("1.0", "end")
        sistema, grupos, etiqueta = self.sistema.get(), self._elegidos(), self.etiqueta.get() or "MSX"
        opciones = self._opciones()

        def trabajo():
            dev = None
            try:
                dev = abrir()
                inf = proceso.crear(dev, plan, sistema, grupos, etiqueta,
                                    lambda texto, f=None: self.cola.put(("aviso", texto, f)), opciones=opciones)
                self.cola.put(("fin", inf, destino))
            except Exception as e:
                self.cola.put(("error", "%s: %s" % (type(e).__name__, e), destino))
            finally:
                if dev is not None:
                    try:
                        dev.cerrar()
                    except Exception as e:
                        self.cola.put(("aviso", "al cerrar: %s" % e, None))
        threading.Thread(target=trabajo, daemon=True).start()

    def _leer_cola(self):
        try:
            while True:
                m = self.cola.get_nowait()
                if m[0] == "aviso":
                    self.estado["text"] = m[1][:110]
                    if m[2] is not None:
                        self.barra["value"] = int(m[2] * 1000)
                    if not m[1].startswith("Copiando"):
                        self.escribir_log(m[1])
                elif m[0] == "fin":
                    self._terminado(m[1], m[2])
                elif m[0] == "error":
                    self._bloquear(False)
                    self.escribir_log("ERROR: " + m[1])
                    messagebox.showerror("MSX SD Maker", "No se ha podido preparar %s:\n\n%s" % (m[2], m[1]))
        except queue.Empty:
            pass
        self.raiz.after(100, self._leer_cola)

    def _terminado(self, inf, destino):
        self._bloquear(False)
        for p in inf["particiones"]:
            self.escribir_log("  particion %d (%s): %s" % (p["numero"], p["etiqueta"], p["geometria"]))
        self.escribir_log("%d ficheros (%s) en %.1f s" % (inf["ficheros"], formato_tamano(inf["bytes"]), inf["segundos"]))
        if inf["errores"]:
            for e in inf["errores"]:
                self.escribir_log("ERROR: " + e)
            messagebox.showerror("MSX SD Maker", "%s está preparada pero la verificación ha encontrado errores:\n\n%s"
                                 % (destino, "\n".join(inf["errores"][:5])))
        else:
            messagebox.showinfo("MSX SD Maker", "%s está lista y verificada.\n\n%d ficheros copiados en la partición "
                                "de arranque." % (destino[:1].upper() + destino[1:], inf["ficheros"]))
        self.raiz.after(2500, self.actualizar_tarjetas)


def relanzar_como_admin():
    import ctypes
    if getattr(sys, "frozen", False):
        exe, params = sys.executable, ""
    else:
        exe, params = sys.executable, '"%s"' % os.path.abspath(sys.argv[0])
    ctypes.windll.shell32.ShellExecuteW(None, "runas", exe, params, None, 1)
    sys.exit(0)


def nitido():
    """Que Windows no amplie la ventana como un mapa de bits en pantallas con escalado (125 %, 150 %...)."""
    if sys.platform == "win32":
        try:
            import ctypes
            ctypes.windll.shcore.SetProcessDpiAwareness(1)
        except Exception:
            pass


def main():
    nitido()
    raiz = tk.Tk()
    try:
        ttk.Style().theme_use("vista" if sys.platform == "win32" else "clam")
    except tk.TclError:
        pass
    Ventana(raiz)
    raiz.mainloop()
