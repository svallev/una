// Página de inicio (spec 025). Arranque: idioma (CA-025-09), recorrido o versión apilada (CA-025-10,
// CL-025-13) y montaje dentro de `boot`, que quita el contenido sin JavaScript al terminar o lo enseña si algo
// falla (CA-025-11, CL-025-12). Lo que se monta es aún el andamiaje de T-025-01 (el titular de la portada,
// movido por GSAP + ScrollTrigger con el scroll suave de Lenis); lo sustituyen T-025-05 a 10.
import "./prepare-body.js"; // el primero: antes de que ScrollTrigger se registre (ver el archivo)
import "lenis/dist/lenis.css";
import "../gen/tokens.css";
import "./base.css";
import "./static.css";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import Lenis from "lenis";
import site from "../gen/site.json";
import es from "./strings.es.json";
import en from "./strings.en.json";
import { boot } from "./boot.js";
import { applyLang, browserStorage, pickLang, plainTitle } from "./lang.js";
import { chooseMode, contentFits, detectMode, observeSizes, watchFit } from "./mode.js";

const lang = pickLang({ storage: browserStorage(window), languages: navigator.languages, language: navigator.language });
const strings = lang === "es" ? es : en;
applyLang(document, lang, strings, site.appName);

boot({ doc: document, mount });

function mount({ onUndo }) {
  const root = document.documentElement;
  const journey = document.getElementById("journey");
  const hero = document.createElement("section");
  hero.className = "hero";
  const title = document.createElement("h1");
  title.className = "moving";
  title.tabIndex = -1;
  title.textContent = plainTitle(strings.heroTitle);
  hero.append(title);
  journey.append(hero);
  onUndo(() => hero.remove());

  const stack = () => root.classList.remove("is-journey");
  if (chooseMode(detectMode(window)).mode === "stacked") return;

  root.classList.add("is-journey");
  onUndo(stack);
  const stopJourney = startJourney(title, journey);
  onUndo(stopJourney);
  const fit = watchFit({
    fits: () => contentFits([hero], window),
    observe: observeSizes(window, [hero]),
    ready: document.fonts?.ready,
    onStack: () => {
      stopJourney();
      stack();
    },
  });
  onUndo(fit.stop);
}

/** El recorrido del andamiaje; devuelve cómo pararlo y dejar la página con el scroll normal. */
function startJourney(target, trigger) {
  gsap.registerPlugin(ScrollTrigger);
  const lenis = new Lenis();
  lenis.on("scroll", ScrollTrigger.update);
  const tick = (time) => lenis.raf(time * 1000);
  gsap.ticker.add(tick);
  gsap.ticker.lagSmoothing(0);
  const tween = gsap.to(target, {
    yPercent: 300,
    rotation: 8,
    ease: "none",
    scrollTrigger: { trigger, start: "top top", end: "bottom bottom", scrub: 0.6 },
  });
  let stopped = false;
  return () => {
    if (stopped) return;
    stopped = true;
    tween.scrollTrigger?.kill();
    tween.kill();
    gsap.ticker.remove(tick);
    lenis.destroy();
    gsap.set(target, { clearProps: "transform" });
  };
}
