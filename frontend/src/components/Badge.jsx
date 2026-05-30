import { C } from "../styles.js";

const COLORS = {
  green: { bg: C.greenLt, text: C.green },
  amber: { bg: C.amberLt, text: C.amber },
  red:   { bg: C.redLt,   text: C.red   },
  blue:  { bg: C.blueLt,  text: C.blue  },
  gray:  { bg: C.gray,    text: C.slateL },
};

// Mapeo de estado → color
const STATUS_COLOR = {
  COMPLETADO:  "green",
  PROCESANDO:  "amber",
  PENDIENTE:   "blue",
  FALLIDO:     "red",
};

export function Badge({ color = "gray", children }) {
  const s = COLORS[color] || COLORS.gray;
  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 5,
        padding: "3px 10px",
        borderRadius: 20,
        fontSize: 12,
        fontWeight: 600,
        background: s.bg,
        color: s.text,
      }}
    >
      <span style={{ width: 6, height: 6, borderRadius: "50%", background: s.text }} />
      {children}
    </span>
  );
}

// Componente que recibe directamente el estado y elige el color
export function StatusBadge({ estado }) {
  const color = STATUS_COLOR[estado] || "gray";
  return <Badge color={color}>{estado}</Badge>;
}
