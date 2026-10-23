"""
=============================================================================
PROYECTO DE GRADO: UNIBOOKS - UNIVERSIDAD DE CUNDINAMARCA (UDEC)
MÓDULO: DASHBOARD DE ANALÍTICA Y EXPLORACIÓN DE DATOS (EDA)
Archivo: dashboard.py
Tecnología: Streamlit + Plotly + Pandas
=============================================================================
"""

import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
from eda_analysis import generate_synthetic_historical_data

# 1. CONFIGURACIÓN DE PÁGINA (DEBE SER LA PRIMERA LLAMADA)
st.set_page_config(
    page_title="Unibooks Analytics - Universidad de Cundinamarca",
    page_icon="📚",
    layout="wide",
    initial_sidebar_state="collapsed",
)

# 2. GESTIÓN DE TEMA CLARO / OSCURO
if "theme" not in st.session_state:
    st.session_state.theme = "light"

def toggle_theme():
    st.session_state.theme = "dark" if st.session_state.theme == "light" else "light"

IS_DARK = st.session_state.theme == "dark"

# 3. SISTEMA DE DISEÑO CSS MODERNO INSTITUCIONAL
bg_color = "#09090b" if IS_DARK else "#f8fafc"
card_bg = "#121217" if IS_DARK else "#ffffff"
text_color = "#fafafa" if IS_DARK else "#0f172a"
text_muted = "#a1a1aa" if IS_DARK else "#64748b"
border_color = "#27272a" if IS_DARK else "#e2e8f0"
primary_green = "#22c55e" if IS_DARK else "#0f5132"
accent_gold = "#eab308" if IS_DARK else "#d97706"

css = f"""
<style>
/* Ocultar elementos estándar de Streamlit */
header[data-testid="stHeader"], #MainMenu, footer, [data-testid="stToolbar"],
[data-testid="stDecoration"], [data-testid="stStatusWidget"], .stDeployButton {{
    display: none !important;
}}

/* Contenedor principal */
html, body, [data-testid="stAppViewContainer"], [data-testid="stApp"], .main, .block-container {{
    background-color: {bg_color} !important;
    color: {text_color} !important;
    font-family: 'DM Sans', -apple-system, BlinkMacSystemFont, sans-serif !important;
}}

.block-container {{
    padding: 1.5rem 2.5rem 3rem !important;
    max-width: 1400px !important;
}}

/* Tarjetas de Métricas (KPIs) */
.metric-card {{
    background: {card_bg};
    border: 1px solid {border_color};
    border-radius: 12px;
    padding: 1.25rem 1.4rem;
    box-shadow: 0 1px 3px rgba(0,0,0,0.04);
    margin-bottom: 0.5rem;
}}
.metric-label {{
    font-size: 0.8rem;
    color: {text_muted};
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
}}
.metric-value {{
    font-size: 1.85rem;
    font-weight: 800;
    color: {text_color};
    letter-spacing: -0.02em;
    margin-top: 4px;
}}
.metric-delta {{
    font-size: 0.78rem;
    font-weight: 600;
    margin-top: 0.4rem;
    padding: 2px 8px;
    border-radius: 6px;
    display: inline-flex;
    align-items: center;
    gap: 4px;
}}
.delta-up {{
    color: #16a34a;
    background: rgba(22,163,74,0.12);
}}
.delta-gold {{
    color: {accent_gold};
    background: rgba(234,179,8,0.12);
}}

/* Contenedor de Gráficos Plotly */
.chart-wrap {{
    background: {card_bg};
    border: 1px solid {border_color};
    border-radius: 14px;
    padding: 1.25rem 1.25rem 0.6rem;
    margin-bottom: 1.25rem;
    box-shadow: 0 1px 3px rgba(0,0,0,0.03);
}}
.chart-title {{
    font-size: 0.95rem;
    font-weight: 700;
    color: {text_color};
}}
.chart-subtitle {{
    font-size: 0.76rem;
    color: {text_muted};
    margin-bottom: 0.8rem;
}}

/* Pestañas estilo píldora */
button[data-baseweb="tab"] {{
    background: transparent !important;
    color: {text_muted} !important;
    font-size: 0.85rem !important;
    font-weight: 600 !important;
    padding: 0.55rem 1.2rem !important;
    border: 1px solid transparent !important;
    border-radius: 8px !important;
}}
button[data-baseweb="tab"][aria-selected="true"] {{
    color: {text_color} !important;
    background: {card_bg} !important;
    border-color: {border_color} !important;
    box-shadow: 0 1px 2px rgba(0,0,0,0.05) !important;
}}
[data-baseweb="tab-highlight"], [data-baseweb="tab-border"] {{
    display: none !important;
}}
[data-baseweb="tab-list"] {{
    gap: 6px !important;
    background: {"#18181b" if IS_DARK else "#f1f5f9"} !important;
    border: 1px solid {border_color} !important;
    border-radius: 12px !important;
    padding: 4px;
    margin-bottom: 1.5rem !important;
}}

/* Badges */
.badge {{
    display: inline-block;
    padding: 2px 8px;
    border-radius: 6px;
    font-size: 0.72rem;
    font-weight: 600;
}}
.badge-green {{ color: #16a34a; background: rgba(22,163,74,0.12); }}
.badge-blue {{ color: #2563eb; background: rgba(37,99,235,0.12); }}
.badge-purple {{ color: #9333ea; background: rgba(147,51,234,0.12); }}
</style>
"""
st.markdown(css, unsafe_allow_html=True)

