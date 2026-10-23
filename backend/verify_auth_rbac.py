import requests

BASE = "http://127.0.0.1:8000/api/v1"

print("=" * 60)
print("TEST 1: Bloqueo de registro con correo no institucional (@gmail.com)")
r_blocked = requests.post(f"{BASE}/auth/register", json={
    "email": "estudiante_falso@gmail.com",
    "password": "Password123!",
    "nombre_completo": "Estudiante Falso",
    "telefono": "3001234567"
})
print("Status Code:", r_blocked.status_code)
print("Respuesta:", r_blocked.json())

print("\n" + "=" * 60)
print("TEST 2: Login de Administrador Principal (vargasdeiby54@gmail.com)")
r_admin_login = requests.post(f"{BASE}/auth/login", json={
    "email": "vargasdeiby54@gmail.com",
    "password": "331156301983"
})
data_admin = r_admin_login.json()
print("Status Code:", r_admin_login.status_code)
print("Rol:", data_admin.get("user", {}).get("rol"))
admin_token = data_admin.get("access_token") or data_admin.get("token")
print("Token:", admin_token)

print("\n" + "=" * 60)
print("TEST 3: Administrador consulta Endpoint Protegido (GET /admin/stats)")
r_stats = requests.get(f"{BASE}/auth/admin/stats", headers={"Authorization": f"Bearer {admin_token}"})
print("Status Code:", r_stats.status_code)
print("Metricas del Sistema:", r_stats.json())

print("\n" + "=" * 60)
print("TEST 4: Login de Estudiante (Carlos Mendoza)")
r_carlos_login = requests.post(f"{BASE}/auth/login", json={
    "email": "carlos.mendoza@ucundinamarca.edu.co",
    "password": "password"
})
data_carlos = r_carlos_login.json()
print("Status Code:", r_carlos_login.status_code)
print("Rol:", data_carlos.get("user", {}).get("rol"))
carlos_token = data_carlos.get("access_token") or data_carlos.get("token")

print("\n" + "=" * 60)
print("TEST 5: RBAC - Estudiante intenta acceder a Endpoint de Administrador (GET /admin/stats)")
r_forbidden = requests.get(f"{BASE}/auth/admin/stats", headers={"Authorization": f"Bearer {carlos_token}"})
print("Status Code (Debe ser 403 Forbidden):", r_forbidden.status_code)
print("Mensaje de Seguridad:", r_forbidden.json())
print("=" * 60)
