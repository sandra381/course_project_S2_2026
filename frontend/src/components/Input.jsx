import { useState } from "react";
import { C } from "../styles.js";

export default function Input({
  label,
  type = "text",
  value,
  onChange,
  placeholder,
  icon,
  rightElement,
}) {
  const [focused, setFocused] = useState(false);

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
      {label && (
        <label style={{ fontSize: 13, fontWeight: 600, color: C.slate }}>
          {label}
        </label>
      )}
      <div style={{ position: "relative" }}>
        {icon && (
          <span
            style={{
              position: "absolute",
              left: 12,
              top: "50%",
              transform: "translateY(-50%)",
              color: C.slateL,
              fontSize: 15,
              pointerEvents: "none",
            }}
          >
            {icon}
          </span>
        )}
        <input
          type={type}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          style={{
            width: "100%",
            padding: icon ? "10px 40px 10px 40px" : rightElement ? "10px 40px 10px 14px" : "10px 14px",
            borderRadius: 10,
            border: `1.5px solid ${focused ? C.coral : C.gray}`,
            fontSize: 14,
            outline: "none",
            background: C.white,
            color: C.navy,
            transition: "border-color 0.15s",
          }}
        />
        {rightElement && (
          <span
            style={{
              position: "absolute",
              right: 12,
              top: "50%",
              transform: "translateY(-50%)",
            }}
          >
            {rightElement}
          </span>
        )}
      </div>
    </div>
  );
}