# 4. CONFIGURACIÓN VISUAL PLOTLY
PLOT_LAYOUT = dict(
    paper_bgcolor="rgba(0,0,0,0)",
    plot_bgcolor="rgba(0,0,0,0)",
    font=dict(family="DM Sans, sans-serif", color=text_muted, size=11),
    margin=dict(l=20, r=20, t=10, b=20),
    xaxis=dict(
        gridcolor="rgba(255,255,255,0.05)" if IS_DARK else "rgba(0,0,0,0.05)",
        zerolinecolor="rgba(255,255,255,0.05)" if IS_DARK else "rgba(0,0,0,0.05)",
        tickfont=dict(size=10, color=text_muted),
    ),
    yaxis=dict(
        gridcolor="rgba(255,255,255,0.05)" if IS_DARK else "rgba(0,0,0,0.05)",
        zerolinecolor="rgba(255,255,255,0.05)" if IS_DARK else "rgba(0,0,0,0.05)",
        tickfont=dict(size=10, color=text_muted),
    ),
)

# 5. CARGA DE DATOS EN MEMORIA CACHÉ
@st.cache_data
def load_data():
    return generate_synthetic_historical_data()

raw_df = load_data()

# 6. CABECERA INSTITUCIONAL Y SELECTOR DE TEMA
head_col1, head_col2 = st.columns([10, 2])

with head_col1:
    st.markdown(f"""
    <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 4px;">
        <span style="font-size: 2rem;">📚</span>
        <div>
            <h1 style="font-size: 1.55rem; font-weight: 800; margin: 0; color: {primary_green};">
                UNIBOOKS ANALYTICS & EDA
            </h1>
            <p style="font-size: 0.85rem; color: {text_muted}; margin: 0;">
                Observatorio de Oferta, Demanda, Precios e Impacto Social | Universidad de Cundinamarca
            </p>
        </div>
    </div>
    """, unsafe_allow_html=True)

with head_col2:
    theme_label = "☀️ Modo Claro" if IS_DARK else "🌙 Modo Oscuro"
    st.button(theme_label, on_click=toggle_theme, use_container_width=True)

st.markdown("<hr style='border: none; border-top: 1px solid var(--border); margin: 0.8rem 0 1.2rem;'>", unsafe_allow_html=True)

# 7. BARRA DE FILTROS INTERACTIVOS
with st.expander("🔍 Filtros de Exploración Dinámica (Sede, Facultad, Modalidad)", expanded=True):
    f_col1, f_col2, f_col3 = st.columns(3)
    
    with f_col1:
        sede_options = ["Todas las Sedes"] + sorted(raw_df["sede"].unique().tolist())
        selected_sede = st.selectbox("Sede Universitaria UDEC", sede_options)

    with f_col2:
        fac_options = ["Todas las Facultades"] + sorted(raw_df["facultad"].unique().tolist())
        selected_fac = st.selectbox("Facultad Académica", fac_options)

    with f_col3:
        mod_options = ["Todas las Modalidades", "VENTA", "INTERCAMBIO", "VENTA_O_INTERCAMBIO", "DONACION"]
        selected_mod = st.selectbox("Modalidad de Traspaso", mod_options)

