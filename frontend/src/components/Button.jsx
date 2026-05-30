import { C } from "../styles.js";

const VARIANTS = {
  primary: { background: C.coral,   color: "#fff" },
  outline: { background: "transparent", color: C.coral, border: `1.5px solid ${C.coral}` },
  ghost:   { background: "transparent", color: C.slate },
  danger:  { background: C.red,     color: "#fff" },
  navy:    { background: C.navy,    color: "#fff" },
};

const SIZES = {
  sm: { padding: "6px 14px",  fontSize: 13 },
  md: { padding: "10px 20px", fontSize: 14 },
  lg: { padding: "13px 28px", fontSize: 15 },
};

export default function Button({
  children,
  onClick,
  variant = "primary",
  size = "md",
  disabled = false,
  fullWidth = false,
  style = {},
}) {
  return (
    <button
      onClick={disabled ? undefined : onClick}
      style={{
        display: "inline-flex",
        alignItems: "center",
        justifyContent: fullWidth ? "center" : undefined,
        gap: 8,
        fontWeight: 600,
        borderRadius: 10,
        border: "none",
        cursor: disabled ? "not-allowed" : "pointer",
        opacity: disabled ? 0.6 : 1,
        transition: "all 0.15s",
        width: fullWidth ? "100%" : undefined,
        ...SIZES[size],
        ...VARIANTS[variant],
        ...style,
      }}
    >
      {children}
    </button>
  );
}
