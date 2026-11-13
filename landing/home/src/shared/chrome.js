import { WORDMARK, STORE_URLS, LINKS } from './config.js';
import { t, lang, setLang, applyMeta, titleHtml } from './i18n.js';
import { SCENES, NOTE } from './story.js';
import { icon } from './icons.js';

const escapeAttr = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

/**
 * Las tiendas, con un rótulo de texto propio (sin insignias hasta que haya ficha), App Store primero. Sin
 * dirección el rótulo se ve igual, pero no es un enlace: encima va "Muy pronto" y el lector lo oye en el nombre.
 */
export function storesHtml({ label = true } = {}) {
  const soon = t('store.soon');
  const one = (id) => {
    const url = STORE_URLS[id];
    const name = t(`store.${id}`);
    return url
      ? `<a class="badge badge--${id}" href="${escapeAttr(url)}" rel="noopener noreferrer">${name}</a>`
      : `<span class="badge badge--${id} is-soon">${name}<span class="vh"> (${soon.toLowerCase()})</span></span>`;
  };
  const pending = !STORE_URLS.googlePlay || !STORE_URLS.appStore;
  return `<div class="stores">${label && pending ? `<p class="stores__soon">${soon}</p>` : ''}<div class="stores__row">${one('appStore')}${one('googlePlay')}</div></div>`;
}

export function footerHtml() {
  return `<footer class="end"><span>${t('footer.legal')}</span><nav aria-label="${t('footer.nav')}"><a href="${LINKS.help}">${t('footer.help')}</a><a href="${LINKS.privacy}">${t('footer.privacy')}</a><a href="${LINKS.licenses}">${t('footer.licenses')}</a></nav></footer>`;
}

/** Bloque de texto de una escena: titular, entradilla y extras. */
export function copyHtml(scene, index, extra = '') {
  const tag = index === 0 ? 'h1' : 'h2';
  return `<div class="copy"><${tag} class="big" id="h-${scene.id}" style="--c:${scene.accent}">${titleHtml(`scenes.${scene.id}.title`)}</${tag}><p class="lead">${t(`scenes.${scene.id}.lead`)}</p>${extra}</div>`;
}

export function switchChip(label, on = false) {
  return `<span class="chip"><span>${label}</span><span class="sw${on ? ' is-on' : ''}" aria-hidden="true"></span></span>`;
}

/** Cabecera y pista de scroll. Devuelve cómo marcar la escena activa. */
export function buildChrome({ onGoTo }) {
  applyMeta();

  const header = document.createElement('header');
  header.className = 'top';
  header.innerHTML = `
    <a class="logo" href="#top" aria-label="${t('nav.home')}">${WORDMARK}</a>
    <div class="top__right">
      <div class="langs" role="group" aria-label="${t('nav.lang')}">
        <button type="button" data-lang="es" aria-pressed="${lang === 'es'}">ES</button>
        <button type="button" data-lang="en" aria-pressed="${lang === 'en'}">EN</button>
      </div>
      <a class="btn" href="#fin">${icon('arrowDown')}<span>${t('nav.download')}</span></a>
    </div>`;
  document.body.prepend(header);

  header.querySelectorAll('[data-lang]').forEach((b) => b.addEventListener('click', () => setLang(b.dataset.lang)));
  header.querySelector('.logo').addEventListener('click', (e) => { e.preventDefault(); onGoTo(0); });
  header.querySelector('.btn').addEventListener('click', (e) => { e.preventDefault(); onGoTo(SCENES.length - 1); });

  const hint = document.createElement('div');
  hint.className = 'hint';
  hint.setAttribute('aria-hidden', 'true');
  hint.innerHTML = `<span>${t('nav.hint')}</span>${icon('arrowDown')}`;
  document.body.append(hint);

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
