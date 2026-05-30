import { C } from "../styles.js";

export default function Spinner({ size = 20 }) {
  return (
    <div
      className="spin"
      style={{
        width: size,
        height: size,
        border: `2px solid ${C.gray}`,
        borderTopColor: C.coral,
        borderRadius: "50%",
        flexShrink: 0,
      }}
    />
  );
}
