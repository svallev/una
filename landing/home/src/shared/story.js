// La historia: siete escenas, cada una con su fondo y el color de nota de su palabra en 3D.
export const NOTE = {
  yellow: '#FFE55C',
  pink: '#FF9EC4',
  blue: '#8FD3F4',
  green: '#A6E88F',
  orange: '#FFB870',
};

export const INK = '#111111';
export const CREAM = '#F4F1EA';

// Solo fondos cálidos: magentas, naranjas y amarillos. `accent` es el color de la palabra en 3D.
// En los fondos claros (`ink: true`) el texto va en tinta en vez de en crema.
export const SCENES = [
  { id: 'hero', bg: '#D4145A', accent: NOTE.yellow },
  { id: 'muchas', bg: '#FF8A1F', accent: '#FFFDF3', ink: true },
  { id: 'una', bg: '#FFD21F', accent: '#D4145A', ink: true },
  { id: 'amano', bg: '#B8146E', accent: NOTE.yellow },
  { id: 'activa', bg: '#FF8A1F', accent: '#FFFDF3', ink: true },
  { id: 'luz', bg: '#FFD21F', accent: '#D4145A', ink: true },
  { id: 'fin', bg: '#D4145A', accent: NOTE.yellow },
];

// Parte de cada tramo en que la cámara descansa en la escena; el resto es viaje.
export const HOLD = 0.42;
