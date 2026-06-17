' Uruchamia Dashboard-Tray.ps1 (STA, ukryte okno). Argumenty: OpenBrowser AutoStartAi
Option Explicit
Dim sh, toolkit, trayPs1, cmd, a, i, arg
Set sh = CreateObject("WScript.Shell")
toolkit = Left(WScript.ScriptFullName, Len(WScript.ScriptFullName) - Len("\Launch-Tray.vbs"))
trayPs1 = toolkit & "\Dashboard-Tray.ps1"

' Minimized (nie Hidden) — niektore Windows ukrywaja NotifyIcon z calkowicie ukrytego PS
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Sta -WindowStyle Minimized -File """ & trayPs1 & """"
For i = 0 To WScript.Arguments.Count - 1
    arg = WScript.Arguments(i)
    If LCase(arg) = "openbrowser" Then
        cmd = cmd & " -OpenBrowser"
    ElseIf LCase(arg) = "autostartai" Then
        cmd = cmd & " -AutoStartAi"
    End If
Next

sh.CurrentDirectory = Left(toolkit, Len(toolkit) - Len("\Toolkit"))
sh.Run cmd, 0, False
