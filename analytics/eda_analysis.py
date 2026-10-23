"""
=============================================================================
PROYECTO DE GRADO: UNIBOOKS - UNIVERSIDAD DE CUNDINAMARCA (UDEC)
MÓDULO: ANÁLISIS EXPLORATORIO DE DATOS (EDA)
Archivo: eda_analysis.py
Descripción: Script de procesamiento analítico y extracción de insights sobre
             oferta, demanda, precios y efectividad de intercambios.
=============================================================================
"""

import sys
import os
import pandas as pd
import numpy as np

# Configurar path para importar modelos si se ejecuta de forma independiente
current_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(current_dir)
sys.path.insert(0, os.path.join(project_root, "backend"))

def generate_synthetic_historical_data() -> pd.DataFrame:
    """
    Genera un conjunto robusto de datos históricos sintéticos representativos
    basado en las dinámicas reales de las sedes y facultades de la UDEC.
    Permite sustentar el comportamiento a escala de la plataforma ante los jurados.
    """
    np.random.seed(42)
    n_samples = 450

    sedes = [
        "Sede Fusagasugá (Principal)",
        "Seccional Girardot",
        "Seccional Ubaté",
        "Extensión Facatativá",
        "Extensión Chía",
        "Extensión Soacha",
        "Extensión Chocontá",
        "Extensión Zipaquirá",
    ]
    sedes_probs = [0.35, 0.20, 0.12, 0.10, 0.08, 0.08, 0.04, 0.03]

    facultades = [
        "Facultad de Ingeniería",
        "Facultad de Ciencias Agropecuarias",
        "Facultad de Ciencias Administrativas, Económicas y Contables",
        "Facultad de Ciencias de la Salud",
        "Facultad de Ciencias de la Educación",
    ]
    fac_probs = [0.40, 0.22, 0.20, 0.10, 0.08]

    modalidades = ["VENTA", "INTERCAMBIO", "VENTA_O_INTERCAMBIO", "DONACION"]
    mod_probs = [0.45, 0.30, 0.20, 0.05]

    condiciones = ["NUEVO", "COMO_NUEVO", "BUEN_ESTADO", "ACEPTABLE", "DESGASTADO"]
    cond_probs = [0.10, 0.30, 0.45, 0.12, 0.03]

    data = []
    sample_titles = {
        "Facultad de Ingeniería": [
            ("Cálculo: Trascendentes Tempranas", "James Stewart", 2),
            ("Fundamentos de Bases de Datos", "Silberschatz & Korth", 4),
            ("Introducción a los Algoritmos", "Cormen & Leiserson", 3),
            ("Física para Ciencias e Ingeniería", "Serway & Jewett", 2),
            ("Álgebra Lineal con Aplicaciones", "David C. Lay", 1),
            ("Ingeniería de Software", "Ian Sommerville", 5),
            ("Circuitos Eléctricos", "Boylestad", 3),
            ("Termodinámica", "Yunus Çengel", 4),
        ],
        "Facultad de Ciencias Agropecuarias": [
            ("Edafología y Ciencia del Suelo", "Porta & López", 3),
            ("Manual de Fitopatología", "Agrios", 5),
            ("Zootecnia General", "Buxadé", 2),
            ("Nutrición y Alimentación Animal", "McDonald", 4),
            ("Fisiología Vegetal", "Taiz & Zeiger", 3),
            ("Entomología Agrícola", "Gallo", 4),
        ],
        "Facultad de Ciencias Administrativas, Económicas y Contables": [
            ("Principios de Finanzas Corporativas", "Gitman & Zutter", 5),
            ("Contabilidad Financiera", "Guajardo", 2),
            ("Fundamentos de Marketing", "Kotler & Armstrong", 3),
            ("Microeconomía Intermedia", "Hal Varian", 4),
            ("Administración: Una Perspectiva Global", "Koontz", 1),
        ],
        "Facultad de Ciencias de la Salud": [
            ("Anatomía Humana", "Latarjet & Ruiz Liard", 1),
            ("Fisiología Médica", "Guyton & Hall", 2),
            ("Farmacología Básica", "Katzung", 4),
            ("Semiología Médica", "Argente & Álvarez", 3),
        ],
        "Facultad de Ciencias de la Educación": [
            ("Pedagogía del Oprimido", "Paulo Freire", 2),
            ("Didáctica General", "Medina & Salvador", 3),
            ("Psicología del Aprendizaje", "Ausubel", 4),
        ]
    }

    for i in range(n_samples):
        sede = np.random.choice(sedes, p=sedes_probs)
        facultad = np.random.choice(facultades, p=fac_probs)
        modalidad = np.random.choice(modalidades, p=mod_probs)
        condicion = np.random.choice(condiciones, p=cond_probs)

        # Selección de libro representativo según facultad
        books_in_fac = sample_titles[facultad]
        book_choice = books_in_fac[np.random.randint(0, len(books_in_fac))]
        titulo, autor, base_semestre = book_choice
        semestre = int(np.clip(base_semestre + np.random.choice([-1, 0, 1]), 1, 10))

        # Precio según modalidad y condición
        if modalidad in ["INTERCAMBIO", "DONACION"]:
            precio = 0.0
        else:
            base_price = np.random.uniform(35000, 110000)
            if condicion == "NUEVO":
                factor = 1.0
            elif condicion == "COMO_NUEVO":
                factor = 0.85
            elif condicion == "BUEN_ESTADO":
                factor = 0.70
            elif condicion == "ACEPTABLE":
                factor = 0.50
            else:
                factor = 0.35
            precio = round(base_price * factor, -3)  # Redondeo al millar COP

        # Estimación de valor comercial en librería nueva
        precio_comercial = round(precio * 1.85 if precio > 0 else np.random.uniform(70000, 160000), -3)
        ahorro_estimado = precio_comercial - precio

        # Métrica de interacción
        vistas = int(np.random.exponential(scale=35) + 5)
        dias_publicado = np.random.randint(1, 180)

        # Estado de transacción
        prob_completado = 0.65 if modalidad in ["INTERCAMBIO", "VENTA_O_INTERCAMBIO"] else 0.55
        completado = np.random.rand() < prob_completado
        estado = "COMPLETADO" if completado else np.random.choice(["DISPONIBLE", "RESERVADO"], p=[0.7, 0.3])

        satisfaccion = int(np.random.choice([5, 4, 3, 2, 1], p=[0.72, 0.20, 0.05, 0.02, 0.01])) if completado else None

        data.append({
            "id": f"book_{i+1:04d}",
            "titulo": titulo,
            "autor": autor,
            "facultad": facultad,
            "sede": sede,
            "semestre": semestre,
            "modalidad": modalidad,
            "condicion": condicion,
            "precio_unibooks": precio,
            "precio_comercial_nuevo": precio_comercial,
            "ahorro_estudiantil": ahorro_estimado,
            "vistas": vistas,
            "dias_publicado": dias_publicado,
            "estado": estado,
            "satisfaccion_stars": satisfaccion,
        })

    return pd.DataFrame(data)

