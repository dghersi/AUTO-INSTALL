Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Obtiene la ruta de la carpeta donde está este script
strPath = fso.GetParentFolderName(WScript.ScriptFullName)

' IMPORTANTE: Verifica que el nombre entre comillas sea IDÉNTICO a tu archivo .bat
strBatchFile = strPath & "\INICIAR ARIA.bat"

' Verificación de seguridad: Si el archivo no existe, te avisará con un mensaje
If Not fso.FileExists(strBatchFile) Then
    MsgBox "Error: No se encontró el archivo: " & strBatchFile, 16, "Error de Ruta"
Else
    ' Ejecuta el .bat en modo oculto (0)
    WshShell.Run chr(34) & strBatchFile & chr(34), 0, False
End If

Set WshShell = Nothing
Set fso = Nothing