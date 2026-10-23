import os
import sys
import subprocess

current_dir = os.path.dirname(os.path.abspath(__file__))
dashboard_script = os.path.join(current_dir, "dashboard.py")

if __name__ == "__main__":
    print("==================================================================")
    print(" INICIANDO DASHBOARD ANALÍTICO (EDA) - UNIBOOKS UDEC")
    print(" Plataforma interactiva en Streamlit: http://localhost:8501")
    print("==================================================================")
    cmd = [sys.executable, "-m", "streamlit", "run", dashboard_script, "--server.port=8501", "--server.headless=true"]
    subprocess.run(cmd)