# Aplicación de Filtros al DataFrame
df = raw_df.copy()
if selected_sede != "Todas las Sedes":
    df = df[df["sede"] == selected_sede]
if selected_fac != "Todas las Facultades":
    df = df[df["facultad"] == selected_fac]
if selected_mod != "Todas las Modalidades":
    df = df[df["modalidad"] == selected_mod]

# 8. FILA DE INDICADORES CLAVE (KPI CARDS)
kpi1, kpi2, kpi3, kpi4 = st.columns(4)

total_libros = len(df)
total_ahorro = df["ahorro_estudiantil"].sum()
pct_trueque_donacion = (df["modalidad"].isin(["INTERCAMBIO", "VENTA_O_INTERCAMBIO", "DONACION"]).mean() * 100) if total_libros > 0 else 0
tasa_exito = (df["estado"] == "COMPLETADO").mean() * 100 if total_libros > 0 else 0

with kpi1:
    st.markdown(f"""
    <div class="metric-card">
        <div class="metric-label">Libros Registrados</div>
        <div class="metric-value">{total_libros:,}</div>
        <div class="metric-delta delta-up">↑ 100% Verificados UDEC</div>
    </div>
    """, unsafe_allow_html=True)

with kpi2:
    st.markdown(f"""
    <div class="metric-card">
        <div class="metric-label">Ahorro Estudiantil Estimado</div>
        <div class="metric-value">${total_ahorro/1e6:.1f}M COP</div>
        <div class="metric-delta delta-gold">★ Impacto en Economía Familiar</div>
    </div>
    """, unsafe_allow_html=True)

with kpi3:
    st.markdown(f"""
    <div class="metric-card">
        <div class="metric-label">Economía Circular (Trueque/Donación)</div>
        <div class="metric-value">{pct_trueque_donacion:.1f}%</div>
        <div class="metric-delta delta-up">↑ Reutilización de Libros</div>
    </div>
    """, unsafe_allow_html=True)

with kpi4:
    st.markdown(f"""
    <div class="metric-card">
        <div class="metric-label">Tasa de Entrega Exitosa</div>
        <div class="metric-value">{tasa_exito:.1f}%</div>
        <div class="metric-delta delta-up">✓ En Puntos de Encuentro Seguros</div>
    </div>
    """, unsafe_allow_html=True)

st.markdown("<div style='height: 14px;'></div>", unsafe_allow_html=True)

# 9. PESTAÑAS ANALÍTICAS (TABS)
tab1, tab2, tab3, tab4, tab5 = st.tabs([
    "📍 Distribución Multisede",
    "🏛️ Demanda por Facultades",
    "💰 Precios y Ahorro",
    "🤝 Dinámica de Trueque (Match)",
    "📋 Explorador de Datos"
])

# -----------------------------------------------------------------------------
# TAB 1: DISTRIBUCIÓN MULTISEDE
# -----------------------------------------------------------------------------
with tab1:
    c1, c2 = st.columns([7, 5])
    
    with c1:
        st.markdown("""
        <div class="chart-wrap">
            <div class="chart-title">Volumen de Libros Ofertados por Sede / Seccional</div>
            <div class="chart-subtitle">Concentración de ejemplares a lo largo de los campus de la UDEC</div>
        """, unsafe_allow_html=True)
        
        sede_counts = df["sede"].value_counts().reset_index()
        sede_counts.columns = ["Sede", "Cantidad"]
        
        fig_sede = px.bar(
            sede_counts,
            x="Cantidad",
            y="Sede",
            orientation="h",
            color="Cantidad",
            color_continuous_scale=["#16a34a", "#22c55e", "#d97706"],
        )
        fig_sede.update_layout(**PLOT_LAYOUT, coloraxis_showscale=False)
        fig_sede.update_yaxes(autorange="reversed")
        st.plotly_chart(fig_sede, use_container_width=True, config={"displayModeBar": False})
        st.markdown("</div>", unsafe_allow_html=True)

    with c2:
        st.markdown("""
        <div class="chart-wrap">
            <div class="chart-title">Distribución por Modalidad de Traspaso</div>
            <div class="chart-subtitle">Proporción de venta directa vs. intercambio (trueque) y donación</div>
        """, unsafe_allow_html=True)
        
        mod_counts = df["modalidad"].value_counts().reset_index()
        mod_counts.columns = ["Modalidad", "Cantidad"]
        
        fig_mod = px.pie(
            mod_counts,
            names="Modalidad",
            values="Cantidad",
            hole=0.55,
            color_discrete_sequence=["#0f5132", "#6f42c1", "#0d6efd", "#28a745"],
        )
        fig_mod.update_layout(**PLOT_LAYOUT)
        fig_mod.update_traces(textposition='inside', textinfo='percent+label')
        st.plotly_chart(fig_mod, use_container_width=True, config={"displayModeBar": False})
        st.markdown("</div>", unsafe_allow_html=True)

