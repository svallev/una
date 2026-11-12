// Página de inicio (spec 025). Andamiaje de T-025-01: un texto movido por GSAP + ScrollTrigger con el
// scroll suave de Lenis, para probar la construcción y la CSP de `/` (sin 'unsafe-inline').
import "./prepare-body.js"; // el primero: antes de que ScrollTrigger se registre (ver el archivo)
import "lenis/dist/lenis.css";
import "../gen/tokens.css";
import "./base.css";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import Lenis from "lenis";

gsap.registerPlugin(ScrollTrigger);

const lenis = new Lenis();
lenis.on("scroll", ScrollTrigger.update);
gsap.ticker.add((time) => lenis.raf(time * 1000));
gsap.ticker.lagSmoothing(0);

gsap.to("#moving", {
  yPercent: 300,
  rotation: 8,
  ease: "none",
  scrollTrigger: { trigger: "#journey", start: "top top", end: "bottom bottom", scrub: 0.6 },
});
