import { C } from "../styles.js";

export default function Card({ children, style = {}, onClick }) {
  return (
    <div
      onClick={onClick}
      style={{
        background: C.white,
        borderRadius: 16,
        border: `1px solid ${C.gray}`,
        boxShadow: "0 1px 3px rgba(0,0,0,0.06)",
        cursor: onClick ? "pointer" : undefined,
        transition: "box-shadow 0.15s",
        ...style,
      }}
      onMouseEnter={onClick ? (e) => (e.currentTarget.style.boxShadow = "0 4px 16px rgba(0,0,0,0.10)") : undefined}
      onMouseLeave={onClick ? (e) => (e.currentTarget.style.boxShadow = "0 1px 3px rgba(0,0,0,0.06)") : undefined}
    >
      {children}
    </div>
  );
}
