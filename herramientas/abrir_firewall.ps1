# Abre en el firewall de Windows el puerto UDP del juego (24680) para que otros jugadores puedan unirse a tu partida.
# Crea una regla de entrada llamada "Juego de aviones - UDP 24680". Pide permisos de administrador (Windows te los pregunta).
#
# Uso: clic derecho en este archivo > "Ejecutar con PowerShell", o desde una consola:
#   powershell -ExecutionPolicy Bypass -File herramientas\abrir_firewall.ps1
# Para quitar la regla despues:
#   powershell -ExecutionPolicy Bypass -File herramientas\abrir_firewall.ps1 -Quitar
# Nota: el archivo es ASCII a proposito (sin acentos) para que Windows PowerShell lo lea bien.

param([switch]$Quitar)

$Puerto = 24680                                  # el mismo que Net.PORT en net.gd
$Regla = "Juego de aviones - UDP $Puerto"

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$esAdmin = ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Sin permisos de administrador se vuelve a lanzar a si mismo pidiendolos.
if (-not $esAdmin) {
    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    if ($Quitar) { $args += "-Quitar" }
    Start-Process powershell -Verb RunAs -ArgumentList $args
    return
}

$existe = Get-NetFirewallRule -DisplayName $Regla -ErrorAction SilentlyContinue

if ($Quitar) {
    if ($existe) {
        Remove-NetFirewallRule -DisplayName $Regla
        Write-Host "Regla '$Regla' eliminada."
    } else {
        Write-Host "No existe la regla '$Regla'. No hay nada que quitar."
    }
} elseif ($existe) {
    Write-Host "La regla '$Regla' ya existe. No hace falta hacer nada."
} else {
    New-NetFirewallRule -DisplayName $Regla -Direction Inbound -Protocol UDP -LocalPort $Puerto -Action Allow -Profile Any | Out-Null
    Write-Host "Regla creada: se permite el trafico UDP entrante por el puerto $Puerto (redes privadas y publicas)."
}

Read-Host "Pulsa Enter para cerrar"