# -----------------------------------------------------------------------------
# TAB 2: DEMANDA POR FACULTADES
# -----------------------------------------------------------------------------
with tab2:
    c1, c2 = st.columns([6, 6])

    with c1:
        st.markdown("""
        <div class="chart-wrap">
            <div class="chart-title">Publicaciones por Facultad Académica</div>
            <div class="chart-subtitle">Facultades con mayor dinámica de publicaciones y flujo bibliográfico</div>
        """, unsafe_allow_html=True)
        
        fac_counts = df["facultad"].value_counts().reset_index()
        fac_counts.columns = ["Facultad", "Cantidad"]
        
        fig_fac = px.bar(
            fac_counts,
            x="Facultad",
            y="Cantidad",
            color="Facultad",
            color_discrete_sequence=px.colors.qualitative.Prism,
        )
        fig_fac.update_layout(**PLOT_LAYOUT, showlegend=False)
        fig_fac.update_xaxes(tickangle=-25)
        st.plotly_chart(fig_fac, use_container_width=True, config={"displayModeBar": False})
        st.markdown("</div>", unsafe_allow_html=True)

    with c2:
        st.markdown("""
        <div class="chart-wrap">
            <div class="chart-title">Rotación de Libros por Semestre Sugerido</div>
            <div class="chart-subtitle">Identificación de semestres críticos donde los estudiantes más demandan textos</div>
        """, unsafe_allow_html=True)
        
        sem_counts = df.groupby("semestre")["id"].count().reset_index()
        sem_counts.columns = ["Semestre", "Total_Libros"]
        
        fig_sem = px.area(
            sem_counts,
            x="Semestre",
            y="Total_Libros",
            markers=True,
            color_discrete_sequence=["#0f5132"],
        )
        fig_sem.update_layout(**PLOT_LAYOUT)
        st.plotly_chart(fig_sem, use_container_width=True, config={"displayModeBar": False})
        st.markdown("</div>", unsafe_allow_html=True)

# -----------------------------------------------------------------------------
# TAB 3: PRECIOS Y AHORRO
# -----------------------------------------------------------------------------
with tab3:
    c1, c2 = st.columns([6, 6])

    with c1:
        st.markdown("""
        <div class="chart-wrap">
            <div class="chart-title">Dispersión de Precios por Facultad (COP)</div>
            <div class="chart-subtitle">Rango intercuartílico, mediana y valores atípicos en libros con precio > 0</div>
        """, unsafe_allow_html=True)
        
        df_priced = df[df["precio_unibooks"] > 0]
        fig_box = px.box(
            df_priced,
            x="facultad",
            y="precio_unibooks",
            color="facultad",
            color_discrete_sequence=px.colors.qualitative.Safe,
        )
        fig_box.update_layout(**PLOT_LAYOUT, showlegend=False)
        fig_box.update_xaxes(tickangle=-25)
        st.plotly_chart(fig_box, use_container_width=True, config={"displayModeBar": False})
        st.markdown("</div>", unsafe_allow_html=True)

    with c2:
        st.markdown("""
        <div class="chart-wrap">
            <div class="chart-title">Comparativa: Precio Unibooks vs. Librería Comercial Nueva</div>
            <div class="chart-subtitle">Ahorro económico directo accesible para los estudiantes de la UDEC</div>
        """, unsafe_allow_html=True)
        
        avg_comp = df_priced.groupby("facultad")[["precio_unibooks", "precio_comercial_nuevo"]].mean().reset_index()
        
        fig_bar_comp = go.Figure(data=[
            go.Bar(name='Precio Unibooks', x=avg_comp['facultad'], y=avg_comp['precio_unibooks'], marker_color='#16a34a'),
            go.Bar(name='Comercial Nuevo', x=avg_comp['facultad'], y=avg_comp['precio_comercial_nuevo'], marker_color='#dc2626')
        ])
        fig_bar_comp.update_layout(**PLOT_LAYOUT, barmode='group')
        fig_bar_comp.update_xaxes(tickangle=-25)
        st.plotly_chart(fig_bar_comp, use_container_width=True, config={"displayModeBar": False})
        st.markdown("</div>", unsafe_allow_html=True)