def run_eda_analysis(df: pd.DataFrame):
    """Ejecuta los análisis cuantitativos clave y genera reporte en consola."""
    print("=" * 70)
    print(" REPORTE ANALÍTICO Y EXPLORATORIO DE DATOS (EDA) - UNIBOOKS UDEC")
    print("=" * 70)

    total_books = len(df)
    total_ahorro = df["ahorro_estudiantil"].sum()
    pct_trueque = (df["modalidad"].isin(["INTERCAMBIO", "VENTA_O_INTERCAMBIO", "DONACION"]).mean()) * 100
    tasa_exito = (df["estado"] == "COMPLETADO").mean() * 100
    precio_medio = df[df["precio_unibooks"] > 0]["precio_unibooks"].mean()

    print(f"\n1. INDICADORES CLAVE DE RENDIMIENTO (KPIs):")
    print(f"   * Total publicaciones analizadas:       {total_books:,}")
    print(f"   * Ahorro total acumulado estudiantes:   ${total_ahorro:,.0f} COP")
    print(f"   * % con opción de Trueque / Donación:   {pct_trueque:.1f}%")
    print(f"   * Tasa de consolidación (éxito):        {tasa_exito:.1f}%")
    print(f"   * Precio promedio de venta:             ${precio_medio:,.0f} COP")

    print(f"\n2. DISTRIBUCIÓN POR SEDE UNIVERSITARIA:")
    sede_dist = df["sede"].value_counts(normalize=True) * 100
    for sede, pct in sede_dist.items():
        print(f"   - {sede:<35}: {pct:5.1f}%")

    print(f"\n3. DEMANDA Y OFERTA POR FACULTAD:")
    fac_dist = df["facultad"].value_counts()
    for fac, count in fac_dist.items():
        print(f"   - {fac:<55}: {count:3d} libros ({count/total_books*100:4.1f}%)")

    print(f"\n4. ESTADÍSTICAS DESCRIPTIVAS DE PRECIO (COP):")
    stats_precio = df[df["precio_unibooks"] > 0]["precio_unibooks"].describe()
    print(stats_precio.to_string())

    print("\n[OK] Analisis exploratorio ejecutado exitosamente.")
    return {
        "total_books": total_books,
        "total_ahorro": total_ahorro,
        "pct_trueque": pct_trueque,
        "tasa_exito": tasa_exito,
    }

if __name__ == "__main__":
    df = generate_synthetic_historical_data()
    run_eda_analysis(df)
