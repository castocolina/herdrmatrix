import { View, div } from "gpui-kit";
import { v_flex } from "gpui-base";
import { theme, agents } from "herdr";

// Lluvia digital: una fila = un elemento con .frames (9 elementos en total).
const GLYPHS = "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎ0123456789Z:.=*+<>";
const COLS = 22;
const ROWS = 9;
const CELL = 11;    // px
const TRAIL = 4;    // largo de la estela
const PERIOD = 16;  // frames por ciclo
const SPEED = 110;  // ms por frame

// PRNG determinista: patrón estable entre renders.
function rng(seed) {
  let s = seed >>> 0;
  return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
}

// Cada fila guarda PERIOD cadenas de COLS caracteres; cada columna tiene su desfase.
function buildRows() {
  const r = rng(7919);
  const offsets = Array.from({ length: COLS }, () => Math.floor(r() * PERIOD));
  const rows = [];
  for (let row = 0; row < ROWS; row++) {
    const frames = [];
    for (let f = 0; f < PERIOD; f++) {
      let line = "";
      for (let c = 0; c < COLS; c++) {
        const d = (f - row - offsets[c] + PERIOD * 4) % PERIOD;
        line += d < TRAIL ? GLYPHS[Math.floor(r() * GLYPHS.length)] : " ";
      }
      frames.push(line);
    }
    rows.push(frames);
  }
  return rows;
}

const RAIN = buildRows();

export default class PhosphorRain extends View {
  render() {
    const t = theme();
    // Agente bloqueado: la lluvia se tiñe de rojo neón.
    const blocked = agents().some((a) => a.status === "blocked");
    const color = blocked ? t.blocked : t.accent;

    return v_flex().id("root").size_full().overflow_hidden()
      .items_center().justify_center()
      .children(RAIN.map((frames, row) =>
        div().id(`r${row}`).h(CELL + 3).text_size(CELL)
          .text_color(row === ROWS - 1 ? t.foreground : color)
          .loop("opacity", { from: 0.45, to: 1, period: 1100 + row * 90 })
          .frames(frames, SPEED)));
  }
}