# -----------------------------------------------------------------------------
# TAB 4: DINÁMICA DE TRUEQUE (MATCH) Y CALIDAD
# -----------------------------------------------------------------------------
with tab4:
    c1, c2 = st.columns([6, 6])

    with c1:
        st.markdown("""
        <div class="chart-wrap">
            <div class="chart-title">Estado de las Publicaciones e Intercambios</div>
            <div class="chart-subtitle">Tasa de conversión de libros disponibles a transacciones completadas</div>
        """, unsafe_allow_html=True)
        
        status_counts = df["estado"].value_counts().reset_index()
        status_counts.columns = ["Estado", "Cantidad"]
        
        fig_status = px.bar(
            status_counts,
            x="Estado",
            y="Cantidad",
            color="Estado",
            color_discrete_map={
                "COMPLETADO": "#16a34a",
                "DISPONIBLE": "#2563eb",
                "RESERVADO": "#d97706"
            }
        )
        fig_status.update_layout(**PLOT_LAYOUT, showlegend=False)
        st.plotly_chart(fig_status, use_container_width=True, config={"displayModeBar": False})
        st.markdown("</div>", unsafe_allow_html=True)

    with c2:
        st.markdown("""
        <div class="chart-wrap">
            <div class="chart-title">Satisfacción y Calificaciones en Puntos Seguros</div>
            <div class="chart-subtitle">Opiniones y estrellas (1 a 5) otorgadas tras las entregas en campus</div>
        """, unsafe_allow_html=True)
        
        stars_df = df[df["satisfaccion_stars"].notnull()]
        stars_count = stars_df["satisfaccion_stars"].value_counts().sort_index(ascending=False).reset_index()
        stars_count.columns = ["Estrellas", "Evaluaciones"]
        stars_count["Estrellas"] = stars_count["Estrellas"].astype(str) + " Estrellas"

        fig_stars = px.bar(
            stars_count,
            x="Evaluaciones",
            y="Estrellas",
            orientation="h",
            color_discrete_sequence=["#eab308"]
        )
        fig_stars.update_layout(**PLOT_LAYOUT)
        fig_stars.update_yaxes(autorange="reversed")
        st.plotly_chart(fig_stars, use_container_width=True, config={"displayModeBar": False})
        st.markdown("</div>", unsafe_allow_html=True)

# -----------------------------------------------------------------------------
# TAB 5: EXPLORADOR DE DATOS CRUDOS
# -----------------------------------------------------------------------------
with tab5:
    st.markdown("""
    <div class="chart-wrap">
        <div class="chart-title">Tabla de Registros de Publicaciones y Transacciones</div>
        <div class="chart-subtitle">Visualización tabular de los datos filtrados con opción de descarga CSV</div>
    """, unsafe_allow_html=True)
    
    st.dataframe(
        df[[
            "titulo", "autor", "facultad", "sede", "semestre",
            "modalidad", "condicion", "precio_unibooks", "ahorro_estudiantil", "estado"
        ]],
        use_container_width=True,
        hide_index=True,
    )
    
    csv_data = df.to_csv(index=False).encode('utf-8')
    st.download_button(
        label="📥 Descargar Dataset Filtrado en CSV",
        data=csv_data,
        file_name="unibooks_udec_analitica.csv",
        mime="text/csv",
    )
    st.markdown("</div>", unsafe_allow_html=True)
