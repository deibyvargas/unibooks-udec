import os
import sys
import socket
import subprocess

# Asegurar que la raíz del backend esté en el sys.path
backend_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, backend_dir)

# Detección inteligente del entorno virtual de backend
venv_python_win = os.path.join(backend_dir, ".venv", "Scripts", "python.exe")
venv_python_posix = os.path.join(backend_dir, ".venv", "bin", "python")
target_python = venv_python_win if os.path.exists(venv_python_win) else (venv_python_posix if os.path.exists(venv_python_posix) else None)

if target_python and os.path.abspath(sys.executable).lower() != os.path.abspath(target_python).lower():
    print(f"[UNIBOOKS] Redirigiendo automáticamente al entorno virtual: {target_python}")
    try:
        sys.exit(subprocess.call([target_python] + sys.argv))
    except KeyboardInterrupt:
        sys.exit(0)

import uvicorn

def main():
    # Permite ejecutar este archivo desde cualquier carpeta sin perder imports ni .env.
    os.chdir(backend_dir)

    local_ip = "127.0.0.1"
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except Exception:
        pass

    print("================================================================")
    print(" INICIANDO UNIBOOKS - UNIVERSIDAD DE CUNDINAMARCA (UDEC)")
    print(" Servidor Local (PC):      http://127.0.0.1:8000/api/v1")
    print(f" Servidor Red (Celular):   http://{local_ip}:8000/api/v1")
    print(" Documentación Swagger UI: http://127.0.0.1:8000/docs")
    print(" Documentación ReDoc:      http://127.0.0.1:8000/redoc")
    print("================================================================")
    try:
        uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
    except KeyboardInterrupt:
        print("\n[UNIBOOKS] Servidor cerrado correctamente.")


if __name__ == "__main__":
    main()
