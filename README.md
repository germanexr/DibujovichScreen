# DibujovichScreen

Una herramienta sencilla para dibujar sobre la pantalla en Windows.

## Descargar y usar

Descargá [DibujovichScreen.exe](https://github.com/germanexr/DibujovichScreen/releases/latest/download/DibujovichScreen.exe) y abrilo. Aparece un icono en el área de notificaciones, junto al reloj. No necesita instalación.

- `F4`: activar o desactivar el modo dibujo.
- Arrastrar con el botón izquierdo: dibujar.
- `Ctrl+Z`: deshacer el último trazo.
- `Supr`: borrar todo.
- `R`, `G`, `B`, `Y`: rojo, verde, celeste y amarillo.
- `+` / `-`: cambiar el grosor.
- `Esc`: salir del modo dibujo.

Para cerrar completamente el programa, hacé clic derecho en su icono junto al reloj y elegí **Salir**.

Windows puede mostrar una advertencia la primera vez porque este ejecutable todavía no está firmado digitalmente.

## Compilar desde el código fuente

En Windows, abrí PowerShell en esta carpeta y ejecutá:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

El resultado queda en `dist/DibujovichScreen.exe`. Se usa el compilador de .NET Framework incluido en Windows. El código C# está dentro de `DibujovichScreen.ps1`; `build.ps1` lo extrae y compila.

## Nota sobre el proyecto

DibujovichScreen es una implementación nueva. No incluye código ni archivos de Mousetrack.
