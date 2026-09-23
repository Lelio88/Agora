// Bascule FR / EN des pages légales.
//
// Une seule page porte les deux langues : le lien donné à la fiche Play, à
// l'app et aux e-mails est alors le même pour tout le monde, et il ne peut pas
// y avoir de version traduite oubliée derrière une autre adresse.
//
// La langue du navigateur décide à l'ouverture ; le français reste le défaut.

const sections = document.querySelectorAll('section[data-langue]');
const boutons = document.querySelectorAll('.langues button');

function choisir(langue) {
  sections.forEach((section) => {
    section.hidden = section.dataset.langue !== langue;
  });
  boutons.forEach((bouton) => {
    bouton.setAttribute('aria-pressed', String(bouton.dataset.langue === langue));
  });
  document.documentElement.lang = langue;
}

boutons.forEach((bouton) => {
  bouton.addEventListener('click', () => choisir(bouton.dataset.langue));
});

choisir((navigator.language || 'fr').toLowerCase().startsWith('en') ? 'en' : 'fr');
