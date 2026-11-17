import { WORDMARK, STORE_URLS, LINKS } from './config.js';
import { t, lang, titleHtml } from './i18n.js';
import { setLang } from './locale.js';
import { SCENES, NOTE } from './story.js';
import { icon } from './icons.js';
import { esc } from './html.js';

/**
 * Las tiendas, con un rótulo de texto propio (sin insignias hasta que haya ficha), App Store primero. Sin
 * dirección el rótulo se ve igual, pero no es un enlace: encima va "Muy pronto" y el lector lo oye en el nombre.
 */
export function storesHtml({ label = true } = {}) {
  const soon = t('store.soon');
  const one = (id) => {
    const url = STORE_URLS[id];
    const name = esc(t(`store.${id}`));
    return url
      ? `<a class="badge badge--${id}" href="${esc(url)}" rel="noopener noreferrer">${name}</a>`
      : `<span class="badge badge--${id} is-soon">${name}<span class="vh"> (${esc(soon.toLowerCase())})</span></span>`;
  };
  const pending = !STORE_URLS.googlePlay || !STORE_URLS.appStore;
  return `<div class="stores">${label && pending ? `<p class="stores__soon">${esc(soon)}</p>` : ''}<div class="stores__row">${one('appStore')}${one('googlePlay')}</div></div>`;
}

export function footerHtml() {
  const link = (key) => `<a href="${esc(LINKS[key])}">${esc(t(`footer.${key}`))}</a>`;
  return `<footer class="end"><span>${esc(t('footer.legal'))}</span><nav aria-label="${esc(t('footer.nav'))}">${link('help')}${link('privacy')}${link('licenses')}</nav></footer>`;
}

/** Bloque de texto de una escena: `before` va encima del titular; `extra`, después de la entradilla. */
export function copyHtml(scene, index, extra = '', { before = '' } = {}) {
  const tag = index === 0 ? 'h1' : 'h2';
  return `<div class="copy">${before}<${tag} class="big" id="h-${scene.id}" style="--c:${scene.accent}">${titleHtml(`scenes.${scene.id}.title`)}</${tag}><p class="lead">${esc(t(`scenes.${scene.id}.lead`))}</p>${extra}</div>`;
}

export function switchChip(label, on = false) {
  return `<span class="chip"><span>${esc(label)}</span><span class="sw${on ? ' is-on' : ''}" aria-hidden="true"></span></span>`;
}

/** Cabecera fija: logotipo, idioma y "Descargar". */
export function headerHtml() {
  return `<header class="top">
    <a class="logo" href="#top" aria-label="${esc(t('nav.home'))}">${esc(WORDMARK)}</a>
    <div class="top__right">
      <div class="langs" role="group" aria-label="${esc(t('nav.lang'))}">
        <button type="button" data-lang="es" aria-pressed="${lang === 'es'}">ES</button>
        <button type="button" data-lang="en" aria-pressed="${lang === 'en'}">EN</button>
      </div>
      <a class="btn" href="#fin">${icon('arrowDown')}<span>${esc(t('nav.download'))}</span></a>
    </div></header>`;
}

/** Pista de scroll (solo con el recorrido: `base.css`). */
export function hintHtml() {
  return `<div class="hint" aria-hidden="true"><span>${esc(t('nav.hint'))}</span>${icon('arrowDown')}</div>`;
}

/** Da vida a la cabecera y a la pista que ya están en la página. Devuelve cómo marcar la escena activa. */
export function buildChrome({ onGoTo }) {
  const header = document.querySelector('body > .top');
  const hint = document.querySelector('body > .hint');

  header.querySelectorAll('[data-lang]').forEach((b) => b.addEventListener('click', () => setLang(b.dataset.lang)));
  header.querySelector('.logo').addEventListener('click', (e) => { e.preventDefault(); onGoTo(0); });
  header.querySelector('.btn').addEventListener('click', (e) => { e.preventDefault(); onGoTo(SCENES.length - 1); });

  let last = -1;
  return {
    setActive(i, time = 0) {
      hint.classList.toggle('is-off', time > 0.12);
      if (i === last) return;
      last = i;
      // Sobre fondo claro, la cabecera y los puntos pasan a tinta y el botón a blanco
      const ink = !!SCENES[i].ink;
      document.documentElement.dataset.tone = ink ? 'ink' : 'cream';
      document.documentElement.style.setProperty('--accent', ink ? '#FFFFFF' : NOTE.yellow);
    },
  };
}
