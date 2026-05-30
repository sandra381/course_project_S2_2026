// ─────────────────────────────────────────────────────────────
// Paleta de colores del SPVR
// Basada en los mockups del equipo (coral/naranja + navy + grises)
// ─────────────────────────────────────────────────────────────
export const C = {
  coral:   "#E8634A",
  coralDk: "#C94F38",
  coralLt: "#FFF0ED",
  navy:    "#1B2A3B",
  navyLt:  "#253548",
  slate:   "#4A5568",
  slateL:  "#718096",
  gray:    "#E2E8F0",
  grayLt:  "#F7FAFC",
  white:   "#FFFFFF",
  green:   "#38A169",
  greenLt: "#F0FFF4",
  amber:   "#D69E2E",
  amberLt: "#FFFFF0",
  red:     "#E53E3E",
  redLt:   "#FFF5F5",
  blue:    "#3182CE",
  blueLt:  "#EBF8FF",
};

// ─────────────────────────────────────────────────────────────
// CSS global — fuentes, reset, animaciones
// ─────────────────────────────────────────────────────────────
export const globalCSS = `
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    font-family: 'Plus Jakarta Sans', sans-serif;
    background: ${C.grayLt};
    color: ${C.navy};
    min-height: 100vh;
  }

  ::-webkit-scrollbar { width: 6px; }
  ::-webkit-scrollbar-track { background: ${C.grayLt}; }
  ::-webkit-scrollbar-thumb { background: ${C.gray}; border-radius: 3px; }

  button { cursor: pointer; font-family: inherit; border: none; }
  input, select, textarea { font-family: inherit; }

  .fade-in {
    animation: fadeIn 0.25s ease;
  }
  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(6px); }
    to   { opacity: 1; transform: translateY(0); }
  }

  .spin { animation: spin 0.9s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }

  .pulse { animation: pulse 1.8s ease-in-out infinite; }
  @keyframes pulse { 0%,100% { opacity:1; } 50% { opacity:0.4; } }
`;
